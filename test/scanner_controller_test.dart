import 'package:bthome_debugger/scanner/scanner_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('starts scanning and merges repeated advertisements', () async {
    final source = FakeBleDiscoverySource();
    final controller = ScannerController(source: source);

    await controller.startScanning();
    expect(source.started, isTrue);
    expect(controller.isScanning, isTrue);

    source.emit(data: [0x40, 0x02, 0xc4, 0x09, 0x1d, 0x01]);
    await Future<void>.delayed(Duration.zero);
    source.emit(data: [0x40, 0x02, 0xca, 0x09, 0x1d, 0x00]);
    await Future<void>.delayed(Duration.zero);

    expect(controller.totalCount, 1);
    expect(controller.devices.single.seenCount, 2);
    expect(
      controller.devices.single.packet.firstByKey('temperature')?.value,
      closeTo(25.06, 0.000001),
    );
    expect(controller.alarmCount, 0);

    controller.dispose();
  });

  test('filters alarm devices and reports authorization failures', () async {
    final source = FakeBleDiscoverySource();
    final controller = ScannerController(source: source);
    source.emit(id: 'normal', data: [0x40, 0x18, 0x00]);
    source.emit(id: 'alarm', data: [0x40, 0x18, 0x01]);
    await Future<void>.delayed(Duration.zero);

    controller.setFilter(DeviceFilter.alarms);
    expect(controller.devices.single.deviceId, 'alarm');
    controller.dispose();

    final denied = ScannerController(
      source: FakeBleDiscoverySource(authorized: false),
    );
    await denied.startScanning();
    expect(denied.isScanning, isFalse);
    expect(denied.error, contains('权限'));
    denied.dispose();
  });

  test('skips unsupported authorization before scanning on Windows', () async {
    final source = FakeBleDiscoverySource(
      authorized: false,
      requiresAuthorization: false,
    );
    final controller = ScannerController(source: source);

    await controller.startScanning();

    expect(source.authorizationCalls, 0);
    expect(source.started, isTrue);
    expect(controller.isScanning, isTrue);
    expect(controller.error, isNull);
    controller.dispose();
  });
}
