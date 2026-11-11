import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:acervo/main.dart';
import 'package:acervo/models/game.dart';
import 'package:acervo/services/collection_store.dart';
import 'package:acervo/widgets/game_box_3d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late CollectionStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('acervo_test_');
    store = CollectionStore(directory);
    await store.load();
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'Persistence, independent progress, duplicate, manual order and delete',
    () async {
      final game = Game.empty()
        ..title = 'Primeiro'
        ..finished = true
        ..complete = true;
      await store.put(game);
      final other = game.copy()
        ..id = 'second'
        ..title = 'Segundo';
      await store.put(other);
      await store.move(other, -1);
      final restarted = CollectionStore(directory);
      await restarted.load();
      expect(restarted.games.first.id, 'second');
      expect(restarted.games.last.finished, true);
      expect(restarted.games.last.platinum, false);
      expect(restarted.games.last.complete, true);
      await restarted.delete(game);
      expect(restarted.games.single.id, 'second');
    },
  );

  test('Missing database recovers the previous committed journal', () async {
    await store.put(Game.empty()..title = 'Seguro');
    await store.put(Game.empty()..title = 'Novo');
    await store.database.delete();
    final restarted = CollectionStore(directory);
    await restarted.load();
    expect(restarted.games.single.title, 'Seguro');
  });

  testWidgets(
    'Images survive source deletion and backup transfers to a fresh installation',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 32, 48),
          Paint()..color = Colors.blue,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(32, 48);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final source = File('${directory.path}/source.png');
        await source.writeAsBytes(bytes!.buffer.asUint8List());
        final owned = await store.importImage(source.path);
        await source.delete();
        expect(await File(store.path(owned)).exists(), true);
        expect(await File(store.thumb(owned)).exists(), true);
        await store.put(
          Game.empty()
            ..title = 'Com imagem'
            ..front = owned,
        );
        final backup = await store.backup();
        final freshDir = await directory.createTemp('fresh_');
        final fresh = CollectionStore(freshDir);
        await fresh.load();
        await fresh.restore(backup);
        expect(fresh.games.single.title, 'Com imagem');
        expect(
          await File(fresh.path(fresh.games.single.front)).readAsBytes(),
          await File(store.path(owned)).readAsBytes(),
        );
        final corrupted = jsonDecode(backup) as Map;
        corrupted['images'] = {};
        await expectLater(
          fresh.restore(jsonEncode(corrupted)),
          throwsFormatException,
        );
        expect(fresh.games.single.title, 'Com imagem');
        image.dispose();
        picture.dispose();
      });
    },
  );

  test('Invalid backups preserve existing games', () async {
    await store.put(Game.empty()..title = 'Preservado');
    await expectLater(store.restore('{}'), throwsFormatException);
    expect(store.games.single.title, 'Preservado');
    final json = store.games.single.toJson()..['finished'] = 'yes';
    expect(() => Game.fromJson(json), throwsFormatException);
  });

  testWidgets('Library filters titles and platforms on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => store.put(
        Game.empty()
          ..title = 'Alfa'
          ..platform = 'PS1',
      ),
    );
    await tester.runAsync(
      () => store.put(
        Game.empty()
          ..title = 'Beta'
          ..platform = 'Steam',
      ),
    );
    await tester.pumpWidget(AcervoApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Alfa'), findsAtLeastNWidgets(1));
    await tester.enterText(find.byType(TextField), 'Beta');
    await tester.pumpAndSettle();
    expect(find.text('Alfa'), findsNothing);
    expect(find.text('Beta'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Editor validates and saves a new game', (tester) async {
    await tester.pumpWidget(AcervoApp(store: store));
    await tester.tap(find.byTooltip('Novo jogo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Meu jogo');
    await tester.scrollUntilVisible(
      find.byTooltip('Salvar jogo'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Salvar jogo'));
      for (var i = 0; i < 100 && store.games.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(store.games.single.title, 'Meu jogo');
    expect(find.text('Meu jogo'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Every platform opens, extracts and closes by touching the rendered objects',
    (tester) async {
      for (final platform in Game.platforms) {
        final game = Game.empty()
          ..title = 'Caixa $platform'
          ..platform = platform;
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: GameBox3D(
                  key: ValueKey(platform),
                  game: game,
                  store: store,
                ),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pump();
        final state = tester.state<GameBox3DState>(find.byType(GameBox3D));
        expect(
          state.usesImportedMesh,
          ['Steam', 'PS2', 'PS3', 'PS4', 'Android'].contains(platform),
          reason: '$platform must use its intended geometry',
        );
        Future<void> tapPart(String part) async {
          final position = state.visiblePartCenter(part);
          expect(
            position,
            isNotNull,
            reason: '$platform: $part must be visibly touchable',
          );
          await tester.tapAt(
            tester.getTopLeft(
                  find.byKey(const ValueKey('case-touch-surface')),
                ) +
                position!,
          );
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
        }

        expect(find.byType(ActionChip), findsNothing);
        expect(find.text('Abrir caixa'), findsNothing);
        await tapPart('lid');
        expect(state.opened, true, reason: platform);
        await tapPart('media');
        expect(state.removed, true, reason: platform);
        final position = state.visiblePartCenter('media')!;
        await tester.dragFrom(position, const Offset(40, 20));
        await tester.pumpAndSettle();
        expect(state.discY.abs(), greaterThan(.01));
        await tapPart('media');
        expect(state.removed, false);
        await tapPart('lid');
        expect(state.opened, false);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'Corrupt local database stays protected until a valid backup restores it',
    () async {
      await store.put(Game.empty()..title = 'Coleção segura');
      final backup = await store.backup();
      await store.database.writeAsString('{}');
      final journal = File('${store.database.path}.previous');
      if (await journal.exists()) await journal.delete();
      final reopened = CollectionStore(directory);
      await expectLater(reopened.load(), throwsFormatException);
      await expectLater(
        reopened.put(Game.empty()..title = 'Não sobrescrever'),
        throwsStateError,
      );
      await reopened.restore(backup);
      expect(reopened.games.single.title, 'Coleção segura');
    },
  );

  testWidgets('Library adapts to 320px, landscape and keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(AcervoApp(store: store));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(800, 360);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
