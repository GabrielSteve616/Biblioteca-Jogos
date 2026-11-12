import 'dart:convert';
import 'dart:io';

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/game.dart';

class ImportCandidate {
  ImportCandidate({
    required this.path,
    required this.name,
    required this.platform,
    required this.sourceId,
  });
  final String path, name, platform, sourceId;
  factory ImportCandidate.fromMap(Map map) => ImportCandidate(
    path: map['path'] as String,
    name: map['name'] as String,
    platform: map['platform'] as String,
    sourceId: map['sourceId'] as String,
  );
}

class Documents {
  static Future<String?> configureFolder({required bool createFolders}) async {
    final result = await channel.invokeMapMethod<String, dynamic>(
      'configureFolder',
      {'createFolders': createFolders},
    );
    return result?['name'] as String?;
  }

  static Future<List<ImportCandidate>> scanFolder(
    Iterable<String> knownIds,
  ) async {
    final result = await channel.invokeListMethod<dynamic>(
      'scanConfiguredFolder',
      {'knownIds': knownIds.toList()},
    );
    return (result ?? [])
        .map((e) => ImportCandidate.fromMap(e as Map))
        .toList();
  }

  static const channel = MethodChannel('acervo/documents');
  static Future<List<String>> images({
    bool multiple = false,
    bool folder = false,
  }) async =>
      (await channel.invokeListMethod<String>(folder ? 'folder' : 'images', {
        'multiple': multiple,
      })) ??
      [];
  static Future<List<String>> catalogFiles({bool folder = false}) async =>
      (await channel.invokeListMethod<String>(
        folder ? 'catalogFolder' : 'catalogFiles',
      )) ??
      [];
  static Future<String?> openBackup() =>
      channel.invokeMethod<String>('openBackup');
  static Future<bool> saveBackup(String path) async =>
      await channel.invokeMethod<bool>('saveBackup', {'path': path}) ?? false;
}

class CollectionStore extends ChangeNotifier {
  CollectionStore(this.root);
  final Directory root;
  List<Game> _games = [];
  List<Game> get games => List.unmodifiable(_games);
  List<String> get availableGenres {
    final counts = <String, int>{};
    for (final game in _games) {
      for (final genre
          in game.genre
              .split(RegExp(r'\s*[,;/|]\s*'))
              .map((g) => g.trim())
              .where((g) => g.isNotEmpty)
              .toSet()) {
        counts[genre] = (counts[genre] ?? 0) + 1;
      }
    }
    final genres = counts.keys.toList();
    genres.sort((a, b) {
      final compare = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      if (compare != 0) return compare;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return genres.take(5).toList();
  }

  File get database => File('${root.path}/collection.json');
  Directory get media => Directory('${root.path}/media');
  bool _busy = false;
  bool _requiresRestore = false;
  String? recoveryMessage;
  bool setupComplete = false;
  String folderName = '';
  String viewMode = 'grade';
  String orderMode = 'Título A–Z';
  Future<void> _preferencesWrite = Future.value();

  Future<void> setViewMode(String value) async {
    if (!['grade', 'estante', 'frontal'].contains(value)) return;
    viewMode = value;
    await _savePreferences();
    notifyListeners();
  }

  Future<void> setOrderMode(String value) async {
    if (![
      'Título A–Z',
      'Gênero',
      'Console',
      'Recentes',
      'Manual',
    ].contains(value)) {
      return;
    }
    orderMode = value;
    await _savePreferences();
    notifyListeners();
  }

  Future<void> _savePreferences() {
    final snapshot = jsonEncode({
      'setupComplete': setupComplete,
      'folderName': folderName,
      'viewMode': viewMode,
      'orderMode': orderMode,
    });
    final write = _preferencesWrite
        .catchError((Object _) {})
        .then((_) => _writePreferences(snapshot));
    _preferencesWrite = write;
    return write;
  }

  Future<void> _writePreferences(String snapshot) async {
    final settings = File('${root.path}/preferences.json');
    final temp = File('${settings.path}.tmp');
    await temp.writeAsString(snapshot, flush: true);
    await temp.rename(settings.path);
  }

  Future<void> finishSetup({String? folder}) async {
    setupComplete = true;
    folderName = folder ?? folderName;
    await _savePreferences();
    notifyListeners();
  }

  Future<void> load() async {
    await media.create(recursive: true);
    final settings = File('${root.path}/preferences.json');
    if (await settings.exists()) {
      try {
        final prefs = jsonDecode(await settings.readAsString());
        setupComplete = prefs['setupComplete'] == true;
        folderName = prefs['folderName'] is String ? prefs['folderName'] : '';
        if (['grade', 'estante', 'frontal'].contains(prefs['viewMode'])) {
          viewMode = prefs['viewMode'];
        }
        if ([
          'Título A–Z',
          'Gênero',
          'Console',
          'Recentes',
          'Manual',
        ].contains(prefs['orderMode'])) {
          orderMode = prefs['orderMode'];
        }
      } catch (_) {
        /* Re-offer setup if only preferences are invalid. */
      }
    }
    if (Platform.isAndroid) {
      String? saved;
      try {
        saved = await Documents.channel.invokeMethod<String>(
          'readCollectionSqlite',
        );
      } catch (_) {
        _requiresRestore = true;
        rethrow;
      }
      if (saved != null) {
        try {
          _games = _parse(saved);
          notifyListeners();
          return;
        } catch (_) {
          _requiresRestore = true;
          throw const FormatException(
            'Banco SQLite inválido. Restaure um backup.',
          );
        }
      }
    }
    // The journal is a full last-known-good DB; interrupted replacements recover automatically.
    final recovery = File('${database.path}.previous');
    if (!await database.exists() && await recovery.exists()) {
      await recovery.copy(database.path);
    }
    if (!await database.exists()) return;
    try {
      _games = _parse(await database.readAsString());
    } catch (_) {
      var recovered = false;
      if (await recovery.exists()) {
        try {
          _games = _parse(await recovery.readAsString());
          recoveryMessage = 'A última cópia válida foi recuperada.';
          recovered = true;
        } catch (_) {}
      }
      if (!recovered) {
        _requiresRestore = true;
        throw const FormatException(
          'Dados locais inválidos. O arquivo foi preservado.',
        );
      }
    }
    if (Platform.isAndroid) {
      try {
        await Documents.channel.invokeMethod<void>('writeCollectionSqlite', {
          'data': jsonEncode({
            'version': 1,
            'games': _games.map((g) => g.toJson()).toList(),
          }),
        });
      } catch (_) {
        _requiresRestore = true;
        rethrow;
      }
    }
    notifyListeners();
  }

  List<Game> _parse(String text) {
    final data = jsonDecode(text);
    if (data is! Map || data['version'] != 1 || data['games'] is! List) {
      throw const FormatException('Formato de coleção inválido.');
    }
    final result = (data['games'] as List)
        .map((e) => Game.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (result.map((g) => g.id).toSet().length != result.length) {
      throw const FormatException('Identificadores duplicados.');
    }
    return result;
  }

  Future<void> _commit(List<Game> games, {bool restoring = false}) async {
    if (_requiresRestore && !restoring) {
      throw StateError('Restaure um backup para preservar o banco inválido.');
    }
    if (_busy) throw StateError('Aguarde o salvamento atual.');
    _busy = true;
    try {
      final data = jsonEncode({
        'version': 1,
        'games': games.map((g) => g.toJson()).toList(),
      });
      if (Platform.isAndroid) {
        await Documents.channel.invokeMethod<void>('writeCollectionSqlite', {
          'data': data,
        });
      } else {
        final temp = File('${database.path}.tmp');
        final journal = File('${database.path}.previous');
        await temp.writeAsString(data, flush: true);
        if (await database.exists()) await database.copy(journal.path);
        await temp.rename(database.path);
      }
      _games = games;
      _requiresRestore = false;
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  Future<void> put(Game game) async {
    final next = _games.map((g) => g.id == game.id ? game.copy() : g).toList();
    if (!next.any((g) => g.id == game.id)) next.add(game.copy());
    await _commit(next);
  }

  Future<void> addAll(List<Game> games) async {
    final next = [..._games, ...games.map((g) => g.copy())];
    if (next.map((g) => g.id).toSet().length != next.length) {
      throw const FormatException('Jogos repetidos no lote.');
    }
    await _commit(next);
  }

  Future<void> delete(Game game) =>
      _commit(_games.where((g) => g.id != game.id).toList());
  Future<void> move(Game game, int offset) async {
    final next = [..._games];
    final index = next.indexWhere((g) => g.id == game.id);
    if (index < 0) return;
    final target = (index + offset).clamp(0, next.length - 1);
    next.insert(target, next.removeAt(index));
    await _commit(next);
  }

  Future<void> reorderById(String gameId, int targetIndex) async {
    final next = [..._games];
    final currentIndex = next.indexWhere((g) => g.id == gameId);
    if (currentIndex < 0) return;
    final game = next.removeAt(currentIndex);
    next.insert(targetIndex.clamp(0, next.length), game);
    await _commit(next);
  }

  Future<void> reorderVisible(List<String> ids) async {
    final wanted = ids.toSet();
    final byId = {for (final game in _games) game.id: game};
    if (wanted.length != ids.length || !wanted.every(byId.containsKey)) {
      throw const FormatException('Ordem de jogos inválida.');
    }
    var index = 0;
    final next = _games
        .map((game) => wanted.contains(game.id) ? byId[ids[index++]]! : game)
        .toList();
    await _commit(next);
  }

  static String basename(String path) =>
      path.replaceAll('\\', '/').split('/').last;
  String path(String name) => '${media.path}/${basename(name)}';
  String thumb(String name) => path('thumb_${basename(name)}');

  Future<String> importImage(String source) async {
    final bytes = await File(source).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final ratio =
        1536 /
        (descriptor.width > descriptor.height
            ? descriptor.width
            : descriptor.height);
    final codec = await descriptor.instantiateCodec(
      targetWidth: ratio < 1
          ? (descriptor.width * ratio).round()
          : descriptor.width,
      targetHeight: ratio < 1
          ? (descriptor.height * ratio).round()
          : descriptor.height,
    );
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    final name = '${DateTime.now().microsecondsSinceEpoch}.png';
    await File(path(name)).writeAsBytes(png!.buffer.asUint8List(), flush: true);
    frame.image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    await _thumbnail(name);
    return name;
  }

  Future<void> _thumbnail(String name) async {
    final bytes = await File(path(name)).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 240,
      allowUpscaling: false,
    );
    final image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(thumb(name)).writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
    codec.dispose();
  }

  Future<String> backup() async {
    final images = <String, String>{};
    for (final game in _games) {
      for (final name in [game.front, game.back, game.disc]) {
        if (name.isNotEmpty && !images.containsKey(name)) {
          images[name] = base64Encode(await File(path(name)).readAsBytes());
        }
      }
    }
    return jsonEncode({
      'format': 'acervo-flutter-1',
      'preferences': {'viewMode': viewMode, 'orderMode': orderMode},
      'collection': {
        'version': 1,
        'games': _games.map((g) => g.toJson()).toList(),
      },
      'images': images,
    });
  }

  /// Writes the existing JSON format without holding every encoded image in memory.
  Future<void> writeBackup(File destination) async {
    final games = _games.map((game) => game.copy()).toList();
    final preferences = {'viewMode': viewMode, 'orderMode': orderMode};
    final names = <String>{
      for (final game in games)
        for (final name in [game.front, game.back, game.disc])
          if (name.isNotEmpty) name,
    };
    final sink = destination.openWrite();
    try {
      sink.write('{"format":"acervo-flutter-1","preferences":');
      sink.write(jsonEncode(preferences));
      sink.write(',"collection":');
      sink.write(
        jsonEncode({
          'version': 1,
          'games': games.map((g) => g.toJson()).toList(),
        }),
      );
      sink.write(',"images":{');
      var first = true;
      for (final name in names) {
        if (!first) sink.write(',');
        first = false;
        sink.write('${jsonEncode(name)}:"');
        await sink.addStream(
          File(
            path(name),
          ).openRead().transform(base64.encoder).transform(utf8.encoder),
        );
        sink.write('"');
      }
      sink.write('}}');
      await sink.flush();
      await sink.close();
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  Future<void> restore(String text) => _restoreParsed(jsonDecode(text));

  Future<void> restoreFile(File file) async {
    final data = await file
        .openRead()
        .transform(utf8.decoder)
        .transform(json.decoder)
        .single;
    await _restoreParsed(data);
  }

  Future<void> _restoreParsed(dynamic data) async {
    if (data is! Map ||
        data['format'] != 'acervo-flutter-1' ||
        data['images'] is! Map) {
      throw const FormatException('Backup inválido.');
    }
    final imported = _parse(jsonEncode(data['collection']));
    final names = <String, String>{};
    final staged = <String>[];
    final stamp = DateTime.now().microsecondsSinceEpoch;
    var committed = false;
    try {
      for (final game in imported) {
        for (final original in [game.front, game.back, game.disc]) {
          if (original.isEmpty || names.containsKey(original)) continue;
          final encoded = data['images'][original];
          if (encoded is! String) {
            throw const FormatException('Imagem ausente no backup.');
          }
          final bytes = base64Decode(encoded);
          final codec = await ui.instantiateImageCodec(bytes);
          try {
            (await codec.getNextFrame()).image.dispose();
          } finally {
            codec.dispose();
          }
          // New filenames keep current media safe until the collection commits.
          final name = 'restore_${stamp}_${names.length}.png';
          staged.add(name);
          await File(path(name)).writeAsBytes(bytes, flush: true);
          await _thumbnail(name);
          names[original] = name;
        }
      }
      for (final game in imported) {
        game.front = names[game.front] ?? '';
        game.back = names[game.back] ?? '';
        game.disc = names[game.disc] ?? '';
      }
      await _commit(imported, restoring: true);
      committed = true;
    } finally {
      if (!committed) {
        for (final name in staged) {
          for (final file in [File(path(name)), File(thumb(name))]) {
            try {
              if (await file.exists()) await file.delete();
            } catch (_) {}
          }
        }
      }
    }
    final preferences = data['preferences'];
    if (preferences is Map) {
      if (['grade', 'estante', 'frontal'].contains(preferences['viewMode'])) {
        viewMode = preferences['viewMode'] as String;
      }
      if ([
        'Título A–Z',
        'Gênero',
        'Console',
        'Recentes',
        'Manual',
      ].contains(preferences['orderMode'])) {
        orderMode = preferences['orderMode'] as String;
      }
      await _savePreferences();
      notifyListeners();
    }
  }
}
