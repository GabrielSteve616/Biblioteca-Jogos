import 'dart:io';
import 'package:flutter/material.dart';
import '../models/game.dart';
import '../services/collection_store.dart';
import '../widgets/game_box_3d.dart';
import '../widgets/cover.dart';
import 'game_editor.dart';
import '../widgets/progress_stickers.dart';

class GameDetail extends StatefulWidget {
  const GameDetail({super.key, required this.store, required this.id});
  final CollectionStore store;
  final String id;
  @override
  State<GameDetail> createState() => _GameDetailState();
}

class _GameDetailState extends State<GameDetail> {
  bool busy = false, artOnly = false;
  void error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível concluir: $e')));
    }
  }

  Future<void> update(Game game, void Function(Game) change) async {
    setState(() => busy = true);
    final copy = game.copy();
    change(copy);
    try {
      await widget.store.put(copy);
    } catch (e) {
      error(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final found = widget.store.games.where((g) => g.id == widget.id);
      if (found.isEmpty) {
        return const Scaffold(body: Center(child: Text('Jogo excluído.')));
      }
      final g = found.first;
      return Scaffold(
        appBar: AppBar(
          title: Text(g.title),
          actions: [
            IconButton(
              tooltip: 'Editar',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameEditor(store: widget.store, game: g),
                  ),
                );
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.platform,
                      style: const TextStyle(
                        color: Color(0xff7ab9ff),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (g.platform == 'Steam')
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Icon(
                          Icons.image_outlined,
                          semanticLabel: 'Somente arte',
                        ),
                        value: artOnly,
                        onChanged: (v) => setState(() => artOnly = v),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: (MediaQuery.sizeOf(context).height * .60).clamp(
                        440.0,
                        650.0,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          artOnly
                              ? (g.front.isEmpty
                                    ? Cover(
                                        game: g,
                                        store: widget.store,
                                        thumbnail: false,
                                      )
                                    : InteractiveViewer(
                                        child: Image.file(
                                          File(widget.store.path(g.front)),
                                          fit: BoxFit.contain,
                                        ),
                                      ))
                              : GameBox3D(
                                  key: ValueKey(
                                    '${g.id}-${g.front}-${g.back}-${g.disc}-${g.title}-${g.description}-${g.genre}-${g.year}-${g.rating}-${g.players}-${g.platform}',
                                  ),
                                  game: g,
                                  store: widget.store,
                                ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: ProgressControls(
                              game: g,
                              busy: busy,
                              onToggle: (key) => update(g, (c) {
                                if (key == 'finished') c.finished = !c.finished;
                                if (key == 'platinum') c.platinum = !c.platinum;
                                if (key == 'complete') c.complete = !c.complete;
                                if (key == 'favorite') c.favorite = !c.favorite;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (g.description.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(g.description, style: const TextStyle(height: 1.6)),
                    ],
                    const SizedBox(height: 16),
                    for (final entry in {
                      'Gênero': g.genre,
                      'Lançamento': g.year,
                      'Classificação': g.rating,
                      'Jogadores': g.players,
                    }.entries)
                      if (entry.value.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('${entry.key}: ${entry.value}'),
                        ),
                    if (g.notes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'SUAS ANOTAÇÕES',
                        style: TextStyle(
                          color: Color(0xff7ab9ff),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(g.notes),
                    ],
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      children: [
                        IconButton.outlined(
                          onPressed: busy
                              ? null
                              : () async {
                                  final copy = g.copy()
                                    ..sourceId = ''
                                    ..id = Game.empty().id
                                    ..title = '${g.title} (cópia)'
                                    ..created = DateTime.now();
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GameEditor(
                                        store: widget.store,
                                        game: copy,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.copy_outlined),
                          tooltip: 'Duplicar',
                        ),
                        IconButton.outlined(
                          onPressed: busy
                              ? null
                              : () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Excluir jogo?'),
                                      content: Text(
                                        '“${g.title}” será removido da coleção.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Excluir'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    try {
                                      await widget.store.delete(g);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    } catch (e) {
                                      error(e);
                                    }
                                  }
                                },
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Excluir',
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  try {
                                    await widget.store.move(g, -1);
                                  } catch (e) {
                                    error(e);
                                  }
                                },
                          icon: const Icon(Icons.arrow_back, size: 16),
                          tooltip: 'Mover antes',
                        ),
                        IconButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  try {
                                    await widget.store.move(g, 1);
                                  } catch (e) {
                                    error(e);
                                  }
                                },
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          tooltip: 'Mover depois',
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
