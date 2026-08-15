import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bthome/bthome_models.dart';
import '../bthome/bthome_parser.dart';
import 'ble_discovery_source.dart';

enum DeviceFilter { all, alarms, encrypted }

class BthomeDeviceSnapshot {
  const BthomeDeviceSnapshot({
    required this.deviceId,
    required this.displayName,
    required this.rssi,
    required this.packet,
    required this.lastSeen,
    required this.seenCount,
  });

  final String deviceId;
  final String displayName;
  final int rssi;
  final BthomePacket packet;
  final DateTime lastSeen;
  final int seenCount;

  Duration ageAt(DateTime now) => now.difference(lastSeen);
}

class ScannerController extends ChangeNotifier {
  ScannerController({
    required BleDiscoverySource source,
    BthomeParser parser = const BthomeParser(),
  }) : _source = source,
       _parser = parser,
       _status = source.currentStatus {
    _statusSubscription = source.statuses.listen(_onStatus);
    _discoverySubscription = source.discoveries.listen(_onDiscovered);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_devices.isNotEmpty) notifyListeners();
    });
  }

  final BleDiscoverySource _source;
  final BthomeParser _parser;
  final Map<String, BthomeDeviceSnapshot> _devices = {};
  StreamSubscription<BleAdapterStatus>? _statusSubscription;
  StreamSubscription<BleDiscoveredAdvertisement>? _discoverySubscription;
  Timer? _clock;

  BleAdapterStatus _status;
  bool _isScanning = false;
  bool _isBusy = false;
  String? _error;
  String _query = '';
  DeviceFilter _filter = DeviceFilter.all;
  String? _selectedDeviceId;

  BleAdapterStatus get status => _status;
  bool get isScanning => _isScanning;
  bool get isBusy => _isBusy;
  String? get error => _error;
  String get query => _query;
  DeviceFilter get filter => _filter;
  String? get selectedDeviceId => _selectedDeviceId;
  int get totalCount => _devices.length;
  int get alarmCount =>
      _devices.values.where((device) => device.packet.hasActiveAlarm).length;
  int get encryptedCount => _devices.values
      .where((device) => device.packet.deviceInfo.encrypted)
      .length;

  List<BthomeDeviceSnapshot> get devices {
    final normalizedQuery = _query.trim().toLowerCase();
    final result =
        _devices.values.where((device) {
          final matchesFilter = switch (_filter) {
            DeviceFilter.all => true,
            DeviceFilter.alarms => device.packet.hasActiveAlarm,
            DeviceFilter.encrypted => device.packet.deviceInfo.encrypted,
          };
          final matchesQuery =
              normalizedQuery.isEmpty ||
              device.displayName.toLowerCase().contains(normalizedQuery) ||
              device.deviceId.toLowerCase().contains(normalizedQuery);
          return matchesFilter && matchesQuery;
        }).toList()..sort((a, b) {
          if (a.packet.hasActiveAlarm != b.packet.hasActiveAlarm) {
            return a.packet.hasActiveAlarm ? -1 : 1;
          }
          return b.lastSeen.compareTo(a.lastSeen);
        });
    return result;
  }

  BthomeDeviceSnapshot? get selectedDevice {
    final id = _selectedDeviceId;
    return id == null ? null : _devices[id];
  }

  Future<void> toggleScanning() =>
      isScanning ? stopScanning() : startScanning();

  Future<void> startScanning() async {
    if (_isBusy || _isScanning) return;
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      final authorized = await _source.authorize();
      _status = _source.currentStatus;
      if (!authorized || _status == BleAdapterStatus.unauthorized) {
        throw StateError('未获得“附近设备/蓝牙”权限，请在系统设置中允许后重试');
      }
      if (_status == BleAdapterStatus.poweredOff) {
        throw StateError('蓝牙当前已关闭，请先打开系统蓝牙');
      }
      if (_status == BleAdapterStatus.unsupported) {
        throw StateError('当前设备不支持 Bluetooth Low Energy');
      }
      await _source.start();
      _isScanning = true;
    } catch (error) {
      _error = _friendlyError(error);
      _isScanning = false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> stopScanning() async {
    if (_isBusy || !_isScanning) return;
    _isBusy = true;
    notifyListeners();
    try {
      await _source.stop();
      _isScanning = false;
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void clearDevices() {
    _devices.clear();
    _selectedDeviceId = null;
    notifyListeners();
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setFilter(DeviceFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  void selectDevice(String deviceId) {
    if (_selectedDeviceId == deviceId) return;
    _selectedDeviceId = deviceId;
    notifyListeners();
  }

  void dismissError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _onStatus(BleAdapterStatus value) {
    _status = value;
    if (value != BleAdapterStatus.poweredOn && _isScanning) {
      _isScanning = false;
    }
    notifyListeners();
  }

  void _onDiscovered(BleDiscoveredAdvertisement event) {
    final previous = _devices[event.deviceId];
    final name = event.name?.trim();
    final packet = _parser.parse(event.serviceData);
    final snapshot = BthomeDeviceSnapshot(
      deviceId: event.deviceId,
      displayName: name == null || name.isEmpty ? '未命名 BTHome 设备' : name,
      rssi: event.rssi,
      packet: packet,
      lastSeen: DateTime.now(),
      seenCount: (previous?.seenCount ?? 0) + 1,
    );
    _devices[event.deviceId] = snapshot;
    _selectedDeviceId ??= event.deviceId;
    notifyListeners();
  }

  String _friendlyError(Object error) {
    if (error is StateError) return error.message.toString();
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? '蓝牙操作失败，请稍后重试' : text;
  }

  @override
  void dispose() {
    _clock?.cancel();
    unawaited(_statusSubscription?.cancel());
    unawaited(_discoverySubscription?.cancel());
    unawaited(_source.dispose());
    super.dispose();
  }
}
