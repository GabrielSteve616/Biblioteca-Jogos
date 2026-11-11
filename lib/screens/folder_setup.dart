import 'package:flutter/material.dart';
import '../models/game.dart';
import '../services/collection_store.dart';
import '../theme/cyber_theme.dart';

/// One-time optional folder selection. No account, network or credentials.
class FolderSetup extends StatefulWidget {
  const FolderSetup({super.key, required this.store, required this.onDone});
  final CollectionStore store;
  final ValueChanged<bool> onDone;
  @override
  State<FolderSetup> createState() => _FolderSetupState();
}

class _FolderSetupState extends State<FolderSetup> {
  bool organize = false, busy = false;
  String? error;
  Future<void> choose() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final name = await Documents.configureFolder(createFolders: organize);
      if (name == null) return;
      await widget.store.finishSetup(folder: name);
      if (mounted) widget.onDone(true);
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Não foi possível usar essa pasta: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> skip() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.finishSetup();
      if (mounted) widget.onDone(false);
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Não foi possível salvar a configuração: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pastas')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.folder_copy_outlined,
                size: 76,
                color: Cyber.cyan,
              ),
              const SizedBox(height: 24),
              const Text(
                'Capas',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha uma pasta.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Cyber.muted),
              ),
              const SizedBox(height: 28),
              Card(
                child: Tooltip(
                  message:
                      'Cria subpastas por plataforma sem alterar as pastas existentes.',
                  child: SwitchListTile(
                    secondary: const Icon(Icons.create_new_folder_outlined),
                    title: const Text('Pastas por plataforma'),
                    value: organize,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => organize = v),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final p in Game.platforms)
                    Chip(label: Text(p == 'Steam' ? p : p.toLowerCase())),
                ],
              ),
              if (widget.store.folderName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.store.folderName)),
                    ],
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    tooltip: 'Agora não',
                    onPressed: busy ? null : skip,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  const SizedBox(width: 18),
                  IconButton.filled(
                    tooltip: 'Escolher pasta',
                    onPressed: busy ? null : choose,
                    padding: const EdgeInsets.all(20),
                    icon: busy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.folder_open,
                            color: Cyber.background,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
