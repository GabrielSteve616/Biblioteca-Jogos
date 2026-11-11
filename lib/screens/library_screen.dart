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
  });
  final CollectionStore store;
  final String? startupError;
  final bool scanFolderOnStart;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String query = '',
      platform = 'Todas',
      progress = 'Todos',
      order = 'Título A–Z';
  bool shelf = false, busy = false;
  String? notice;
  @override
  void initState() {
    super.initState();
    notice = widget.startupError ?? widget.store.recoveryMessage;
    if (widget.scanFolderOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) importConfiguredFolder();
      });
    }
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
    final data = await widget.store.backup();
    if (await Documents.saveBackup(data)) {
      snack('Backup salvo com os jogos e suas imagens.');
    }
  });
  Future<void> restore() async {
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
      final text = await Documents.openBackup();
      if (text == null) return;
      await widget.store.restore(text);
      if (mounted) setState(() => notice = null);
      snack('Coleção restaurada.');
    });
  }

  List<Game> filtered() {
    final result = widget.store.games.where((g) {
      if (!g.title.toLowerCase().contains(query.toLowerCase().trim())) {
        return false;
      }
      if (platform != 'Todas' && g.platform != platform) return false;
      return switch (progress) {
        'Zerados' => g.finished,
        'Não zerados' => !g.finished,
        'Platinados' => g.platinum,
        '100%' => g.complete,
        'Favoritos' => g.favorite,
        _ => true,
      };
    }).toList();
    if (order == 'Título A–Z') {
      result.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    }
    if (order == 'Recentes') {
      result.sort((a, b) => b.created.compareTo(a.created));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
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
            IconButton(
              tooltip: 'Importar capas',
              onPressed: busy ? null : () => importImages(),
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (value) {
                if (value == 'configure') configureFolder();
                if (value == 'scan') importConfiguredFolder();
                if (value == 'export') export();
                if (value == 'restore') restore();
              },
              itemBuilder: (_) => const [
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
                    title: Text('Exportar'),
                  ),
                ),
                PopupMenuItem(
                  value: 'restore',
                  child: ListTile(
                    leading: Icon(Icons.restore),
                    title: Text('Restaurar'),
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
                              value: platform,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                              ),
                              items: ['Todas', ...Game.platforms]
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(
                                        p,
                                        style: const TextStyle(fontSize: 13),
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
                      PopupMenuButton<String>(
                        tooltip: 'Ordenar',
                        initialValue: order,
                        onSelected: (v) => setState(() => order = v),
                        icon: const Icon(Icons.sort),
                        itemBuilder: (_) => ['Título A–Z', 'Recentes', 'Manual']
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
                        tooltip: shelf ? 'Ver em grade' : 'Ver em estante',
                        onPressed: () => setState(() => shelf = !shelf),
                        icon: Icon(
                          shelf ? Icons.grid_view_rounded : Icons.shelves,
                        ),
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
                        if (shelf) {
                          return BookShelf(
                            games: games,
                            store: widget.store,
                            onOpen: (game) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GameDetail(
                                  store: widget.store,
                                  id: game.id,
                                ),
                              ),
                            ),
                          );
                        }
                        final columns =
                            (constraints.maxWidth / (shelf ? 130 : 185))
                                .floor()
                                .clamp(2, 7);
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: shelf ? 6 : 18,
                                childAspectRatio: shelf ? .52 : .60,
                              ),
                          itemCount: games.length,
                          itemBuilder: (context, index) {
                            final game = games[index];
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GameDetail(
                                    store: widget.store,
                                    id: game.id,
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
                                  if (shelf)
                                    Container(
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xff21434c),
                                            Color(0xff583044),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.vertical(
                                          bottom: Radius.circular(3),
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
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
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
