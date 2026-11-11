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
  static Future<String?> openBackup() =>
      channel.invokeMethod<String>('openBackup');
  static Future<bool> saveBackup(String json) async =>
      await channel.invokeMethod<bool>('saveBackup', {'data': json}) ?? false;
}

class CollectionStore extends ChangeNotifier {
  CollectionStore(this.root);
  final Directory root;
  List<Game> _games = [];
  List<Game> get games => List.unmodifiable(_games);
  File get database => File('${root.path}/collection.json');
  Directory get media => Directory('${root.path}/media');
  bool _busy = false;
  bool _requiresRestore = false;
  String? recoveryMessage;
  bool setupComplete = false;
  String folderName = '';

  Future<void> finishSetup({String? folder}) async {
    final settings = File('${root.path}/preferences.json');
    final temp = File('${settings.path}.tmp');
    await temp.writeAsString(
      jsonEncode({'setupComplete': true, 'folderName': folder ?? folderName}),
      flush: true,
    );
    await temp.rename(settings.path);
    setupComplete = true;
    folderName = folder ?? folderName;
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
      } catch (_) {
        /* Re-offer setup if only preferences are invalid. */
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
      if (await recovery.exists()) {
        try {
          _games = _parse(await recovery.readAsString());
          recoveryMessage = 'A última cópia válida foi recuperada.';
          return;
        } catch (_) {}
      }
      _requiresRestore = true;
      throw const FormatException(
        'Dados locais inválidos. O arquivo foi preservado.',
      );
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
      final temp = File('${database.path}.tmp');
      final journal = File('${database.path}.previous');
      await temp.writeAsString(
        jsonEncode({
          'version': 1,
          'games': games.map((g) => g.toJson()).toList(),
        }),
        flush: true,
      );
      if (await database.exists()) await database.copy(journal.path);
      await temp.rename(database.path);
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
      'collection': {
        'version': 1,
        'games': _games.map((g) => g.toJson()).toList(),
      },
      'images': images,
    });
  }

  Future<void> restore(String text) async {
    final data = jsonDecode(text);
    if (data is! Map ||
        data['format'] != 'acervo-flutter-1' ||
        data['images'] is! Map) {
      throw const FormatException('Backup inválido.');
    }
    final imported = _parse(jsonEncode(data['collection']));
    final images = <String, Uint8List>{};
    for (final game in imported) {
      for (final name in [game.front, game.back, game.disc]) {
        if (name.isEmpty || images.containsKey(name)) continue;
        final encoded = data['images'][name];
        if (encoded is! String) {
          throw const FormatException('Imagem ausente no backup.');
        }
        final bytes = base64Decode(encoded);
        final codec = await ui.instantiateImageCodec(bytes);
        (await codec.getNextFrame()).image.dispose();
        codec.dispose();
        images[name] = bytes;
      }
    }
    // New filenames keep current media safe until the validated collection commits.
    final names = <String, String>{};
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (final entry in images.entries) {
      final name = 'restore_${stamp}_${names.length}.png';
      await File(path(name)).writeAsBytes(entry.value, flush: true);
      await _thumbnail(name);
      names[entry.key] = name;
    }
    for (final game in imported) {
      game.front = names[game.front] ?? '';
      game.back = names[game.back] ?? '';
      game.disc = names[game.disc] ?? '';
    }
    await _commit(imported, restoring: true);
  }
}
