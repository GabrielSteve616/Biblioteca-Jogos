import 'dart:io';
import 'package:acervo/main.dart';
import 'package:acervo/models/game.dart';
import 'package:acervo/screens/game_detail.dart';
import 'package:acervo/screens/game_editor.dart';
import 'package:acervo/services/collection_store.dart';
import 'package:acervo/widgets/game_box_3d.dart';
import 'package:acervo/widgets/progress_stickers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late CollectionStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('acervo_interactive_');
    store = CollectionStore(directory);
    await store.load();
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  testWidgets(
    'Cover editor contains no progress toggles and preserves existing achievements',
    (tester) async {
      final game = Game.empty()
        ..title = 'Jogo preservado'
        ..finished = true
        ..platinum = true
        ..complete = true;
      await tester.runAsync(() => store.put(game));
      await tester.pumpWidget(
        MaterialApp(
          home: GameEditor(store: store, game: game),
        ),
      );
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text('Campanha zerada'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, 'Capa editada');
      await tester.scrollUntilVisible(
        find.byTooltip('Salvar jogo'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Salvar jogo'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(store.games.single.title, 'Capa editada');
      expect(store.games.single.finished, true);
      expect(store.games.single.platinum, true);
      expect(store.games.single.complete, true);
    },
  );

  testWidgets(
    'Corner controls toggle independently, preserve camera and add cover stickers',
    (tester) async {
      tester.view.physicalSize = const Size(480, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = Game.empty()..title = 'Adesivos';
      await tester.runAsync(() async {
        await store.put(game);
        await tester.pumpWidget(AcervoApp(store: store));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Adesivos').last);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pumpAndSettle();
      expect(find.byType(GameDetail), findsOneWidget);
      expect(find.byType(ProgressControls), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      final state = tester.state<GameBox3DState>(find.byType(GameBox3D));
      final position = state.visiblePartCenter('lid')!;
      await tester.tapAt(
        tester.getTopLeft(find.byKey(const ValueKey('case-touch-surface'))) +
            position,
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(state.opened, true);
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Platina'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(store.games.single.platinum, true);
      expect(store.games.single.finished, false);
      expect(state.opened, true, reason: 'Progress must not reset the 3D pose');
      final currentViewer = tester.widget<GameBox3D>(find.byType(GameBox3D));
      expect(currentViewer.game.platinum, true);
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('100% das conquistas'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(store.games.single.complete, true);
      expect(store.games.single.platinum, true);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Pulling the cover edge opens continuously and a double tap resets the pose',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GameBox3D(
                game: Game.empty()..title = 'Gestos',
                store: store,
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();
      final state = tester.state<GameBox3DState>(find.byType(GameBox3D));
      final surface = find.byKey(const ValueKey('case-touch-surface'));
      final bounds = tester.getRect(surface);
      final touch = Offset(bounds.left + bounds.width * .60, bounds.center.dy);
      final gesture = await tester.startGesture(touch);
      await gesture.moveBy(Offset(-bounds.width * .42, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(state.opened, true);
      expect(state.lid.value, closeTo(1, .001));
      await tester.tapAt(bounds.topLeft + const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(bounds.topLeft + const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(state.opened, false);
      expect(state.removed, false);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Bookshelf scrolls through every game and opens the selected spine',
    (tester) async {
      tester.view.physicalSize = const Size(480, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        for (var i = 0; i < 25; i++) {
          await store.put(
            Game(
              id: 'shelf_$i',
              title: 'Livro ${i.toString().padLeft(2, '0')}',
            ),
          );
        }
        await tester.pumpWidget(AcervoApp(store: store));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ver em estante'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('book-shelves')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byTooltip('Livro 24'),
        240,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('book-shelves')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Livro 24'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Livro 24'));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pumpAndSettle();
      expect(find.byType(GameDetail), findsOneWidget);
      expect(
        tester.widget<GameBox3D>(find.byType(GameBox3D)).game.id,
        'shelf_24',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
