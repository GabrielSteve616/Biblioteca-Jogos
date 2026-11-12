import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:acervo/models/game.dart';
import 'package:acervo/screens/library_screen.dart';
import 'package:acervo/services/collection_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late CollectionStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('biblioteca_backup_');
    store = CollectionStore(root);
    await store.load();
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Documents.channel, null);
    await root.delete(recursive: true);
  });

  testWidgets(
    'Backup em arquivo recupera imagens, plataformas e preferências',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
        final image = await recorder.endRecording().toImage(32, 48);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        image.dispose();
        final original = File('${root.path}/cover.png');
        await original.writeAsBytes(bytes);
        final cover = await store.importImage(original.path);
        await store.addAll([
          Game(id: 'first', title: 'Jogo', front: cover, platinum: true)
            ..assignedPlatforms = ['PS2', 'Steam'],
          Game(
            id: 'second',
            title: 'Mesmo arquivo',
            front: cover,
            finished: true,
          ),
        ]);
        await store.setViewMode('estante');
        await store.setOrderMode('Manual');
        final output = File('${root.path}/export.json');
        await store.writeBackup(output);
        final document = jsonDecode(await output.readAsString()) as Map;
        expect((document['images'] as Map).length, 1);
        expect(document, jsonDecode(await store.backup()));
        final destination = CollectionStore(await root.createTemp('restored_'));
        await destination.load();
        await destination.restoreFile(output);
        expect(destination.games.first.assignedPlatforms, ['PS2', 'Steam']);
        expect(destination.games.first.platinum, isTrue);
        expect(destination.games.last.finished, isTrue);
        expect(destination.viewMode, 'estante');
        expect(destination.orderMode, 'Manual');
        expect(
          await File(
            destination.path(destination.games.first.front),
          ).readAsBytes(),
          bytes,
        );
        final before = destination.media.listSync().map((f) => f.path).toSet();
        ((document['collection']['games'] as List)[1] as Map)['front'] =
            'ausente.png';
        await expectLater(
          destination.restore(jsonEncode(document)),
          throwsFormatException,
        );
        expect(destination.games.map((g) => g.id), ['first', 'second']);
        expect(destination.media.listSync().map((f) => f.path).toSet(), before);
      });
    },
  );

  test('Falha ao exportar imagem ausente apaga arquivo parcial', () async {
    await store.put(
      Game(id: 'missing', title: 'Sem imagem', front: 'missing.png'),
    );
    final output = File('${root.path}/partial.json');
    await expectLater(
      store.writeBackup(output),
      throwsA(isA<FileSystemException>()),
    );
    expect(await output.exists(), isFalse);
    expect(store.games.single.title, 'Sem imagem');
  });

  test(
    'Exportação em partes preserva imagens grandes e nomes especiais',
    () async {
      const name = 'Capa edição & ã.png';
      final bytes = List<int>.generate(512 * 1024 + 7, (i) => i % 251);
      await File(store.path(name)).writeAsBytes(bytes);
      await store.put(Game(id: 'large', title: 'Edição especial', front: name));
      final output = File('${root.path}/large.json');
      await store.writeBackup(output);
      final backup = jsonDecode(await output.readAsString()) as Map;
      expect(base64Decode(backup['images'][name] as String), bytes);
    },
  );

  testWidgets(
    'Exportar envia um arquivo temporário ao seletor e remove após cancelar ou salvar',
    (tester) async {
      await tester.runAsync(() => store.put(Game(id: 'game', title: 'Jogo')));
      var saves = 0;
      final submittedPaths = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Documents.channel, (call) async {
            if (call.method != 'saveBackup') return null;
            saves++;
            final args = Map<String, dynamic>.from(call.arguments as Map);
            expect(args.keys, ['path']);
            final path = args['path'] as String;
            submittedPaths.add(path);
            final data = jsonDecode(await File(path).readAsString()) as Map;
            expect(
              (data['collection']['games'] as List).single['title'],
              'Jogo',
            );
            if (saves == 3) {
              throw PlatformException(
                code: 'write',
                message: 'Falha de gravação',
              );
            }
            return saves == 2;
          });
      await tester.pumpWidget(MaterialApp(home: LibraryScreen(store: store)));
      await tester.pumpAndSettle();
      final dynamic screen = tester.state(find.byType(LibraryScreen));
      await tester.runAsync(() async {
        await screen.export();
        await screen.export();
        await screen.export();
      });
      expect(saves, 3);
      await tester.runAsync(() async {
        for (final path in submittedPaths) {
          expect(await File(path).exists(), isFalse);
        }
      });
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Restaurar usa cópia temporária e preserva o arquivo escolhido', (
    tester,
  ) async {
    late File original;
    final temporary = File('${root.path}/incoming-copy.json');
    await tester.runAsync(() async {
      await store.put(
        Game(id: 'backup', title: 'Jogo do backup')
          ..assignedPlatforms = ['Steam', 'PS3'],
      );
      original = File('${root.path}/original-backup.json');
      await store.writeBackup(original);
      await store.delete(store.games.single);
      await store.put(Game(id: 'current', title: 'Coleção atual'));
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Documents.channel, (call) async {
          if (call.method != 'openBackup') return null;
          await original.copy(temporary.path);
          return temporary.path;
        });
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(store: store)));
    await tester.pumpAndSettle();
    final dynamic screen = tester.state(find.byType(LibraryScreen));
    await tester.runAsync(() async {
      final Future<void> restoring = screen.restore();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escolher backup'));
      for (var i = 0; i < 200 && store.games.first.id != 'backup'; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await restoring;
      expect(await original.exists(), isTrue);
      expect(await temporary.exists(), isFalse);
    });
    expect(store.games.single.assignedPlatforms, ['Steam', 'PS3']);
    await tester.pumpWidget(const SizedBox());
  });
}
