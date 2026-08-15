import 'package:flutter/material.dart';

import 'scanner/ble_discovery_source.dart';
import 'scanner/scanner_controller.dart';
import 'ui/app_theme.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    BthomeDebuggerApp(
      controller: ScannerController(source: SystemBleDiscoverySource()),
    ),
  );
}

class BthomeDebuggerApp extends StatefulWidget {
  const BthomeDebuggerApp({super.key, required this.controller});

  final ScannerController controller;

  @override
  State<BthomeDebuggerApp> createState() => _BthomeDebuggerAppState();
}

class _BthomeDebuggerAppState extends State<BthomeDebuggerApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BTHome Coast',
    debugShowCheckedModeBanner: false,
    theme: buildSeaTheme(),
    home: HomeScreen(controller: widget.controller),
  );
}
