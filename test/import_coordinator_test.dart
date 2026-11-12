import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acervo/models/game.dart';
import 'package:acervo/services/collection_store.dart';
import 'package:acervo/services/import_coordinator.dart';
import 'package:acervo/services/catalog_importer.dart';

Future<void> waitUntil(bool Function() condition) async {
  for (var i = 0; i < 500 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(
    condition(),
    isTrue,
    reason: 'Background task did not reach the expected state',
  );
}

void main() {
  late Directory root;
  late CollectionStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('background_catalog_');
    store = CollectionStore(root);
    await store.load();
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
  test('Only the selected ZIP image is extracted and imported', () async {
    final archive = Archive()
      ..add(ArchiveFile('escolhido.png', 2, [1, 2]))
      ..add(ArchiveFile('ignorado.png', 2, [8, 9]));
    final zip = File('${root.path}/capas.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));
    var calls = 0;
    final task = ImportCoordinator(
      store,
      imageImporter: (path) async {
        calls++;
        expect(await File(path).readAsBytes(), [1, 2]);
        return 'chosen.png';
      },
    );
    await task.start([
      Game(
        id: 'chosen',
        title: 'Escolhido',
        front: catalogZipImage(zip.path, 'escolhido.png'),
      ),
    ], []);
    await waitUntil(() => !task.active);
    expect(task.error, isNull);
    expect(calls, 1);
    expect(store.games.map((g) => g.id), ['chosen']);
    expect(await zip.exists(), isTrue);
  });
  test(
    'A selected batch runs independently while the collection remains usable',
    () async {
      final original = File('${root.path}/original.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      final gate = Completer<void>();
      final task = ImportCoordinator(
        store,
        imageImporter: (path) async {
          await gate.future;
          expect(await File(path).exists(), isTrue);
          await File(store.path('converted.png')).writeAsBytes([4, 5]);
          return 'converted.png';
        },
      );
      final first = Game(
        id: 'one',
        title: 'Selecionado',
        platform: '',
        front: original.path,
      )..assignedPlatforms = ['Steam', 'PS3'];
      await task.start([first], []);
      expect(task.active, isTrue);
      expect(store.games, isEmpty);
      expect(File('${root.path}/catalog_import_job.json').existsSync(), isTrue);
      await store.put(
        Game(id: 'existing', title: 'Jogo adicionado durante a importação'),
      );
      gate.complete();
      await waitUntil(() => !task.active);
      expect(task.completed, isTrue);
      expect(task.error, isNull);
      expect(store.games.map((g) => g.id), ['existing', 'one']);
      expect(store.games.last.assignedPlatforms, ['Steam', 'PS3']);
      expect(await original.readAsBytes(), [1, 2, 3]);
      expect(
        await File('${root.path}/catalog_import_job.json').exists(),
        isFalse,
      );
    },
  );
  test(
    'A failed second image leaves the collection untouched and resumes from its checkpoint',
    () async {
      final first = File('${root.path}/1.jpg')..writeAsBytesSync([1]);
      final second = File('${root.path}/2.jpg')..writeAsBytesSync([2]);
      var calls = 0;
      final task = ImportCoordinator(
        store,
        imageImporter: (path) async {
          calls++;
          if (calls == 2) {
            throw const FormatException('Imagem temporariamente indisponível');
          }
          final name = 'converted_$calls.png';
          await File(store.path(name)).writeAsBytes([calls]);
          return name;
        },
      );
      await task.start([
        Game(id: 'first', title: 'Primeiro', front: first.path, platform: ''),
        Game(id: 'second', title: 'Segundo', front: second.path, platform: ''),
      ], []);
      await waitUntil(() => !task.active);
      expect(task.error, isNotNull);
      expect(store.games, isEmpty);
      final checkpoint =
          jsonDecode(
                await File(
                  '${root.path}/catalog_import_job.json',
                ).readAsString(),
              )
              as Map;
      expect(checkpoint['index'], 1);
      expect(calls, 2);
      await task.retry();
      await waitUntil(() => !task.active);
      expect(task.error, isNull);
      expect(task.completed, isTrue);
      expect(calls, 3);
      expect(store.games.map((g) => g.id), ['first', 'second']);
      expect(await first.exists(), isTrue);
      expect(await second.exists(), isTrue);
    },
  );
  test(
    'Recovery after the database commit does not duplicate previously saved games',
    () async {
      final game = Game(id: 'persistent', title: 'Já salvo', platform: 'Steam');
      await store.put(game);
      await File('${root.path}/catalog_import_job.json').writeAsString(
        jsonEncode({
          'version': 1,
          'games': [game.toJson()],
          'index': 1,
          'images': {},
          'owned': [],
          'sessions': [],
        }),
      );
      final task = ImportCoordinator(store);
      await task.resumeIfPending();
      await waitUntil(() => !task.active);
      expect(task.completed, isTrue);
      expect(store.games.map((g) => g.id), ['persistent']);
      expect(
        await File('${root.path}/catalog_import_job.json').exists(),
        isFalse,
      );
    },
  );
  test(
    'Discard after failure removes only newly staged media and keeps existing data',
    () async {
      final original = File('${root.path}/original.jpg')..writeAsBytesSync([1]);
      final other = File('${root.path}/other.jpg')..writeAsBytesSync([3]);
      var calls = 0;
      final task = ImportCoordinator(
        store,
        imageImporter: (path) async {
          calls++;
          if (calls > 1) throw const FormatException('Erro de teste');
          await File(store.path('temp.png')).writeAsBytes([2]);
          return 'temp.png';
        },
      );
      await store.put(Game(id: 'keep', title: 'Manter'));
      await task.start([
        Game(id: 'a', title: 'A', front: original.path),
        Game(id: 'b', title: 'B', front: other.path),
      ], []);
      await waitUntil(() => !task.active);
      expect(task.error, isNotNull);
      expect(task.pending, isTrue);
      expect(await File(store.path('temp.png')).exists(), isTrue);
      expect(store.games.single.id, 'keep');
      await task.discard();
      expect(await File(store.path('temp.png')).exists(), isFalse);
      expect(
        await File('${root.path}/catalog_import_job.json').exists(),
        isFalse,
      );
      expect(await original.exists(), isTrue);
      expect(await other.exists(), isTrue);
    },
  );
  test(
    'A 254-game job checkpoints every row and commits the batch only once',
    () async {
      final sources = <Game>[];
      for (var i = 0; i < 254; i++) {
        final source = File('${root.path}/source_$i.jpg')
          ..writeAsBytesSync([i % 256]);
        sources.add(
          Game(
            id: 'row_$i',
            title: 'Jogo $i',
            front: source.path,
            platform: '',
          ),
        );
      }
      var normalized = 0;
      final task = ImportCoordinator(
        store,
        imageImporter: (path) async {
          normalized++;
          final name = 'normalized_$normalized.png';
          await File(store.path(name)).writeAsBytes([normalized % 256]);
          return name;
        },
      );
      var writes = 0;
      store.addListener(() => writes++);
      await task.start(sources, []);
      for (var i = 0; i < 6000 && task.active; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(task.active, isFalse);
      expect(task.error, isNull);
      expect(task.done, 254);
      expect(normalized, 254);
      expect(store.games.length, 254);
      expect(writes, 1);
      expect(store.games.map((g) => g.id).toSet().length, 254);
      expect(
        await File('${root.path}/catalog_import_job.json').exists(),
        isFalse,
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
