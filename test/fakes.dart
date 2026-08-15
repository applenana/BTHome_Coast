import 'dart:async';
import 'dart:typed_data';

import 'package:bthome_debugger/scanner/ble_discovery_source.dart';

class FakeBleDiscoverySource implements BleDiscoverySource {
  FakeBleDiscoverySource({
    this.authorized = true,
    this.requiresAuthorization = true,
    BleAdapterStatus status = BleAdapterStatus.poweredOn,
  }) : _status = status;

  final bool authorized;
  @override
  final bool requiresAuthorization;
  final _statuses = StreamController<BleAdapterStatus>.broadcast();
  final _discoveries = StreamController<BleDiscoveredAdvertisement>.broadcast();
  BleAdapterStatus _status;
  bool started = false;
  bool disposed = false;
  int authorizationCalls = 0;

  @override
  BleAdapterStatus get currentStatus => _status;

  @override
  Stream<BleAdapterStatus> get statuses => _statuses.stream;

  @override
  Stream<BleDiscoveredAdvertisement> get discoveries => _discoveries.stream;

  @override
  Future<bool> authorize() async {
    authorizationCalls++;
    return authorized;
  }

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => started = false;

  void setStatus(BleAdapterStatus status) {
    _status = status;
    _statuses.add(status);
  }

  void emit({
    String id = 'AA:BB:CC:DD:EE:FF',
    String name = 'CH572 Alarm',
    int rssi = -52,
    required List<int> data,
  }) {
    _discoveries.add(
      BleDiscoveredAdvertisement(
        deviceId: id,
        name: name,
        rssi: rssi,
        serviceData: Uint8List.fromList(data),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await _statuses.close();
    await _discoveries.close();
  }
}
