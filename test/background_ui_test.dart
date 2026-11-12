import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acervo/models/game.dart';
import 'package:acervo/screens/catalog_import.dart';
import 'package:acervo/screens/library_screen.dart';
import 'package:acervo/services/catalog_importer.dart';
import 'package:acervo/services/collection_store.dart';
import 'package:acervo/services/import_coordinator.dart';

void main() {
  testWidgets(
    'A selected game continues importing after leaving review and pausing the app',
    (tester) async {
      tester.view.physicalSize = const Size(480, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory root;
      late CollectionStore store;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('background_ui_');
        store = CollectionStore(root);
        await store.load();
      });
      late File picture;
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(Colors.blue, BlendMode.src);
        final image = await recorder.endRecording().toImage(20, 20);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        picture = File('${root.path}/source.png');
        await picture.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      final gate = Completer<void>();
      final task = ImportCoordinator(
        store,
        imageImporter: (path) async {
          await gate.future;
          return store.importImage(path);
        },
      );
      final games = [
        Game(
          id: 'chosen',
          title: 'Escolhido',
          platform: '',
          front: picture.path,
        ),
        Game(id: 'other', title: 'Outro', platform: ''),
      ];
      final batch = CatalogBatch(games, {}, [], '');
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: LibraryScreen(store: store, coordinator: task),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => CatalogImport(
            store: store,
            initialBatch: batch,
            coordinator: task,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Importar selecionados (1)'));
        for (
          var i = 0;
          i < 300 && find.byType(CatalogImport).evaluate().isNotEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 20));
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(find.byType(CatalogImport), findsNothing);
      expect(task.active, isTrue);
      await tester.pump();
      expect(
        find.textContaining('Importando em segundo plano'),
        findsOneWidget,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.runAsync(() async {
        await store.put(Game(id: 'existing', title: 'Outro cadastro'));
        gate.complete();
        for (var i = 0; i < 1000 && task.active; i++) {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        task.completed,
        isTrue,
        reason: task.error ?? 'Tarefa ainda ativa',
      );
      expect(task.error, isNull);
      expect(store.games.map((g) => g.id), ['existing', 'chosen']);
      expect(store.games.any((g) => g.id == 'other'), isFalse);
      expect(find.text('Importação concluída'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await root.delete(recursive: true);
      });
    },
  );

  testWidgets(
    'Previously imported legacy rows are marked and are not selected again',
    (tester) async {
      late Directory root;
      late CollectionStore store;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('background_legacy_');
        store = CollectionStore(root);
        await store.load();
      });
      await tester.runAsync(
        () => store.put(
          Game(
            id: 'catalog_168000_0',
            title: 'Jogo antigo',
            description: 'Descrição',
            genre: 'Ação',
            year: '2020',
            rating: 'T',
            players: '1',
          ),
        ),
      );
      final first = Game(
        id: 'catalog_hash_0',
        title: 'Jogo antigo',
        platform: '',
        description: 'Descrição',
        genre: 'Ação',
        year: '2020',
        rating: 'T',
        players: '1',
      );
      final second = Game(
        id: 'catalog_hash_1',
        title: 'Jogo antigo',
        platform: '',
        description: 'Descrição',
        genre: 'Ação',
        year: '2020',
        rating: 'T',
        players: '1',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CatalogImport(
            store: store,
            initialBatch: CatalogBatch([first, second], {}, [], ''),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Já na biblioteca'), findsOneWidget);
      expect(find.text('Importar todos (1)'), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged,
        isNull,
      );
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).last).onChanged,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );

  testWidgets(
    'An updated catalog recognizes existing rows with revised descriptions',
    (tester) async {
      late Directory root;
      late CollectionStore store;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('background_updated_');
        store = CollectionStore(root);
        await store.load();
        await store.addAll([
          Game(
            id: 'catalog_previous_1',
            title: 'The Forest',
            year: '2018',
            description: 'Minha descrição',
            platinum: true,
          )..assignedPlatforms = ['PS4'],
          Game(
            id: 'catalog_previous_146',
            title: 'The Forest',
            year: '2018',
            description: 'Outra edição',
          )..assignedPlatforms = ['Steam'],
        ]);
      });
      final games = [
        Game(
          id: 'catalog_new_1',
          title: 'The Forest',
          year: '2018',
          description: 'Descrição revisada',
          platform: '',
        ),
        Game(
          id: 'catalog_new_146',
          title: 'The Forest',
          year: '2018',
          description: 'Outra descrição revisada',
          platform: '',
        ),
        Game(
          id: 'catalog_new_274',
          title: 'Jogo novo',
          year: '2024',
          platform: '',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: CatalogImport(
            store: store,
            initialBatch: CatalogBatch(games, {}, [], ''),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Já na biblioteca'), findsNWidgets(2));
      expect(find.text('Importar todos (1)'), findsOneWidget);
      expect(store.games.first.description, 'Minha descrição');
      expect(store.games.first.assignedPlatforms, ['PS4']);
      expect(store.games.first.platinum, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
}
