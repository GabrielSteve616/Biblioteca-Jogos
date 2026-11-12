import '../services/import_coordinator.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game.dart';
import '../services/catalog_importer.dart';
import '../services/collection_store.dart';
import '../widgets/platform_picker.dart';

class CatalogImport extends StatefulWidget {
  const CatalogImport({
    super.key,
    required this.store,
    this.initialBatch,
    this.coordinator,
  });
  final CollectionStore store;
  final CatalogBatch? initialBatch;
  final ImportCoordinator? coordinator;
  @override
  State<CatalogImport> createState() => _CatalogImportState();
}

class _CatalogImportState extends State<CatalogImport> {
  late CatalogBatch? batch = widget.initialBatch;
  final selected = <String>{};
  final imported = <String>{};
  final importedGames = <String, Game>{};
  late final coordinator =
      widget.coordinator ?? ImportCoordinator.forStore(widget.store);
  final sessions = <Directory>[];
  bool busy = false, onlyUnassigned = false;
  String query = '', status = '', error = '';
  List<Game> get visible => (batch?.games ?? [])
      .where(
        (g) =>
            catalogKey(g.title).contains(catalogKey(query)) &&
            (!onlyUnassigned || g.assignedPlatforms.isEmpty),
      )
      .toList();
  @override
  void initState() {
    super.initState();
    if (batch != null) _markImported(batch!);
  }

  void _markImported(CatalogBatch data) {
    imported.clear();
    importedGames.clear();
    final existing = widget.store.games;
    final byId = {for (final game in existing) game.id: game};
    final currentIds = data.games.map((g) => g.id).toSet();
    final previous = existing
        .where((g) => g.id.startsWith('catalog_') && !currentIds.contains(g.id))
        .toList();
    bool same(Game a, Game b) =>
        a.title == b.title &&
        a.description == b.description &&
        a.genre == b.genre &&
        a.year == b.year &&
        a.rating == b.rating &&
        a.players == b.players;
    for (final game in data.games) {
      if (byId.containsKey(game.id)) {
        imported.add(game.id);
        importedGames[game.id] = byId[game.id]!;
        continue;
      }
      var index = previous.indexWhere(
        (g) =>
            g.id.split('_').last == game.id.split('_').last &&
            catalogKey(g.title) == catalogKey(game.title) &&
            g.year.trim() == game.year.trim(),
      );
      if (index < 0) index = previous.indexWhere((g) => same(g, game));
      if (index >= 0) {
        imported.add(game.id);
        importedGames[game.id] = previous[index];
        previous.removeAt(index);
      }
    }
  }

  Future<void>? _cleanupFuture;
  Future<void> cleanup() => _cleanupFuture ??= _cleanupSessions();
  Future<void> _cleanupSessions() async {
    final parent = Directory('${widget.store.root.path}/catalog_inputs');
    if (!await parent.exists()) return;
    final parentPath = (await parent.resolveSymbolicLinks()).replaceAll(
      '\\',
      '/',
    );
    for (final directory in sessions) {
      try {
        if (!await directory.exists()) continue;
        var actual = (await directory.resolveSymbolicLinks()).replaceAll(
          '\\',
          '/',
        );
        var base = parentPath;
        if (Platform.isWindows) {
          actual = actual.toLowerCase();
          base = base.toLowerCase();
        }
        if (actual.startsWith('$base/') &&
            actual.split('/').last.startsWith('batch_')) {
          await directory.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    unawaited(cleanup());
    super.dispose();
  }

  Future<void> load({bool folder = false, bool bundled = false}) async {
    setState(() {
      busy = true;
      error = '';
      status = 'Lendo arquivos…';
    });
    try {
      List<String> files;
      final base = await Directory(
        '${widget.store.root.path}/catalog_inputs',
      ).create(recursive: true);
      final input = await base.createTemp('batch_');
      sessions.add(input);
      if (bundled) {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        final assets = manifest
            .listAssets()
            .where(
              (p) =>
                  p.startsWith('jogos/') &&
                  (p.toLowerCase().endsWith('.xlsx') ||
                      p.toLowerCase().endsWith('.zip')),
            )
            .toList();
        files = [];
        for (var i = 0; i < assets.length; i++) {
          final data = await rootBundle.load(assets[i]);
          final file = File('${input.path}/$i.${assets[i].split('.').last}');
          await file.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          files.add(file.path);
        }
      } else {
        files = await Documents.catalogFiles(folder: folder);
      }
      if (files.isEmpty) return;
      final sheets = files
          .where((p) => p.toLowerCase().endsWith('.xlsx'))
          .toList();
      final zips = files
          .where((p) => p.toLowerCase().endsWith('.zip'))
          .toList();
      if (sheets.length != 1 || zips.length > 1) {
        throw const FormatException(
          'Escolha uma planilha .xlsx e, opcionalmente, um ZIP de capas.',
        );
      }
      final output = await Directory('${input.path}/images').create();
      final result = await compute(prepareCatalog, {
        'xlsx': sheets.single,
        'zip': zips.isEmpty ? '' : zips.single,
        'directory': output.path,
      });
      if (!mounted) return;
      setState(() {
        batch = result;
        _markImported(result);
        selected.clear();
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'Não foi possível ler os arquivos: $e',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> platforms(Game game) async {
    final result = await choosePlatforms(context, game.assignedPlatforms);
    if (result != null && mounted) {
      setState(() => game.assignedPlatforms = result);
    }
  }

  Future<void> bulk() async {
    final result = await choosePlatforms(
      context,
      [],
      hint:
          'Substitui as plataformas dos ${selected.length} jogos selecionados. Você pode marcar mais de uma ou deixar sem plataforma.',
    );
    if (result != null && mounted) {
      setState(() {
        for (final g in batch!.games) {
          if (selected.contains(g.id)) g.assignedPlatforms = result;
        }
      });
    }
  }

  Future<void> image(Game game) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ImageChooser(images: batch!.images),
    );
    if (result != null && mounted) setState(() => game.front = result);
  }

  Future<void> finish({required bool all}) async {
    if (busy || batch == null) return;
    final chosen = batch!.games
        .where(
          (g) => !imported.contains(g.id) && (all || selected.contains(g.id)),
        )
        .toList();
    if (chosen.isEmpty) return;
    setState(() {
      busy = true;
      error = '';
      status = 'Preparando importação…';
    });
    final transferredSessions = List<Directory>.of(sessions);
    sessions.clear();
    try {
      await coordinator.start(chosen, transferredSessions);
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Importação iniciada em segundo plano.')),
      );
      Navigator.pop(context);
    } catch (e) {
      sessions.addAll(transferredSessions);
      if (!mounted) await _cleanupSessions();
      if (mounted) {
        setState(() => error = 'Não foi possível iniciar a importação: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void details(Game game) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(game.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final entry in {
              'Descrição': game.description,
              'Gênero': game.genre,
              'Ano': game.year,
              'Classificação': game.rating,
              'Jogadores': game.players,
            }.entries)
              if (entry.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('${entry.key}: ${entry.value}'),
                ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final games = visible;
    final selectable = games.where((g) => !imported.contains(g.id)).toList();
    final available =
        batch?.games.where((g) => !imported.contains(g.id)).length ?? 0;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Importar jogos')),
        body: Column(
          children: [
            if (busy) ...[
              const LinearProgressIndicator(),
              Padding(padding: const EdgeInsets.all(12), child: Text(status)),
            ],
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (batch == null)
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 64),
                        const SizedBox(height: 20),
                        const Text(
                          'Excel + ZIP',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Escolha os arquivos. As plataformas serão definidas por você na revisão.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: busy ? null : () => load(bundled: true),
                          icon: const Icon(Icons.folder_copy_outlined),
                          label: const Text('Carregar pasta jogos'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => load(),
                          icon: const Icon(Icons.file_open_outlined),
                          label: const Text('Escolher Excel e ZIP'),
                        ),
                        TextButton.icon(
                          onPressed: busy ? null : () => load(folder: true),
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Escolher pasta no celular'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${batch!.games.length} jogos • ${batch!.games.where((g) => g.front.isNotEmpty).length} capas • ${imported.length} já importados',
                          ),
                        ),
                        Text('${selected.length} selecionados'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      enabled: !busy,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar jogo',
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Selecionar todos os visíveis',
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  final all =
                                      selectable.isNotEmpty &&
                                      selectable.every(
                                        (g) => selected.contains(g.id),
                                      );
                                  for (final g in selectable) {
                                    all
                                        ? selected.remove(g.id)
                                        : selected.add(g.id);
                                  }
                                }),
                          icon: Icon(
                            selectable.isNotEmpty &&
                                    selectable.every(
                                      (g) => selected.contains(g.id),
                                    )
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                          ),
                        ),
                        FilterChip(
                          label: const Text('Sem plataforma'),
                          selected: onlyUnassigned,
                          onSelected: busy
                              ? null
                              : (v) => setState(() => onlyUnassigned = v),
                        ),
                        TextButton.icon(
                          onPressed: busy || selected.isEmpty ? null : bulk,
                          icon: const Icon(Icons.devices),
                          label: const Text(
                            'Atribuir plataforma aos selecionados',
                          ),
                        ),
                      ],
                    ),
                    if (batch!.warnings.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Avisos'),
                              content: SizedBox(
                                width: 400,
                                child: SingleChildScrollView(
                                  child: Text(batch!.warnings.join('\n')),
                                ),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.info_outline),
                          label: Text('${batch!.warnings.length} avisos'),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final g = games[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: selected.contains(g.id),
                              onChanged: busy || imported.contains(g.id)
                                  ? null
                                  : (v) => setState(
                                      () => v == true
                                          ? selected.add(g.id)
                                          : selected.remove(g.id),
                                    ),
                            ),
                            InkWell(
                              onTap: busy || imported.contains(g.id)
                                  ? null
                                  : () => image(g),
                              child: SizedBox(
                                width: 52,
                                height: 74,
                                child: g.front.isEmpty
                                    ? const Icon(
                                        Icons.add_photo_alternate_outlined,
                                      )
                                    : _CatalogPreview(reference: g.front),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (imported.contains(g.id))
                                    const Text(
                                      'Já na biblioteca',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  Text(
                                    g.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: busy || imported.contains(g.id)
                                        ? null
                                        : () => platforms(g),
                                    icon: const Icon(Icons.devices, size: 16),
                                    label: Text(
                                      importedGames[g.id]?.platformLabel ??
                                          g.platformLabel,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              enabled: !busy && !imported.contains(g.id),
                              tooltip: 'Opções do jogo',
                              onSelected: (v) {
                                if (v == 'details') details(g);
                                if (v == 'image') image(g);
                                if (v == 'remove') {
                                  setState(() {
                                    batch!.games.remove(g);
                                    selected.remove(g.id);
                                  });
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'details',
                                  child: Text('Ver dados'),
                                ),
                                PopupMenuItem(
                                  value: 'image',
                                  child: Text('Trocar capa'),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remover do lote'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'A importação continua em segundo plano.',
                        style: TextStyle(fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  busy ||
                                      selected.isEmpty ||
                                      coordinator.pending
                                  ? null
                                  : () => finish(all: false),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Importar selecionados (${selected.length})',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  busy || available == 0 || coordinator.pending
                                  ? null
                                  : () => finish(all: true),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Importar todos ($available)'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImageChooser extends StatefulWidget {
  const _ImageChooser({required this.images});
  final Map<String, String> images;
  @override
  State<_ImageChooser> createState() => _ImageChooserState();
}

class _ImageChooserState extends State<_ImageChooser> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final images = widget.images.entries
        .where((e) => catalogKey(e.key).contains(catalogKey(query)))
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar capa no ZIP',
                ),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final files = await Documents.images();
                if (context.mounted && files.isNotEmpty) {
                  Navigator.pop(context, files.first);
                }
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('Escolher imagem local'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: images.length,
                itemBuilder: (_, i) => ListTile(
                  leading: SizedBox(
                    width: 40,
                    height: 56,
                    child: _CatalogPreview(reference: images[i].value),
                  ),
                  title: Text(images[i].key),
                  onTap: () => Navigator.pop(context, images[i].value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogPreview extends StatefulWidget {
  const _CatalogPreview({required this.reference});
  final String reference;
  @override
  State<_CatalogPreview> createState() => _CatalogPreviewState();
}

class _CatalogPreviewState extends State<_CatalogPreview> {
  Future<Uint8List>? bytes;
  void load() {
    bytes = isCatalogZipImage(widget.reference)
        ? compute(readCatalogImage, widget.reference)
        : null;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(_CatalogPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference) load();
  }

  @override
  Widget build(BuildContext context) {
    Widget broken() => const Icon(Icons.broken_image_outlined);
    if (bytes == null) {
      return Image.file(
        File(widget.reference),
        fit: BoxFit.cover,
        cacheWidth: 104,
        errorBuilder: (_, _, _) => broken(),
      );
    }
    return FutureBuilder<Uint8List>(
      future: bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) return broken();
        if (!snapshot.hasData) {
          return const Icon(Icons.image_outlined);
        }
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          cacheWidth: 104,
          errorBuilder: (_, _, _) => broken(),
        );
      },
    );
  }
}
