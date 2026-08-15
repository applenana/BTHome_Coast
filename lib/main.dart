import 'package:flutter/material.dart';

import 'audio/ambient_audio_controller.dart';
import 'scanner/ble_discovery_source.dart';
import 'scanner/scanner_controller.dart';
import 'ui/app_theme.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    BthomeDebuggerApp(
      controller: ScannerController(source: SystemBleDiscoverySource()),
      ambientAudio: OceanAmbientAudioController(),
    ),
  );
}

class BthomeDebuggerApp extends StatefulWidget {
  const BthomeDebuggerApp({
    super.key,
    required this.controller,
    this.ambientAudio,
  });

  final ScannerController controller;
  final AmbientAudioController? ambientAudio;

  @override
  State<BthomeDebuggerApp> createState() => _BthomeDebuggerAppState();
}

class _BthomeDebuggerAppState extends State<BthomeDebuggerApp> {
  late final AmbientAudioController _ambientAudio =
      widget.ambientAudio ?? SilentAmbientAudioController();

  @override
  void dispose() {
    widget.controller.dispose();
    _ambientAudio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BTHome Coast',
    debugShowCheckedModeBanner: false,
    theme: buildSeaTheme(),
    home: HomeScreen(
      controller: widget.controller,
      ambientAudio: _ambientAudio,
    ),
  );
}
