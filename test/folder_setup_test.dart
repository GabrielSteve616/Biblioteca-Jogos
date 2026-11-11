import 'dart:io';
import 'package:acervo/main.dart';
import 'package:acervo/models/game.dart';
import 'package:acervo/services/collection_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late CollectionStore store;
  final calls = <MethodCall>[];
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('acervo_setup_');
    store = CollectionStore(directory);
    await store.load();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Documents.channel, (call) async {
          calls.add(call);
          if (call.method == 'configureFolder') {
            return {'name': 'Minhas capas', 'created': []};
          }
          if (call.method == 'scanConfiguredFolder') return [];
          return null;
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Documents.channel, null);
    await directory.delete(recursive: true);
  });

  test('Old games and backups migrate with all seven platforms', () async {
    expect(Game.platforms, [
      'PS1',
      'PS2',
      'PS3',
      'PS4',
      'PS5',
      'Steam',
      'Android',
    ]);
    final old = Game.empty()..title = 'Coleção antiga';
    final json = old.toJson()..remove('sourceId');
    expect(Game.fromJson(json).sourceId, '');
    for (final platform in Game.platforms) {
      await store.put(
        Game.empty()
          ..title = platform
          ..platform = platform
          ..sourceId = 'source:$platform',
      );
    }
    final backup = await store.backup();
    await store.restore(backup);
    expect(store.games.map((g) => g.platform), Game.platforms);
    expect(store.games.last.sourceId, 'source:Android');
  });

  testWidgets(
    'First opening offers optional folders and enters without login',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(AcervoApp(store: store, showSetup: true));
      expect(find.text('Capas'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Agora não'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(find.byTooltip('Novo jogo'), findsOneWidget);
      expect(calls, isEmpty);
      final reopened = CollectionStore(directory);
      await tester.runAsync(reopened.load);
      await tester.pumpWidget(
        AcervoApp(
          key: const ValueKey('restart'),
          store: reopened,
          showSetup: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Capas'), findsNothing);
      expect(find.byTooltip('Novo jogo'), findsOneWidget);
    },
  );

  testWidgets(
    'Folder organization is opt-in, remembered and scans after selection',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(AcervoApp(store: store, showSetup: true));
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.ensureVisible(find.byTooltip('Escolher pasta'));
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Escolher pasta'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(calls.first.method, 'configureFolder');
      expect(calls.first.arguments['createFolders'], true);
      expect(calls.any((c) => c.method == 'scanConfiguredFolder'), true);
      expect(store.folderName, 'Minhas capas');
      final reopened = CollectionStore(directory);
      await tester.runAsync(reopened.load);
      expect(reopened.setupComplete, true);
      expect(reopened.folderName, 'Minhas capas');
    },
  );

  testWidgets(
    'Cancelling folder picker keeps setup open and does not save settings',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Documents.channel, (_) async => null);
      tester.view.physicalSize = const Size(480, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(AcervoApp(store: store, showSetup: true));
      await tester.ensureVisible(find.byTooltip('Escolher pasta'));
      await tester.tap(find.byTooltip('Escolher pasta'));
      await tester.pumpAndSettle();
      expect(store.setupComplete, false);
      expect(find.text('Capas'), findsOneWidget);
    },
  );

  test(
    'Folder scan retains inferred platform and excludes saved source ids',
    () async {
      final candidate = ImportCandidate.fromMap({
        'path': '/cache/capa.png',
        'name': 'Jogo Android.png',
        'platform': 'Android',
        'sourceId': 'content://covers/android/1',
      });
      expect(candidate.platform, 'Android');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Documents.channel, (call) async {
            expect(call.arguments['knownIds'], ['content://already-imported']);
            return [
              {
                'path': candidate.path,
                'name': candidate.name,
                'platform': candidate.platform,
                'sourceId': candidate.sourceId,
              },
            ];
          });
      final result = await Documents.scanFolder(['content://already-imported']);
      expect(result.single.name, 'Jogo Android.png');
      expect(result.single.sourceId, 'content://covers/android/1');
    },
  );
}
