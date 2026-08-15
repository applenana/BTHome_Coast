import 'package:bthome_debugger/main.dart';
import 'package:bthome_debugger/scanner/scanner_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('shows scanner state and a decoded BTHome alarm', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final source = FakeBleDiscoverySource();
    final controller = ScannerController(source: source);
    final ambientAudio = FakeAmbientAudioController();
    await tester.pumpWidget(
      BthomeDebuggerApp(controller: controller, ambientAudio: ambientAudio),
    );

    expect(find.text('BTHome Coast'), findsOneWidget);
    expect(find.text('准备发现 BTHome 设备'), findsOneWidget);

    await tester.tap(find.byKey(const Key('scan-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(source.started, isTrue);
    expect(ambientAudio.scanning, isTrue);
    expect(ambientAudio.isPlaying, isTrue);
    expect(find.text('正在聆听附近广播'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ambient-audio-button')));
    await tester.pump();
    expect(ambientAudio.enabled, isFalse);
    expect(ambientAudio.isPlaying, isFalse);

    source.emit(
      name: 'CH572 Alarm',
      data: [0x40, 0x00, 0x2a, 0x02, 0xc4, 0x09, 0x1d, 0x01],
    );
    await tester.pump();

    expect(find.text('CH572 Alarm'), findsNWidgets(2));
    expect(find.text('高温警报'), findsOneWidget);
    expect(find.text('高温'), findsOneWidget);
    expect(find.textContaining('25.00', findRichText: true), findsOneWidget);
  });

  testWidgets('fits animated controls on a compact Android viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = ScannerController(source: FakeBleDiscoverySource());
    await tester.pumpWidget(
      BthomeDebuggerApp(
        controller: controller,
        ambientAudio: FakeAmbientAudioController(),
      ),
    );
    await tester.tap(find.byKey(const Key('scan-button')));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('正在聆听附近广播'), findsOneWidget);
    expect(find.byKey(const Key('ambient-audio-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
