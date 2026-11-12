import 'dart:io';
import 'package:acervo/models/game.dart';
import 'package:acervo/screens/library_screen.dart';
import 'package:acervo/services/collection_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Segurar e arrastar reorganiza as capas e persiste a ordem', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory root;
    late CollectionStore store;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('drag_library_');
      store = CollectionStore(root);
      await store.load();
      await store.addAll([
        Game(id: 'a', title: 'Alfa'),
        Game(id: 'b', title: 'Beta'),
        Game(id: 'c', title: 'Charlie'),
      ]);
    });
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(store: store)));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('drag-a'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('drag-c'))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await gesture.up();
      for (var i = 0; i < 100 && store.games.last.id != 'a'; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    expect(store.games.map((g) => g.id), ['b', 'c', 'a']);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      final reopened = CollectionStore(root);
      await reopened.load();
      expect(reopened.games.map((g) => g.id), ['b', 'c', 'a']);
      await root.delete(recursive: true);
    });
  });
}
