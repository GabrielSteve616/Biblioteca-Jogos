import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acervo/main.dart';
import 'package:acervo/models/game.dart';
import 'package:acervo/screens/catalog_import.dart';
import 'package:acervo/screens/game_editor.dart';
import 'package:acervo/services/catalog_importer.dart';
import 'package:acervo/services/collection_store.dart';
import 'package:acervo/services/import_coordinator.dart';

void main() {
  late Directory root;
  late CollectionStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('catalog_review_');
    store = CollectionStore(root);
    await store.load();
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  testWidgets(
    'Review supports per-game, multi-platform and bulk assignments; only Finish commits',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final games = List.generate(
        3,
        (i) => Game(
          id: 'review_$i',
          title: 'Jogo $i',
          platform: '',
          description: 'Descrição $i',
          genre: 'Aventura',
          year: '2024',
          rating: 'T',
          players: '1–2',
        ),
      );
      final batch = CatalogBatch(games, {}, [], '');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CatalogImport(store: store, initialBatch: batch),
                  ),
                ),
                child: const Text('Revisar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      expect(store.games, isEmpty);
      await tester.tap(find.widgetWithText(TextButton, Game.unassigned).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Steam'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'PS2'));
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(games.first.assignedPlatforms, ['Steam', 'PS2']);
      expect(store.games, isEmpty);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      await tester.tap(find.text('Atribuir plataforma aos selecionados'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'PS4'));
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(games[0].assignedPlatforms, ['PS4']);
      expect(games[1].assignedPlatforms, ['PS4']);
      expect(games[2].assignedPlatforms, isEmpty);
      expect(store.games, isEmpty);
      await tester.runAsync(() async {
        await tester.tap(find.text('Importar selecionados (2)'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      for (
        var i = 0;
        i < 200 &&
            (store.games.length < 2 ||
                ImportCoordinator.forStore(store).active);
        i++
      ) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pumpAndSettle();
      expect(store.games.length, 2);
      expect(store.games.any((g) => g.id == 'review_2'), isFalse);
      expect(ImportCoordinator.forStore(store).active, isFalse);
      expect(store.games.first.description, 'Descrição 0');
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      expect(find.text('Já na biblioteca'), findsNWidgets(2));
      expect(find.text('Importar todos (1)'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Importar todos (1)'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      for (
        var i = 0;
        i < 200 &&
            (store.games.length < 3 ||
                ImportCoordinator.forStore(store).active);
        i++
      ) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pumpAndSettle();
      expect(store.games.length, 3);
      expect(store.games.last.platformLabel, Game.unassigned);
      expect(store.games.map((g) => g.id).toSet().length, 3);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Editing a saved game can add a collection or clear all platforms without losing progress',
    (tester) async {
      final game = Game(
        id: 'edit',
        title: 'Já cadastrado',
        platform: 'Steam',
        finished: true,
      );
      await tester.runAsync(() => store.put(game));
      await tester.pumpWidget(
        MaterialApp(
          home: GameEditor(store: store, game: game),
        ),
      );
      await tester.tap(find.widgetWithText(FilterChip, 'PS3'));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Salvar jogo'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(store.games.single.assignedPlatforms, ['Steam', 'PS3']);
      expect(store.games.single.finished, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: GameEditor(
            key: const ValueKey('again'),
            store: store,
            game: store.games.single,
          ),
        ),
      );
      await tester.tap(find.byTooltip(Game.unassigned));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Salvar jogo'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(store.games.single.assignedPlatforms, isEmpty);
      expect(store.games.single.finished, isTrue);
    },
  );
  testWidgets(
    'Library filters a shared game into both collections and exposes unassigned games',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await store.addAll([
          Game(id: 'shared', title: 'Compartilhado')
            ..assignedPlatforms = ['Steam', 'PS2'],
          Game(id: 'none', title: 'Sem coleção', platform: ''),
        ]);
      });
      await tester.pumpWidget(AcervoApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Opções de Compartilhado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plataformas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Android'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Aplicar'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      for (
        var i = 0;
        i < 200 && store.games.first.assignedPlatforms.length != 3;
        i++
      ) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pumpAndSettle();
      expect(store.games.first.assignedPlatforms, ['Steam', 'PS2', 'Android']);
      await tester.tap(find.byKey(const ValueKey('platform_filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PS2').last);
      await tester.pumpAndSettle();
      expect(find.text('Compartilhado'), findsAtLeastNWidgets(1));
      expect(find.text('Sem coleção'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('platform_filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Game.unassigned).last);
      await tester.pumpAndSettle();
      expect(find.text('Sem coleção'), findsAtLeastNWidgets(1));
      expect(find.text('Compartilhado'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Bundled project files load into review without saving or preselecting platforms',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: CatalogImport(store: store)));
      final dynamic state = tester.state(find.byType(CatalogImport));
      await tester.runAsync(() async {
        await state.load(bundled: true);
      });
      await tester.pumpAndSettle();
      expect(state.batch.games.length, 279);
      expect(
        state.batch.games.every((Game g) => g.assignedPlatforms.isEmpty),
        isTrue,
      );
      expect(find.text('Importar todos (279)'), findsOneWidget);
      expect(store.games, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        await state.cleanup();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
    },
  );
}
