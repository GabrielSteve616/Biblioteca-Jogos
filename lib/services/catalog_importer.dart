import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';
import '../models/game.dart';

String catalogKey(String text) {
  const groups = {
    'a': 'áàâãäå',
    'e': 'éèêë',
    'i': 'íìîï',
    'o': 'óòôõö',
    'u': 'úùûü',
    'c': 'ç',
    'n': 'ñ',
  };
  var value = text.toLowerCase();
  for (final entry in groups.entries) {
    for (final rune in entry.value.runes) {
      value = value.replaceAll(String.fromCharCode(rune), entry.key);
    }
  }
  return value.replaceAll('&', 'and').replaceAll(RegExp('[^a-z0-9]'), '');
}

String fileStem(String name) => name
    .replaceAll('\\', '/')
    .split('/')
    .last
    .replaceFirst(RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false), '');

const _zipPrefix = 'catalog-zip:';
bool isCatalogZipImage(String value) => value.startsWith(_zipPrefix);
String catalogZipImage(String path, String entry) =>
    '$_zipPrefix${base64Url.encode(utf8.encode(jsonEncode([path, entry])))}';
List<String> catalogZipParts(String value) => List<String>.from(
  jsonDecode(utf8.decode(base64Url.decode(value.substring(_zipPrefix.length))))
      as List,
);
Uint8List readCatalogImage(String reference) {
  final parts = catalogZipParts(reference);
  final input = InputFileStream(parts[0]);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final file = archive.findFile(parts[1]);
    if (file == null ||
        !file.isFile ||
        file.isSymbolicLink ||
        file.size > 24 * 1024 * 1024) {
      throw const FormatException('Capa indisponível no ZIP.');
    }
    return Uint8List.fromList(file.readBytes()!);
  } finally {
    input.closeSync();
  }
}

const catalogFields = {
  'title': ['nome do jogo', 'nome', 'titulo', 'jogo', 'name', 'game', 'title'],
  'description': ['descricao do jogo', 'descricao', 'description', 'sinopse'],
  'genre': ['genero', 'generos', 'genre', 'genres'],
  'year': [
    'ano de lancamento',
    'ano',
    'lancamento',
    'year',
    'released',
    'release date',
  ],
  'rating': [
    'classificacao esrb',
    'classificacao indicativa',
    'classificacao',
    'esrb',
    'rating',
  ],
  'players': [
    'n de jogadores',
    'numero de jogadores',
    'n jogadores',
    'jogadores',
    'players',
  ],
  'image': [
    'imagem renomeada',
    'imagem',
    'capa',
    'arquivo da imagem',
    'nome da imagem',
    'cover',
    'image',
    'filename',
  ],
};

class CatalogBatch {
  CatalogBatch(this.games, this.images, this.warnings, this.directory);
  final List<Game> games;
  final Map<String, String> images;
  final List<String> warnings;
  final String directory;
}

class CatalogReader {
  static List<Game> spreadsheet(String path) {
    if (File(path).lengthSync() > 32 * 1024 * 1024) {
      throw const FormatException('A planilha excede 32 MB.');
    }
    final input = InputFileStream(path);
    try {
      final archive = ZipDecoder().decodeStream(input, verify: true);
      String xml(ArchiveFile file) {
        if (file.size > 16 * 1024 * 1024) {
          throw const FormatException(
            'Aba muito grande. Limite: 16 MB de XML.',
          );
        }
        final text = utf8.decode(file.readBytes()!);
        if (text.contains('<!DOCTYPE')) {
          throw const FormatException('XML não suportado.');
        }
        return text;
      }

      final shared = <String>[];
      final strings = archive.findFile('xl/sharedStrings.xml');
      if (strings != null) {
        for (final si in XmlDocument.parse(
          xml(strings),
        ).findAllElements('si')) {
          shared.add(si.findAllElements('t').map((e) => e.innerText).join());
        }
      }
      final sheets =
          archive.files
              .where(
                (f) =>
                    RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      final games = <Game>[];
      final fingerprint = sha256
          .convert(File(path).readAsBytesSync())
          .toString();
      for (final sheet in sheets) {
        Map<String, int>? header;
        var seen = 0;
        for (final row in XmlDocument.parse(
          xml(sheet),
        ).findAllElements('row')) {
          final cells = <int, String>{};
          var fallback = 0;
          for (final c in row.findElements('c')) {
            final address = c.getAttribute('r') ?? '';
            var column = 0;
            for (final rune in address.toUpperCase().codeUnits.takeWhile(
              (c) => c >= 65 && c <= 90,
            )) {
              column = column * 26 + rune - 64;
            }
            column = column == 0 ? fallback : column - 1;
            fallback = column + 1;
            final type = c.getAttribute('t');
            var text = c.getElement('v')?.innerText ?? '';
            if (type == 'inlineStr') {
              text = c.findAllElements('t').map((e) => e.innerText).join();
            }
            if (type == 's') {
              final index = int.tryParse(text);
              text = index != null && index >= 0 && index < shared.length
                  ? shared[index]
                  : '';
            }
            cells[column] = text.trim();
          }
          if (header == null) {
            if (seen++ > 40) break;
            final found = <String, int>{};
            for (final c in cells.entries) {
              for (final field in catalogFields.entries) {
                if (field.value.any(
                  (alias) => catalogKey(alias) == catalogKey(c.value),
                )) {
                  found[field.key] = c.key;
                }
              }
            }
            if (found.containsKey('title')) header = found;
            continue;
          }
          String value(String field) => cells[header![field]] ?? '';
          final title = value('title');
          if (title.isEmpty ||
              catalogFields['title']!.any(
                (v) => catalogKey(v) == catalogKey(title),
              )) {
            continue;
          }
          if (games.length >= 5000) {
            throw const FormatException(
              'Limite de 5.000 jogos por importação.',
            );
          }
          var year = value('year');
          final numeric = num.tryParse(year);
          if (numeric != null && numeric == numeric.roundToDouble()) {
            year = numeric.toInt().toString();
          }
          games.add(
            Game(
              id: 'catalog_${fingerprint.substring(0, 16)}_${games.length}',
              sourceId: 'catalog:$fingerprint:${games.length}',
              title: title,
              platform: '',
              description: value('description'),
              genre: value('genre'),
              year: year,
              rating: value('rating'),
              players: value('players'),
              // Temporary reference only; the import worker replaces it with a local path.
              front: value('image'),
            ),
          );
        }
      }
      if (games.isEmpty) {
        throw const FormatException(
          'Não encontrei jogos. A planilha deve ser .xlsx e ter uma coluna Nome do jogo ou Título.',
        );
      }
      return games;
    } finally {
      input.closeSync();
    }
  }
}

/// Runs in an isolate; paths are always synthetic and remain inside the session.
CatalogBatch prepareCatalog(Map<String, String> args) {
  final directory = Directory(args['directory']!)..createSync(recursive: true);
  final games = CatalogReader.spreadsheet(args['xlsx']!);
  final warnings = <String>[];
  final images = <String, String>{};
  final zipPath = args['zip'];
  if (zipPath != null && zipPath.isNotEmpty) {
    if (File(zipPath).lengthSync() > 256 * 1024 * 1024) {
      throw const FormatException('O ZIP excede 256 MB.');
    }
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      final files = archive.files
          .where(
            (f) =>
                f.isFile &&
                !f.isSymbolicLink &&
                RegExp(
                  r'\.(png|jpe?g|webp)$',
                  caseSensitive: false,
                ).hasMatch(f.name) &&
                !f.name.startsWith('__MACOSX/'),
          )
          .toList();
      if (files.length > 5000 ||
          files.fold<int>(0, (a, f) => a + f.size) > 512 * 1024 * 1024) {
        throw const FormatException(
          'ZIP muito grande. Limite: 5.000 imagens e 512 MB descompactados.',
        );
      }
      for (final file in files) {
        if (file.size > 24 * 1024 * 1024) {
          warnings.add('Imagem maior que 24 MB ignorada: ${file.name}');
          continue;
        }
        images[file.name] = catalogZipImage(zipPath, file.name);
      }
    } finally {
      input.closeSync();
    }
  }
  final index = <String, List<String>>{};
  for (final entry in images.entries) {
    index
        .putIfAbsent(catalogKey(fileStem(entry.key)), () => [])
        .add(entry.value);
  }
  for (final game in games) {
    final explicit = game.front;
    final exact = images[explicit];
    final byFile = explicit.isEmpty
        ? null
        : index[catalogKey(fileStem(explicit))];
    final byTitle = index[catalogKey(game.title)];
    final matches = byFile ?? byTitle ?? [];
    game.front = exact ?? (matches.length == 1 ? matches.single : '');
    if (matches.length > 1 && exact == null) {
      warnings.add('Mais de uma capa para ${game.title}. Escolha na revisão.');
    }
  }
  return CatalogBatch(games, images, warnings, directory.path);
}
