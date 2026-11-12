import 'dart:async';
import 'dart:io';
import '../services/import_coordinator.dart';
import '../widgets/platform_picker.dart';
import 'catalog_import.dart';
import '../widgets/book_shelf.dart';
import 'package:flutter/material.dart';
import '../models/game.dart';
import '../services/collection_store.dart';
import '../widgets/cover.dart';
import 'game_editor.dart';
import 'game_detail.dart';
import 'folder_setup.dart';
import '../theme/cyber_theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.store,
    this.startupError,
    this.scanFolderOnStart = false,
    this.coordinator,
  });
  final CollectionStore store;
  final String? startupError;
  final bool scanFolderOnStart;
  final ImportCoordinator? coordinator;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String query = '',
      platform = 'Todas',
      genre = 'Todos',
      progress = 'Todos',
      order = 'Título A–Z',
      viewMode = 'grade';
  bool busy = false;
  String? notice;
  late final importCoordinator =
      widget.coordinator ?? ImportCoordinator.forStore(widget.store);
  @override
  void initState() {
    super.initState();
    viewMode = widget.store.viewMode;
    order = widget.store.orderMode;
    notice = widget.startupError ?? widget.store.recoveryMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(importCoordinator.resumeIfPending());
    });
    if (widget.scanFolderOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) importConfiguredFolder();
      });
    }
  }

  void changeView(String value) {
    setState(() => viewMode = value);
    unawaited(
      widget.store.setViewMode(value).catchError((Object error) {
        snack('Não foi possível salvar a visualização: $error');
      }),
    );
  }

  void snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> task(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      snack('Não foi possível concluir: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editPlatforms(Game game) async {
    if (busy) return;
    final stored = widget.store.games.firstWhere((g) => g.id == game.id);
    final next = await choosePlatforms(context, stored.assignedPlatforms);
    if (next != null && mounted) {
      await task(
        () => widget.store.put(stored.copy()..assignedPlatforms = next),
      );
    }
  }

  void reorder(Game moving, Game target, List<Game> displayed) {
    if (moving.id == target.id || busy) return;
    final ids = displayed.map((g) => g.id).toList();
    final old = ids.indexOf(moving.id), next = ids.indexOf(target.id);
    if (old < 0 || next < 0) return;
    ids.insert(next, ids.removeAt(old));
    unawaited(
      task(() async {
        await widget.store.reorderVisible(ids);
        await widget.store.setOrderMode('Manual');
        if (mounted) setState(() => order = 'Manual');
      }),
    );
  }

  Widget draggable(Game game, List<Game> displayed, Widget child) =>
      DragTarget<Game>(
        onWillAcceptWithDetails: (details) =>
            !busy && details.data.id != game.id,
        onAcceptWithDetails: (details) =>
            reorder(details.data, game, displayed),
        builder: (context, candidates, rejected) => LongPressDraggable<Game>(
          key: ValueKey('drag-${game.id}'),
          data: game,
          maxSimultaneousDrags: busy ? 0 : 1,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 110,
              height: 155,
              child: Cover(game: game, store: widget.store),
            ),
          ),
          childWhenDragging: Opacity(opacity: .35, child: child),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (candidates.isNotEmpty)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Cyber.cyan, width: 3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                right: 0,
                child: PopupMenuButton<String>(
                  tooltip: 'Opções de ${game.title}',
                  padding: EdgeInsets.zero,
                  iconSize: 19,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (_) => editPlatforms(game),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'platforms',
                      child: Text('Plataformas'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> add() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameEditor(store: widget.store, game: Game.empty()),
      ),
    );
  }

  Future<void> importImages({bool folder = false}) => task(() async {
    final files = await Documents.images(multiple: true, folder: folder);
    for (var i = 0; i < files.length; i++) {
      final name = await widget.store.importImage(files[i]);
      final basename = CollectionStore.basename(
        files[i],
      ).replaceFirst(RegExp(r'^\d+_'), '');
      final title = basename
          .replaceFirst(RegExp(r'\.[^.]+$'), '')
          .replaceAll('_', ' ');
      final game = Game.empty()
        ..front = name
        ..title = title;
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => GameEditor(
            store: widget.store,
            game: game,
            batchPosition: 'Capa ${i + 1} de ${files.length}',
          ),
        ),
      );
      if (saved != true) break;
    }
    if (folder && files.isEmpty) {
      snack('Nenhuma imagem encontrada nesta pasta.');
    }
  });
  Future<void> configureFolder() async {
    if (busy) return;
    final scan = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => FolderSetup(
          store: widget.store,
          onDone: (locate) => Navigator.pop(routeContext, locate),
        ),
      ),
    );
    if (scan == true && mounted) await importConfiguredFolder();
  }

  Future<void> importConfiguredFolder() async {
    if (widget.store.folderName.isEmpty) {
      await configureFolder();
      return;
    }
    await task(() async {
      final images = await Documents.scanFolder(
        widget.store.games.map((g) => g.sourceId).where((id) => id.isNotEmpty),
      );
      if (images.isEmpty) {
        snack('Nenhuma capa nova encontrada na pasta escolhida.');
        return;
      }
      for (var i = 0; i < images.length; i++) {
        final item = images[i];
        final name = await widget.store.importImage(item.path);
        final game = Game.empty()
          ..front = name
          ..title = item.name
              .replaceFirst(RegExp(r'\.[^.]+$'), '')
              .replaceAll('_', ' ')
          ..platform = Game.platforms.contains(item.platform)
              ? item.platform
              : 'PS4'
          ..sourceId = item.sourceId;
        if (!mounted) return;
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => GameEditor(
              store: widget.store,
              game: game,
              batchPosition:
                  'Capa ${i + 1} de ${images.length} • ${game.platform}',
            ),
          ),
        );
        if (saved != true) break;
      }
    });
  }

  Future<void> export() => task(() async {
    final base = await Directory(
      '${widget.store.root.path}/backup_staging',
    ).create(recursive: true);
    final temporary = await base.createTemp('export_');
    try {
      final backup = File('${temporary.path}/Biblioteca-backup.json');
      await widget.store.writeBackup(backup);
      if (await Documents.saveBackup(backup.path)) {
        snack('Backup JSON salvo com os jogos e suas imagens.');
      }
    } finally {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    }
  });
  Future<void> restore() async {
    if (importCoordinator.pending) {
      snack('Aguarde a importação atual terminar antes de restaurar o backup.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar coleção?'),
        content: const Text(
          'O backup substituirá a coleção atual. Exporte sua coleção antes de continuar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Escolher backup'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await task(() async {
      final selectedPath = await Documents.openBackup();
      if (selectedPath == null) return;
      final copy = File(selectedPath);
      try {
        await widget.store.restoreFile(copy);
      } finally {
        if (await copy.exists()) await copy.delete();
      }
      if (mounted) {
        setState(() {
          notice = null;
          viewMode = widget.store.viewMode;
          order = widget.store.orderMode;
        });
      }
      snack('Coleção restaurada.');
    });
  }

  List<Game> filtered() {
    final result = widget.store.games.where((g) {
      if (!g.title.toLowerCase().contains(query.toLowerCase().trim())) {
        return false;
      }
      if (genre != 'Todos' &&
          widget.store.availableGenres.contains(genre) &&
          !g.genre.toLowerCase().contains(genre.toLowerCase().trim())) {
        return false;
      }
      if (platform == Game.unassigned && g.assignedPlatforms.isNotEmpty) {
        return false;
      }
      if (platform != 'Todas' &&
          platform != Game.unassigned &&
          !g.assignedPlatforms.contains(platform)) {
        return false;
      }
      return switch (progress) {
        'Zerados' || 'Fechados' => g.finished,
        'Não zerados' || 'Abertos' => !g.finished,
        'Platinados' => g.platinum,
        '100%' => g.complete,
        'Favoritos' => g.favorite,
        _ => true,
      };
    }).toList();
    if (order == 'Título A–Z' || order == 'Alfabética A–Z') {
      result.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    }
    if (order == 'Recentes') {
      result.sort((a, b) => b.created.compareTo(a.created));
    }
    if (order == 'Console') {
      result.sort((a, b) {
        final aKey = a.assignedPlatforms.isEmpty
            ? 'zzz'
            : a.assignedPlatforms.first;
        final bKey = b.assignedPlatforms.isEmpty
            ? 'zzz'
            : b.assignedPlatforms.first;
        final keyCompare = aKey.toLowerCase().compareTo(bKey.toLowerCase());
        if (keyCompare != 0) return keyCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }
    if (order == 'Gênero') {
      result.sort((a, b) {
        final aKey = a.genre.trim().isEmpty ? 'zzz' : a.genre.trim();
        final bKey = b.genre.trim().isEmpty ? 'zzz' : b.genre.trim();
        final keyCompare = aKey.toLowerCase().compareTo(bKey.toLowerCase());
        if (keyCompare != 0) return keyCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }
    if (order == 'Manual') {
      result.sort((a, b) {
        final indexA = widget.store.games.indexWhere((g) => g.id == a.id);
        final indexB = widget.store.games.indexWhere((g) => g.id == b.id);
        return indexA.compareTo(indexB);
      });
    }
    if (Game.platforms.contains(platform)) {
      return result
          .map(
            (g) => g.copy()
              ..assignedPlatforms = [
                platform,
                ...g.assignedPlatforms.where((p) => p != platform),
              ],
          )
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.store, importCoordinator]),
    builder: (context, _) {
      final games = filtered(), all = widget.store.games;
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Biblioteca',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          leading: const Icon(Icons.auto_stories_outlined, color: Cyber.cyan),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Visualização',
              initialValue: viewMode,
              onSelected: changeView,
              icon: Icon(switch (viewMode) {
                'estante' => Icons.shelves,
                'frontal' => Icons.library_books_rounded,
                _ => Icons.grid_view_rounded,
              }),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'grade',
                  child: Row(
                    children: const [
                      Icon(Icons.grid_view_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Grade'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'estante',
                  child: Row(
                    children: const [
                      Icon(Icons.shelves, size: 18),
                      SizedBox(width: 10),
                      Text('Estante'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'frontal',
                  child: Row(
                    children: const [
                      Icon(Icons.library_books_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Capa frontal'),
                    ],
                  ),
                ),
              ],
            ),
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (value) {
                if (value == 'catalog') {
                  if (importCoordinator.pending) {
                    snack(
                      'Aguarde a importação atual terminar ou retome a tarefa pausada.',
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CatalogImport(
                          store: widget.store,
                          coordinator: importCoordinator,
                        ),
                      ),
                    );
                  }
                }
                if (value == 'configure') configureFolder();
                if (value == 'scan') importConfiguredFolder();
                if (value == 'export') export();
                if (value == 'restore') restore();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'catalog',
                  child: ListTile(
                    leading: Icon(Icons.table_view_outlined),
                    title: Text('Importar Excel + ZIP'),
                  ),
                ),
                PopupMenuItem(
                  value: 'configure',
                  child: ListTile(
                    leading: Icon(Icons.folder_open),
                    title: Text('Pasta de capas'),
                  ),
                ),
                PopupMenuItem(
                  value: 'scan',
                  child: ListTile(
                    leading: Icon(Icons.manage_search),
                    title: Text('Buscar capas'),
                  ),
                ),
                PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.upload_file_outlined),
                    title: Text('Exportar backup'),
                  ),
                ),
                PopupMenuItem(
                  value: 'restore',
                  child: ListTile(
                    leading: Icon(Icons.restore),
                    title: Text('Restaurar backup'),
                  ),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Novo jogo',
          onPressed: busy ? null : add,
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            if (busy) const LinearProgressIndicator(minHeight: 2),
            if (importCoordinator.active ||
                importCoordinator.error != null ||
                importCoordinator.completed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          importCoordinator.error != null
                              ? Icons.error_outline
                              : importCoordinator.completed
                              ? Icons.check_circle_outline
                              : Icons.downloading,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            importCoordinator.error ??
                                (importCoordinator.completed
                                    ? 'Importação concluída'
                                    : 'Importando em segundo plano: ${importCoordinator.done}/${importCoordinator.total}'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (importCoordinator.error != null &&
                            !importCoordinator.active)
                          IconButton(
                            tooltip: 'Retomar importação',
                            onPressed: importCoordinator.retry,
                            icon: const Icon(Icons.refresh),
                          ),
                        if (importCoordinator.error != null &&
                            !importCoordinator.active)
                          IconButton(
                            tooltip: 'Cancelar importação',
                            onPressed: importCoordinator.discard,
                            icon: const Icon(Icons.close),
                          ),
                        if (importCoordinator.completed)
                          IconButton(
                            tooltip: 'Dispensar',
                            onPressed: importCoordinator.dismiss,
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                    if (importCoordinator.active)
                      LinearProgressIndicator(
                        value: importCoordinator.total == 0
                            ? null
                            : importCoordinator.done / importCoordinator.total,
                      ),
                  ],
                ),
              ),

            if (notice != null)
              MaterialBanner(
                content: Text(notice!),
                actions: [
                  IconButton(
                    tooltip: 'Restaurar backup',
                    onPressed: restore,
                    icon: const Icon(Icons.restore),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      metric(
                        all.length,
                        'Jogos',
                        Icons.sports_esports_outlined,
                        Cyber.cyan,
                      ),
                      const SizedBox(width: 8),
                      metric(
                        all.where((g) => g.finished).length,
                        'Zerados',
                        Icons.check_circle_outline,
                        Cyber.pink,
                      ),
                      const SizedBox(width: 8),
                      metric(
                        all.where((g) => g.platinum).length,
                        'Platinas',
                        Icons.emoji_events_outlined,
                        Cyber.yellow,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Cyber.panel,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Cyber.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              key: const ValueKey('platform_filter'),
                              value: platform,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                              ),
                              items:
                                  ['Todas', Game.unassigned, ...Game.platforms]
                                      .map(
                                        (p) => DropdownMenuItem(
                                          value: p,
                                          child: Text(
                                            p,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (p) => setState(() => platform = p!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<String>(
                        tooltip: 'Filtrar progresso',
                        initialValue: progress,
                        onSelected: (v) => setState(() => progress = v),
                        icon: Icon(
                          switch (progress) {
                            'Zerados' => Icons.check_circle,
                            'Não zerados' => Icons.radio_button_unchecked,
                            'Platinados' => Icons.emoji_events,
                            '100%' => Icons.workspace_premium,
                            'Favoritos' => Icons.favorite,
                            _ => Icons.filter_alt_outlined,
                          },
                          color: progress == 'Todos' ? Cyber.muted : Cyber.cyan,
                        ),
                        itemBuilder: (_) =>
                            [
                                  'Todos',
                                  'Zerados',
                                  'Não zerados',
                                  'Fechados',
                                  'Abertos',
                                  'Platinados',
                                  '100%',
                                  'Favoritos',
                                ]
                                .map(
                                  (v) => CheckedPopupMenuItem(
                                    value: v,
                                    checked: progress == v,
                                    child: Text(v),
                                  ),
                                )
                                .toList(),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Cyber.panel,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Cyber.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              key: const ValueKey('genre_filter'),
                              isExpanded: true,
                              value:
                                  widget.store.availableGenres.contains(genre)
                                  ? genre
                                  : 'Todos',
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                              ),
                              items: ['Todos', ...widget.store.availableGenres]
                                  .map(
                                    (g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(
                                        g,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (g) =>
                                  setState(() => genre = g ?? 'Todos'),
                            ),
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Ordenar',
                        initialValue: order,
                        onSelected: (v) {
                          setState(() => order = v);
                          unawaited(
                            widget.store.setOrderMode(v).catchError((
                              Object error,
                            ) {
                              snack(
                                'Não foi possível salvar a ordenação: $error',
                              );
                            }),
                          );
                        },
                        icon: const Icon(Icons.sort),
                        itemBuilder: (_) =>
                            [
                                  'Título A–Z',
                                  'Gênero',
                                  'Console',
                                  'Recentes',
                                  'Manual',
                                ]
                                .map(
                                  (v) => CheckedPopupMenuItem(
                                    value: v,
                                    checked: order == v,
                                    child: Text(v),
                                  ),
                                )
                                .toList(),
                      ),
                      IconButton(
                        tooltip: viewMode == 'grade'
                            ? 'Ver em estante'
                            : viewMode == 'estante'
                            ? 'Ver capa frontal'
                            : 'Ver em grade',
                        onPressed: () {
                          changeView(
                            viewMode == 'grade'
                                ? 'estante'
                                : viewMode == 'estante'
                                ? 'frontal'
                                : 'grade',
                          );
                        },
                        icon: Icon(switch (viewMode) {
                          'estante' => Icons.shelves,
                          'frontal' => Icons.library_books_rounded,
                          _ => Icons.grid_view_rounded,
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: games.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 80),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                all.isEmpty
                                    ? Icons.auto_stories_outlined
                                    : Icons.search_off,
                                size: 54,
                                color: Cyber.muted,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                all.isEmpty ? 'Sem jogos' : 'Sem resultados',
                                style: const TextStyle(color: Cyber.muted),
                              ),
                              const SizedBox(height: 12),
                              if (all.isEmpty)
                                IconButton.filledTonal(
                                  tooltip: 'Importar capas',
                                  onPressed: busy ? null : () => importImages(),
                                  icon: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isShelf = viewMode == 'estante';
                        final isFront = viewMode == 'frontal';
                        if (isShelf) {
                          return BookShelf(
                            games: games,
                            onPlatforms: editPlatforms,
                            onReorder: (moving, target) =>
                                reorder(moving, target, games),
                            store: widget.store,
                            onOpen: (game) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GameDetail(
                                  store: widget.store,
                                  id: game.id,
                                  preferredPlatform:
                                      Game.platforms.contains(platform)
                                      ? platform
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }
                        final columns =
                            (constraints.maxWidth / (isFront ? 135 : 185))
                                .floor()
                                .clamp(2, 7);
                        if (isFront) {
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 18,
                                  childAspectRatio: .72,
                                ),
                            itemCount: games.length,
                            itemBuilder: (context, index) {
                              final game = games[index];
                              return draggable(
                                game,
                                games,
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GameDetail(
                                        store: widget.store,
                                        id: game.id,
                                        preferredPlatform:
                                            Game.platforms.contains(platform)
                                            ? platform
                                            : null,
                                      ),
                                    ),
                                  ),
                                  child: Card(
                                    color: Cyber.panel,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Cover(
                                                game: game,
                                                store: widget.store,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            game.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            game.platformLabel,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Cyber.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 18,
                                childAspectRatio: .60,
                              ),
                          itemCount: games.length,
                          itemBuilder: (context, index) {
                            final game = games[index];
                            return draggable(
                              game,
                              games,
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GameDetail(
                                      store: widget.store,
                                      id: game.id,
                                      preferredPlatform:
                                          Game.platforms.contains(platform)
                                          ? platform
                                          : null,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Cover(
                                        game: game,
                                        store: widget.store,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      game.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );

  Widget metric(int value, String label, IconData icon, Color color) =>
      Expanded(
        child: Tooltip(
          message: label,
          child: Semantics(
            label: '$value $label',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: .09), Cyber.panel],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: .25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19, color: color),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      '$value',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
