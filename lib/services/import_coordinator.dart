import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/game.dart';
import 'collection_store.dart';
import 'catalog_importer.dart';

/// One durable batch per collection. Images and checkpoint are kept in private
/// storage until a single atomic collection commit completes.
class ImportCoordinator extends ChangeNotifier {
  ImportCoordinator(this.store, {this.imageImporter});
  static final _instances = Expando<ImportCoordinator>();
  static ImportCoordinator forStore(CollectionStore store) =>
      _instances[store] ??= ImportCoordinator(store);
  final CollectionStore store;
  final Future<String> Function(String)? imageImporter;
  bool active = false, completed = false;
  String? error;
  int done = 0, total = 0;
  Map<String, dynamic>? _job;
  File get _file => File('${store.root.path}/catalog_import_job.json');
  bool get pending => active || _job != null;

  Future<void> _native(String method, [Map<String, dynamic>? arguments]) async {
    if (!Platform.isAndroid) return;
    await Documents.channel.invokeMethod<void>(method, arguments);
  }

  Future<void> _write() async {
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(jsonEncode(_job), flush: true);
    await temp.rename(_file.path);
  }

  String _normalized(String path) =>
      File(path).absolute.path.replaceAll('\\', '/');
  bool _within(String path, String directory) {
    var p = _normalized(path), d = _normalized(directory);
    if (Platform.isWindows) {
      p = p.toLowerCase();
      d = d.toLowerCase();
    }
    return p.startsWith(d.endsWith('/') ? d : '$d/');
  }

  Future<void> start(List<Game> games, List<Directory> sessions) async {
    if (pending) throw StateError('Já existe uma importação em andamento.');
    if (games.isEmpty) {
      throw const FormatException('Selecione ao menos um jogo.');
    }
    active = true;
    completed = false;
    error = null;
    done = 0;
    total = games.length;
    notifyListeners();
    Directory? stage;
    var nativeStarted = false;
    try {
      if (await _file.exists()) {
        throw StateError('Já existe uma importação pendente.');
      }
      await _native('beginImportService', {'total': total, 'done': done});
      nativeStarted = true;
      final base = await Directory(
        '${store.root.path}/catalog_inputs',
      ).create(recursive: true);
      stage = await base.createTemp('job_');
      final dirs = [...sessions.map((s) => s.path), stage.path];
      final staged = <String, String>{};
      final copies = <Game>[];
      for (final game in games) {
        final copy = game.copy();
        if (isCatalogZipImage(copy.front)) {
          final parts = catalogZipParts(copy.front);
          if (!sessions.any((s) => _within(parts[0], s.path))) {
            staged[parts[0]] ??= (await File(
              parts[0],
            ).copy('${stage.path}/covers.zip')).path;
            copy.front = catalogZipImage(staged[parts[0]]!, parts[1]);
          }
        } else if (copy.front.isNotEmpty &&
            !sessions.any((s) => _within(copy.front, s.path))) {
          staged[copy.front] ??= (await File(
            copy.front,
          ).copy('${stage.path}/image_${staged.length}')).path;
          copy.front = staged[copy.front]!;
        }
        copies.add(copy);
      }
      _job = {
        'version': 1,
        'games': copies.map((g) => g.toJson()).toList(),
        'index': 0,
        'images': <String, String>{},
        'owned': <String>[],
        'sessions': dirs,
      };
      await _write();
      unawaited(_run());
    } catch (e) {
      active = false;
      _job = null;
      if (stage != null) {
        await _cleanupSessions({
          'sessions': [stage.path],
        });
      }
      if (nativeStarted) {
        try {
          await _native('finishImportService', {'success': false});
        } catch (_) {}
      }
      notifyListeners();
      rethrow;
    }
  }

  /// Called while the app is visible; after a process stop, resumes the last checkpoint.
  Future<void> resumeIfPending() async {
    if (active || _job != null) return;
    final exists = await _file.exists();
    if (active || _job != null || !exists) return;
    try {
      final data = jsonDecode(await _file.readAsString());
      if (data is! Map ||
          data['version'] != 1 ||
          data['games'] is! List ||
          data['index'] is! int ||
          data['images'] is! Map ||
          data['owned'] is! List ||
          data['sessions'] is! List) {
        throw const FormatException('Importação pendente inválida.');
      }
      _job = Map<String, dynamic>.from(data);
      total = (_job!['games'] as List).length;
      done = _job!['index'] as int;
      if (done < 0 || done > total) {
        throw const FormatException('Progresso de importação inválido.');
      }
      await retry();
    } catch (e) {
      active = false;
      error = 'Não foi possível retomar a importação: $e';
      notifyListeners();
    }
  }

  Future<void> retry() async {
    if (active || _job == null) return;
    try {
      await _native('beginImportService', {'total': total, 'done': done});
      active = true;
      completed = false;
      error = null;
      notifyListeners();
      unawaited(_run());
    } catch (e) {
      error = 'Não foi possível iniciar a importação: $e';
      notifyListeners();
    }
  }

  Future<void> _run() async {
    final job = _job!;
    // The native service releases itself if this Dart engine disappears.
    final heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      if (active) {
        unawaited(
          _native('updateImportService', {
            'done': done,
            'total': total,
          }).catchError((Object _) {}),
        );
      }
    });
    try {
      final raw = job['games'] as List;
      final images = Map<String, String>.from(job['images'] as Map);
      final owned = List<String>.from(job['owned'] as List);
      for (var i = job['index'] as int; i < raw.length; i++) {
        final game = Game.fromJson(Map<String, dynamic>.from(raw[i] as Map));
        if (game.front.isNotEmpty) {
          final source = game.front;
          if (!images.containsKey(source)) {
            String input = source;
            if (isCatalogZipImage(source)) {
              final bytes = await compute(readCatalogImage, source);
              final temp = File(
                '${(job['sessions'] as List).last}/selected_$i',
              );
              await temp.writeAsBytes(bytes, flush: true);
              input = temp.path;
            }
            final name = await (imageImporter ?? store.importImage)(input);
            images[source] = name;
            owned.add(name);
          }
          game.front = images[source]!;
        }
        raw[i] = game.toJson();
        job['images'] = images;
        job['owned'] = owned;
        job['index'] = i + 1;
        await _write();
        done = i + 1;
        notifyListeners();
        if (done == total || done % 5 == 0) {
          try {
            await _native('updateImportService', {
              'done': done,
              'total': total,
            });
          } catch (_) {}
        }
      }
      final existing = store.games.map((g) => g.id).toSet();
      final ready = raw
          .map((j) => Game.fromJson(Map<String, dynamic>.from(j as Map)))
          .where((g) => !existing.contains(g.id))
          .toList();
      if (ready.isNotEmpty) {
        while (true) {
          try {
            await store.addAll(ready);
            break;
          } on StateError catch (e) {
            if (e.message != 'Aguarde o salvamento atual.') rethrow;
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
      }
      await _cleanupSessions(job);
      if (await _file.exists()) await _file.delete();
      _job = null;
      active = false;
      completed = true;
      error = null;
      notifyListeners();
      try {
        await _native('finishImportService', {'success': true, 'total': total});
      } catch (_) {}
    } catch (e) {
      active = false;
      error = 'Importação pausada. Confira as imagens e tente novamente: $e';
      notifyListeners();
      try {
        await _native('finishImportService', {
          'success': false,
          'total': total,
        });
      } catch (_) {}
    } finally {
      heartbeat.cancel();
    }
  }

  Future<void> _cleanupSessions(Map<String, dynamic> job) async {
    final parent = Directory('${store.root.path}/catalog_inputs');
    if (!await parent.exists()) return;
    final parentPath = (await parent.resolveSymbolicLinks()).replaceAll(
      '\\',
      '/',
    );
    for (final value in (job['sessions'] as List)) {
      if (value is! String) continue;
      final dir = Directory(value);
      try {
        if (!await dir.exists()) continue;
        var actual = (await dir.resolveSymbolicLinks()).replaceAll('\\', '/');
        var base = parentPath;
        if (Platform.isWindows) {
          actual = actual.toLowerCase();
          base = base.toLowerCase();
        }
        if (actual.startsWith('$base/') &&
            RegExp(r'^(batch_|job_)').hasMatch(actual.split('/').last)) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<void> discard() async {
    if (active) return;
    if (_job == null) {
      if (await _file.exists()) await _file.delete();
      error = null;
      completed = false;
      notifyListeners();
      return;
    }
    final referenced = store.games
        .expand((g) => [g.front, g.back, g.disc])
        .toSet();
    for (final name in (_job!['owned'] as List).whereType<String>()) {
      if (referenced.contains(name)) continue;
      for (final path in [store.path(name), store.thumb(name)]) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    }
    await _cleanupSessions(_job!);
    if (await _file.exists()) await _file.delete();
    _job = null;
    error = null;
    completed = false;
    notifyListeners();
  }

  void dismiss() {
    completed = false;
    notifyListeners();
  }
}
