import 'dart:convert';
import 'dart:io';
import 'package:acervo/services/catalog_importer.dart';

void main() {
  final temp = Directory.systemTemp.createTempSync('biblioteca_catalog_check_');
  try {
    final sources = Directory('jogos').listSync().whereType<File>().toList();
    final sheets = sources
        .where((f) => f.path.toLowerCase().endsWith('.xlsx'))
        .toList();
    final zips = sources
        .where((f) => f.path.toLowerCase().endsWith('.zip'))
        .toList();
    if (sheets.length != 1 || zips.length != 1) {
      throw StateError('A pasta jogos deve conter uma planilha e um ZIP.');
    }
    final batch = prepareCatalog({
      'xlsx': sheets.single.path,
      'zip': zips.single.path,
      'directory': temp.path,
    });
    final report = {
      'jogos': batch.games.length,
      'imagensNoZip': batch.images.length,
      'capasVinculadas': batch.games.where((g) => g.front.isNotEmpty).length,
      'comDescricao': batch.games.where((g) => g.description.isNotEmpty).length,
      'comGenero': batch.games.where((g) => g.genre.isNotEmpty).length,
      'comAno': batch.games.where((g) => g.year.isNotEmpty).length,
      'comClassificacao': batch.games.where((g) => g.rating.isNotEmpty).length,
      'comJogadores': batch.games.where((g) => g.players.isNotEmpty).length,
      'plataformasPredefinidas': batch.games
          .where((g) => g.assignedPlatforms.isNotEmpty)
          .length,
      'avisos': batch.warnings,
      'semCapa': batch.games
          .where((g) => g.front.isEmpty)
          .map((g) => g.title)
          .toList(),
    };
    const encoder = JsonEncoder.withIndent('  ');
    File(
      'docs/import-validation.json',
    ).writeAsStringSync(encoder.convert(report));
    stdout.writeln(encoder.convert(report));
  } finally {
    temp.deleteSync(recursive: true);
  }
}
