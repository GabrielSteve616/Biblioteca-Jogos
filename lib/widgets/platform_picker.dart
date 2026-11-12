import 'package:flutter/material.dart';
import '../models/game.dart';

class PlatformPicker extends StatelessWidget {
  const PlatformPicker({
    super.key,
    required this.values,
    required this.onChanged,
  });
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        values.isEmpty ? Game.unassigned : 'Plataformas',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final p in [
            'Steam',
            'Android',
            'PS1',
            'PS2',
            'PS3',
            'PS4',
            'PS5',
          ])
            FilterChip(
              label: Text(p),
              selected: values.contains(p),
              onSelected: (selected) {
                final next = [...values];
                selected ? next.add(p) : next.remove(p);
                onChanged(next);
              },
            ),
          if (values.isNotEmpty)
            IconButton(
              tooltip: Game.unassigned,
              onPressed: () => onChanged([]),
              icon: const Icon(Icons.clear_all),
            ),
        ],
      ),
    ],
  );
}

Future<List<String>?> choosePlatforms(
  BuildContext context,
  List<String> current, {
  String? hint,
}) => showDialog<List<String>>(
  context: context,
  builder: (context) {
    var values = [...current];
    return StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Plataformas'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(hint),
                ),
              PlatformPicker(
                values: values,
                onChanged: (v) => setState(() => values = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, values),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  },
);
