import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'services/collection_store.dart';
import 'screens/library_screen.dart';
import 'screens/startup_gate.dart';
import 'theme/cyber_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final root = await getApplicationSupportDirectory();
  final store = CollectionStore(root);
  String? error;
  try {
    await store.load();
  } catch (e) {
    error = e.toString();
  }
  runApp(AcervoApp(store: store, startupError: error, showSetup: true));
}

class AcervoApp extends StatelessWidget {
  const AcervoApp({
    super.key,
    required this.store,
    this.startupError,
    this.showSetup = false,
  });
  final CollectionStore store;
  final String? startupError;
  final bool showSetup;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Biblioteca',
    theme: Cyber.theme,
    builder: (context, child) =>
        CyberBackdrop(child: child ?? const SizedBox.shrink()),
    home: showSetup
        ? StartupGate(store: store, startupError: startupError)
        : LibraryScreen(store: store, startupError: startupError),
  );
}
