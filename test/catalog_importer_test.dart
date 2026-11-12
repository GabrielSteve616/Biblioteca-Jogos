import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acervo/models/game.dart';
import 'package:acervo/services/catalog_importer.dart';
import 'package:acervo/services/collection_store.dart';

void zipFile(String path, Map<String, List<int>> files) {
  final archive = Archive();
  for (final e in files.entries) {
    archive.add(ArchiveFile(e.key, e.value.length, e.value));
  }
  File(path).writeAsBytesSync(ZipEncoder().encode(archive));
}

void main() {
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('catalog_test_');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test(
    'Real catalog imports all 279 rows, six data fields and 279 cover matches with no platform',
    () {
      final batch = prepareCatalog({
        'xlsx': 'jogos/Catalogo_de_279_jogos_descricoes_melhoradas.xlsx',
        'zip': 'jogos/Capas_de_jogos_279_unificadas.zip',
        'directory': '${root.path}/images',
      });
      expect(batch.games.length, 279);
      expect(batch.images.length, 279);
      expect(
        batch.games.every(
          (g) => g.front.isNotEmpty && isCatalogZipImage(g.front),
        ),
        isTrue,
      );
      expect(Directory('${root.path}/images').listSync(), isEmpty);
      expect(readCatalogImage(batch.games.first.front), isNotEmpty);
      expect(
        batch.games.every(
          (g) =>
              g.description.isNotEmpty &&
              g.genre.isNotEmpty &&
              g.year.isNotEmpty &&
              g.rating.isNotEmpty &&
              g.players.isNotEmpty,
        ),
        isTrue,
      );
      expect(batch.games.every((g) => g.assignedPlatforms.isEmpty), isTrue);
      expect(batch.warnings, isEmpty);
      expect(batch.games.map((g) => g.id).toSet().length, 279);
      final secondRead = CatalogReader.spreadsheet(
        'jogos/Catalogo_de_279_jogos_descricoes_melhoradas.xlsx',
      );
      expect(secondRead.map((g) => g.id), batch.games.map((g) => g.id));
      expect(
        secondRead.map((g) => g.sourceId),
        batch.games.map((g) => g.sourceId),
      );
    },
  );
  test(
    'Matching honors image column, accents and punctuation; ambiguous and missing covers stay empty',
    () {
      final sheet = '''<worksheet><sheetData>
      <row r="1"><c r="B1" t="inlineStr"><is><t>Meu catálogo</t></is></c></row>
      <row r="3"><c r="C3" t="inlineStr"><is><t>Nome do jogo</t></is></c><c r="D3" t="inlineStr"><is><t>Imagem renomeada</t></is></c><c r="E3" t="inlineStr"><is><t>Plataforma</t></is></c></row>
      <row r="4"><c r="C4" t="inlineStr"><is><t>Ação: O Jogo</t></is></c><c r="E4" t="inlineStr"><is><t>Steam</t></is></c></row>
      <row r="5"><c r="C5" t="inlineStr"><is><t>Ação: O Jogo</t></is></c><c r="D5" t="inlineStr"><is><t>Outra edição.png</t></is></c></row>
      <row r="6"><c r="C6" t="inlineStr"><is><t>Ambíguo</t></is></c></row>
      <row r="7"><c r="C7" t="inlineStr"><is><t>Sem imagem</t></is></c></row>
    </sheetData></worksheet>''';
      zipFile('${root.path}/data.xlsx', {
        'xl/worksheets/sheet1.xml': utf8.encode(sheet),
      });
      zipFile('${root.path}/images.zip', {
        '../Acao - O Jogo.jpg': [1, 2, 3],
        'Outra edição.png': [4, 5, 6],
        'a/Ambíguo.jpg': [1],
        'b/Ambíguo.png': [2],
      });
      final batch = prepareCatalog({
        'xlsx': '${root.path}/data.xlsx',
        'zip': '${root.path}/images.zip',
        'directory': '${root.path}/out',
      });
      expect(batch.games.length, 4);
      expect(batch.games[0].front, isNotEmpty);
      expect(batch.games[1].front, isNot(batch.games[0].front));
      expect(batch.games[2].front, isEmpty);
      expect(batch.games[3].front, isEmpty);
      expect(
        batch.games.every((g) => g.assignedPlatforms.isEmpty),
        isTrue,
        reason: 'Spreadsheet platform must never be assigned',
      );
      expect(batch.warnings.length, 1);
      expect(File('${root.path}/Acao - O Jogo.jpg').existsSync(), isFalse);
      expect(batch.images.values.every((p) => isCatalogZipImage(p)), isTrue);
    },
  );
  test(
    'Shared strings, sparse columns and cached formula values are read without opening network links',
    () {
      zipFile('${root.path}/data.xlsx', {
        'xl/sharedStrings.xml': utf8.encode(
          '<sst><si><t>Title</t></si><si><r><t>Meu </t></r><r><t>jogo</t></r></si><si><t>Year</t></si></sst>',
        ),
        'xl/worksheets/sheet1.xml': utf8.encode(
          '<worksheet><sheetData><row><c r="B1" t="s"><v>0</v></c><c r="F1" t="s"><v>2</v></c></row><row><c r="B2" t="s"><v>1</v></c><c r="F2"><f>2000+24</f><v>2024</v></c></row></sheetData></worksheet>',
        ),
      });
      final games = CatalogReader.spreadsheet('${root.path}/data.xlsx');
      expect(games.single.title, 'Meu jogo');
      expect(games.single.year, '2024');
      expect(games.single.assignedPlatforms, isEmpty);
    },
  );
  test('Absent title column is rejected without changing original files', () {
    zipFile('${root.path}/bad.xlsx', {
      'xl/worksheets/sheet1.xml': utf8.encode(
        '<worksheet><sheetData><row><c t="inlineStr"><is><t>Não é um catálogo</t></is></c></row></sheetData></worksheet>',
      ),
    });
    final before = File('${root.path}/bad.xlsx').readAsBytesSync();
    expect(
      () => CatalogReader.spreadsheet('${root.path}/bad.xlsx'),
      throwsFormatException,
    );
    expect(File('${root.path}/bad.xlsx').readAsBytesSync(), before);
  });
  test(
    'Multiple and undefined platforms survive reload and backup; old JSON remains compatible',
    () async {
      final store = CollectionStore(root);
      await store.load();
      final multi = Game(id: 'multi', title: 'Duas coleções')
        ..assignedPlatforms = ['Steam', 'PS2'];
      final none = Game(id: 'none', title: 'Organizar depois', platform: '');
      await store.addAll([multi, none]);
      final reopened = CollectionStore(root);
      await reopened.load();
      expect(reopened.games.first.assignedPlatforms, ['Steam', 'PS2']);
      expect(reopened.games.last.assignedPlatforms, isEmpty);
      final backup = await store.backup();
      await reopened.restore(backup);
      expect(reopened.games.first.assignedPlatforms, ['Steam', 'PS2']);
      final old = multi.toJson()..remove('additionalPlatforms');
      expect(Game.fromJson(old).assignedPlatforms, ['Steam']);
      final before = await store.database.readAsString();
      await expectLater(store.addAll([multi]), throwsFormatException);
      expect(await store.database.readAsString(), before);
    },
  );
  test(
    'All supplied covers normalize and save in one batch without replacing existing games',
    () async {
      final batch = prepareCatalog({
        'xlsx': 'jogos/Catalogo_de_279_jogos_descricoes_melhoradas.xlsx',
        'zip': 'jogos/Capas_de_jogos_279_unificadas.zip',
        'directory': '${root.path}/images',
      });
      final store = CollectionStore(root);
      await store.load();
      await store.put(
        Game(
          id: 'existing',
          title: 'Coleção preservada',
          platform: 'PS5',
          platinum: true,
        ),
      );
      final copied = <String, String>{};
      for (var i = 0; i < batch.games.length; i++) {
        final game = batch.games[i];
        if (!copied.containsKey(game.front)) {
          final source = File('${root.path}/selected_$i');
          await source.writeAsBytes(readCatalogImage(game.front));
          copied[game.front] = await store.importImage(source.path);
        }
        game.front = copied[game.front]!;
        if (i.isEven) game.assignedPlatforms = ['Steam', 'PS3'];
      }
      var writes = 0;
      store.addListener(() => writes++);
      await store.addAll(batch.games);
      expect(writes, 1);
      expect(store.games.length, 280);
      expect(store.games.first.platinum, isTrue);
      expect(
        store.games
            .skip(1)
            .every(
              (g) =>
                  g.front.endsWith('.png') &&
                  File(store.thumb(g.front)).existsSync(),
            ),
        isTrue,
      );
      final reopened = CollectionStore(root);
      await reopened.load();
      expect(reopened.games[1].assignedPlatforms, ['Steam', 'PS3']);
      expect(reopened.games[2].assignedPlatforms, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
