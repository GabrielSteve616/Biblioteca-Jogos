import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acervo/screens/catalog_import.dart';
import 'package:acervo/services/catalog_importer.dart';
import 'package:acervo/services/collection_store.dart';
import 'package:acervo/theme/cyber_theme.dart';

void main() {
  testWidgets('Import review visual checks with actual 279-game catalog', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('CAPTURE')) return;
    tester.view.physicalSize = const Size(480, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory root;
    late CollectionStore store;
    late CatalogBatch batch;
    await tester.runAsync(() async {
      for (final entry in {
        'Roboto': 'C:/Windows/Fonts/segoeui.ttf',
        'monospace': 'C:/Windows/Fonts/consola.ttf',
        'MaterialIcons':
            'C:/Walkman-tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      }.entries) {
        await (FontLoader(entry.key)..addFont(
              File(
                entry.value,
              ).readAsBytes().then((b) => ByteData.sublistView(b)),
            ))
            .load();
      }
      root = await Directory.systemTemp.createTemp('catalog_capture_');
      store = CollectionStore(root);
      await store.load();
      batch = prepareCatalog({
        'xlsx': 'jogos/Catalogo_de_279_jogos_descricoes_melhoradas.xlsx',
        'zip': 'jogos/Capas_de_jogos_279_unificadas.zip',
        'directory': '${root.path}/preview',
      });
    });
    final key = GlobalKey();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Cyber.theme,
            builder: (_, child) => CyberBackdrop(child: child!),
            home: CatalogImport(store: store, initialBatch: batch),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('importacao-revisao');
    await tester.tap(find.byTooltip('Selecionar todos os visíveis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atribuir plataforma aos selecionados'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Steam'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'PS3'));
    await tester.pumpAndSettle();
    await capture('importacao-plataformas');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    await capture('importacao-lote');
    expect(batch.games.every((g) => g.assignedPlatforms.length == 2), isTrue);
    expect(store.games, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => root.delete(recursive: true));
  });
}
