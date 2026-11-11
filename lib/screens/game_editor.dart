import 'dart:io';
import 'package:flutter/material.dart';
import '../models/game.dart';
import '../services/collection_store.dart';

class GameEditor extends StatefulWidget {
  const GameEditor({
    super.key,
    required this.store,
    required this.game,
    this.batchPosition,
  });
  final CollectionStore store;
  final Game game;
  final String? batchPosition;
  @override
  State<GameEditor> createState() => _GameEditorState();
}

class _GameEditorState extends State<GameEditor> {
  final form = GlobalKey<FormState>();
  late Game game = widget.game.title.isEmpty ? widget.game : widget.game.copy();
  final Map<String, TextEditingController> inputs = {};
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final json = game.toJson();
    for (final key in [
      'title',
      'description',
      'genre',
      'year',
      'rating',
      'players',
      'notes',
    ]) {
      inputs[key] = TextEditingController(text: json[key] as String);
    }
  }

  @override
  void dispose() {
    for (final controller in inputs.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível concluir: $e')));
    }
  }

  Future<void> pick(String field) async {
    setState(() => busy = true);
    try {
      final selected = await Documents.images();
      if (selected.isNotEmpty) {
        final name = await widget.store.importImage(selected.first);
        if (!mounted) return;
        setState(() {
          if (field == 'front') game.front = name;
          if (field == 'back') game.back = name;
          if (field == 'disc') game.disc = name;
        });
      }
    } catch (e) {
      error(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    game.title = inputs['title']!.text.trim();
    game.description = inputs['description']!.text.trim();
    game.genre = inputs['genre']!.text.trim();
    game.year = inputs['year']!.text.trim();
    game.rating = inputs['rating']!.text.trim();
    game.players = inputs['players']!.text.trim();
    game.notes = inputs['notes']!.text.trim();
    try {
      await widget.store.put(game);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      error(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget input(String key, String title, {int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: inputs[key],
      maxLines: lines,
      decoration: InputDecoration(labelText: title),
      keyboardType: key == 'year' ? TextInputType.number : TextInputType.text,
      validator: key == 'title'
          ? (v) =>
                v == null || v.trim().isEmpty ? 'Informe o nome do jogo.' : null
          : null,
    ),
  );
  Widget imageField(String key, String title, String name) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 64,
            child: name.isEmpty
                ? const Icon(Icons.add_photo_alternate_outlined)
                : Image.file(
                    File(widget.store.thumb(name)),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.image_not_supported_outlined),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
          IconButton(
            tooltip: 'Escolher imagem',
            onPressed: busy ? null : () => pick(key),
            icon: const Icon(Icons.folder_open),
          ),
          if (name.isNotEmpty)
            IconButton(
              tooltip: 'Remover imagem',
              onPressed: busy
                  ? null
                  : () => setState(() {
                      if (key == 'front') game.front = '';
                      if (key == 'back') game.back = '';
                      if (key == 'disc') game.disc = '';
                    }),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.batchPosition ??
            (widget.game.title.isEmpty ? 'Nova capa' : 'Editar capa'),
      ),
      actions: [
        IconButton(
          tooltip: 'Salvar jogo',
          onPressed: busy ? null : save,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
        ),
      ],
    ),
    body: AbsorbPointer(
      absorbing: busy,
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            input('title', 'Nome do jogo *'),
            DropdownButtonFormField<String>(
              initialValue: game.platform,
              decoration: const InputDecoration(labelText: 'Plataforma'),
              items: Game.platforms
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (p) => setState(() => game.platform = p!),
            ),
            const SizedBox(height: 20),
            imageField('front', 'Capa', game.front),
            imageField('back', 'Verso', game.back),
            imageField('disc', 'Disco', game.disc),
            ExpansionTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Detalhes'),
              children: [
                input('description', 'Descrição', lines: 4),
                input('genre', 'Gênero'),
                input('year', 'Ano de lançamento'),
                input('rating', 'Classificação indicativa'),
                input('players', 'Número de jogadores'),
                input('notes', 'Observações pessoais', lines: 3),
              ],
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}
