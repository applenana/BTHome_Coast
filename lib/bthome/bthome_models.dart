import 'dart:typed_data';

enum BthomeValueKind { number, binary, event, text, raw, timestamp, version }

abstract final class BthomeServiceUuid {
  static const int v1Unencrypted = 0x181c;
  static const int v1Encrypted = 0x181e;
  static const int v2 = 0xfcd2;

  static bool isSupported(int value) =>
      value == v1Unencrypted || value == v1Encrypted || value == v2;
}

class BthomeDeviceInfo {
  const BthomeDeviceInfo({
    required this.raw,
    required this.version,
    required this.encrypted,
    required this.triggerBased,
  });

  final int raw;
  final int version;
  final bool encrypted;
  final bool triggerBased;
}

class BthomeMeasurement {
  const BthomeMeasurement({
    required this.objectId,
    required this.key,
    required this.label,
    required this.value,
    required this.displayValue,
    required this.kind,
    required this.raw,
    this.unit = '',
    this.isAlarm = false,
    this.alarmWhenValue = true,
  });

  final int objectId;
  final String key;
  final String label;
  final Object? value;
  final String displayValue;
  final String unit;
  final BthomeValueKind kind;
  final Uint8List raw;
  final bool isAlarm;
  final bool alarmWhenValue;

  String get objectIdHex =>
      '0x${objectId.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}

class BthomePacket {
  const BthomePacket({
    required this.serviceUuid,
    required this.deviceInfo,
    required this.measurements,
    required this.raw,
    this.issue,
    this.remaining = const <int>[],
  });

  final int serviceUuid;
  final BthomeDeviceInfo deviceInfo;
  final List<BthomeMeasurement> measurements;
  final Uint8List raw;
  final String? issue;
  final List<int> remaining;

  String get serviceUuidHex =>
      '0x${serviceUuid.toRadixString(16).padLeft(4, '0').toUpperCase()}';

  bool get hasActiveAlarm => measurements.any(
    (measurement) =>
        measurement.isAlarm && measurement.value == measurement.alarmWhenValue,
  );

  BthomeMeasurement? firstByKey(String key) {
    for (final measurement in measurements) {
      if (measurement.key == key) return measurement;
    }
    return null;
  }
}

String bytesToHex(Iterable<int> bytes, {String separator = ' '}) => bytes
    .map((value) => value.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(separator);
