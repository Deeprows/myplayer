import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    MediaKit.ensureInitialized();
  } catch (e, st) {
    // Show the failure on screen instead of hanging on the splash screen.
    runApp(_StartupError(error: '$e\n\n$st'));
    return;
  }
  runApp(const DeeprowsPlayerApp());
}

class _StartupError extends StatelessWidget {
  final String error;
  const _StartupError({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "The media engine didn't start",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(error, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
