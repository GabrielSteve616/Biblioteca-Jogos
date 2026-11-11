import 'package:flutter/material.dart';
import '../services/collection_store.dart';
import 'folder_setup.dart';
import 'library_screen.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.store, this.startupError});
  final CollectionStore store;
  final String? startupError;
  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool ready = false, scan = false;
  @override
  Widget build(BuildContext context) {
    if (!ready && !widget.store.setupComplete) {
      return FolderSetup(
        store: widget.store,
        onDone: (locate) => setState(() {
          ready = true;
          scan = locate;
        }),
      );
    }
    return LibraryScreen(
      store: widget.store,
      startupError: widget.startupError,
      scanFolderOnStart: scan,
    );
  }
}
