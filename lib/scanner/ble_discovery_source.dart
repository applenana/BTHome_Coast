import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

enum BleAdapterStatus {
  unknown,
  unsupported,
  unauthorized,
  poweredOff,
  poweredOn,
}

class BleDiscoveredAdvertisement {
  const BleDiscoveredAdvertisement({
    required this.deviceId,
    required this.rssi,
    required this.serviceData,
    this.name,
  });

  final String deviceId;
  final String? name;
  final int rssi;
  final Uint8List serviceData;
}

abstract interface class BleDiscoverySource {
  BleAdapterStatus get currentStatus;
  Stream<BleAdapterStatus> get statuses;
  Stream<BleDiscoveredAdvertisement> get discoveries;
  Future<bool> authorize();
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

class SystemBleDiscoverySource implements BleDiscoverySource {
  SystemBleDiscoverySource() : _manager = CentralManager() {
    _stateSubscription = _manager.stateChanged.listen((event) {
      _statusController.add(_mapState(event.state));
    });
    _discoverySubscription = _manager.discovered.listen(_onDiscovered);
  }

  final CentralManager _manager;
  final _statusController = StreamController<BleAdapterStatus>.broadcast();
  final _discoveryController =
      StreamController<BleDiscoveredAdvertisement>.broadcast();
  StreamSubscription<BluetoothLowEnergyStateChangedEventArgs>?
  _stateSubscription;
  StreamSubscription<DiscoveredEventArgs>? _discoverySubscription;

  @override
  BleAdapterStatus get currentStatus => _mapState(_manager.state);

  @override
  Stream<BleAdapterStatus> get statuses => _statusController.stream;

  @override
  Stream<BleDiscoveredAdvertisement> get discoveries =>
      _discoveryController.stream;

  @override
  Future<bool> authorize() => _manager.authorize();

  @override
  Future<void> start() => _manager.startDiscovery();

  @override
  Future<void> stop() => _manager.stopDiscovery();

  void _onDiscovered(DiscoveredEventArgs event) {
    Uint8List? bthomeData;
    for (final entry in event.advertisement.serviceData.entries) {
      if (_isBthomeUuid(entry.key)) {
        bthomeData = Uint8List.fromList(entry.value);
        break;
      }
    }
    if (bthomeData == null) return;

    _discoveryController.add(
      BleDiscoveredAdvertisement(
        deviceId: event.peripheral.uuid.toString(),
        name: event.advertisement.name,
        rssi: event.rssi,
        serviceData: bthomeData,
      ),
    );
  }

  bool _isBthomeUuid(UUID uuid) {
    final compact = uuid.toString().toLowerCase().replaceAll('-', '');
    return compact == 'fcd2' || compact == '0000fcd200001000800000805f9b34fb';
  }

  @override
  Future<void> dispose() async {
    try {
      await stop();
    } catch (_) {
      // The adapter may already be off while the application is closing.
    }
    await _stateSubscription?.cancel();
    await _discoverySubscription?.cancel();
    await _statusController.close();
    await _discoveryController.close();
  }

  static BleAdapterStatus _mapState(BluetoothLowEnergyState state) =>
      switch (state) {
        BluetoothLowEnergyState.unsupported => BleAdapterStatus.unsupported,
        BluetoothLowEnergyState.unauthorized => BleAdapterStatus.unauthorized,
        BluetoothLowEnergyState.poweredOff => BleAdapterStatus.poweredOff,
        BluetoothLowEnergyState.poweredOn => BleAdapterStatus.poweredOn,
        BluetoothLowEnergyState.unknown => BleAdapterStatus.unknown,
      };
}
