import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acervo/main.dart';
import 'package:acervo/models/game.dart';
import 'package:acervo/services/collection_store.dart';
import 'package:acervo/widgets/game_box_3d.dart';
import 'package:acervo/theme/cyber_theme.dart';
import 'package:acervo/screens/folder_setup.dart';
import 'package:acervo/screens/game_detail.dart';

void main() {
  testWidgets('Visual review captures (optional)', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE')) return;
    tester.view.physicalSize = const Size(480, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late CollectionStore store;
    late Directory temp;
    await tester.runAsync(() async {
      final font = FontLoader('Roboto')
        ..addFont(
          File(
            'C:/Windows/Fonts/segoeui.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await font.load();
      final mono = FontLoader('monospace')
        ..addFont(
          File(
            'C:/Windows/Fonts/consola.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await mono.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            'C:/Walkman-tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await icons.load();
      temp = await Directory.systemTemp.createTemp('acervo_visual_');
      store = CollectionStore(temp);
      await store.load();
      for (var i = 0; i < 4; i++) {
        final game = Game.empty()
          ..id = 'visual_$i'
          ..title = [
            'Horizonte azul',
            'Órbita',
            'Além do tempo',
            'A última jornada',
          ][i]
          ..platform = ['PS1', 'PS3', 'PS4', 'Steam'][i]
          ..finished = i < 2
          ..platinum = i == 1
          ..complete = i == 3;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final colors = [
          const Color(0xff285d91),
          const Color(0xff5b397a),
          const Color(0xff34726a),
          const Color(0xff945640),
        ];
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 400, 540),
          Paint()..color = colors[i],
        );
        canvas.drawCircle(
          const Offset(290, 160),
          140,
          Paint()..color = Colors.white.withValues(alpha: .17),
        );
        canvas.drawPath(
          Path()
            ..moveTo(0, 480)
            ..lineTo(280, 200)
            ..lineTo(400, 420)
            ..lineTo(400, 540)
            ..lineTo(0, 540)
            ..close(),
          Paint()..color = Colors.black.withValues(alpha: .35),
        );
        final tp = TextPainter(
          text: TextSpan(
            text: game.title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontFamily: "Roboto",
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 310);
        tp.paint(canvas, const Offset(36, 280));
        final picture = recorder.endRecording();
        final image = await picture.toImage(400, 540);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${temp.path}/source.png');
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        game.front = await store.importImage(file.path);
        game.description = 'Uma história para guardar na sua coleção pessoal.';
        await store.put(game);
        image.dispose();
        picture.dispose();
      }
    });
    final key = GlobalKey();
    Future<void> capture(String name) async {
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/$name.png').writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.runAsync(() async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: AcervoApp(store: store),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await capture('biblioteca');
    await tester.tap(find.byTooltip('Ver em estante'));
    await tester.pumpAndSettle();
    await capture('estante');
    await tester.tap(find.byTooltip('Ver em grade'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Cyber.theme,
            builder: (_, child) => CyberBackdrop(child: child!),
            home: Scaffold(
              appBar: AppBar(title: const Text('Além do tempo • PS4')),
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: GameBox3D(game: store.games[2], store: store),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    Future<void> tapObject(String part) async {
      final state = tester.state<GameBox3DState>(find.byType(GameBox3D));
      final point = state.visiblePartCenter(part);
      expect(point, isNotNull, reason: 'Touchable $part');
      await tester.tapAt(
        tester.getTopLeft(find.byKey(const ValueKey('case-touch-surface'))) +
            point!,
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    }

    await capture('caixa-fechada');
    final angles = tester.state<GameBox3DState>(find.byType(GameBox3D));
    angles.view(1.42);
    await tester.pump();
    await capture('lombada-ps4');
    angles.reset();
    await tester.pump();
    final scene = tester.state<GameBox3DState>(find.byType(GameBox3D));
    scene.view(3.141592653589793);
    await tester.pump();
    await capture('contracapa-retro');
    scene.reset();
    await tester.pump();
    await tapObject('lid');
    await tester.pumpAndSettle();
    await capture('caixa-aberta');
    await tapObject('media');
    await tester.pumpAndSettle();
    await capture('disco');
    final androidGame = store.games[2].copy()
      ..platform = 'Android'
      ..title = 'NEON / RUNNER';
    await tester.runAsync(() async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Cyber.theme,
            builder: (_, child) => CyberBackdrop(child: child!),
            home: Scaffold(
              appBar: AppBar(title: const Text('Android')),
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: GameBox3D(
                  key: const ValueKey('android'),
                  game: androidGame,
                  store: store,
                ),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    await capture('android-case');
    expect(
      tester.state<GameBox3DState>(find.byType(GameBox3D)).usesImportedMesh,
      isTrue,
    );
    await tapObject('lid');
    await tester.pumpAndSettle();
    await tapObject('media');
    await tester.pumpAndSettle();
    await capture('android-disco');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: Cyber.theme,
          builder: (_, child) => CyberBackdrop(child: child!),
          home: FolderSetup(store: store, onDone: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture('primeira-abertura');
    for (final platform in ['PS1', 'PS2', 'PS3', 'PS4', 'PS5', 'Steam']) {
      final sample = store.games[2].copy()..platform = platform;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: Cyber.theme,
              builder: (_, child) => CyberBackdrop(child: child!),
              home: Scaffold(
                appBar: AppBar(title: Text(platform)),
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: GameBox3D(
                    key: ValueKey('physical-$platform'),
                    game: sample,
                    store: store,
                  ),
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      await capture('modelo-${platform.toLowerCase()}');
      final state = tester.state<GameBox3DState>(find.byType(GameBox3D));
      state.view(1.5707963267948966);
      await tester.pump();
      expect(
        state.visiblePartCenter('spine'),
        isNotNull,
        reason: '$platform printed spine must exist',
      );
      await capture('lombada-${platform.toLowerCase()}');
    }
    final stickers = store.games[2].copy()
      ..finished = true
      ..platinum = true
      ..complete = true;
    await tester.runAsync(() async {
      await store.put(stickers);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Cyber.theme,
            builder: (_, child) => CyberBackdrop(child: child!),
            home: GameDetail(store: store, id: stickers.id),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));
    });
    await tester.pumpAndSettle();
    await capture('adesivos-e-controles');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => temp.delete(recursive: true));
  });
}
