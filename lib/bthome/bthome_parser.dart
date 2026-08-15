import 'dart:convert';
import 'dart:typed_data';

import 'bthome_models.dart';

class BthomeParser {
  const BthomeParser();

  static const int serviceUuid = 0xfcd2;

  BthomePacket parse(List<int> serviceData) {
    final original = Uint8List.fromList(serviceData);
    var data = original;

    if (data.length >= 2 &&
        ((data[0] == 0xd2 && data[1] == 0xfc) ||
            (data[0] == 0xfc && data[1] == 0xd2))) {
      data = Uint8List.sublistView(data, 2);
    }

    if (data.isEmpty) {
      return BthomePacket(
        deviceInfo: const BthomeDeviceInfo(
          raw: 0,
          version: 0,
          encrypted: false,
          triggerBased: false,
        ),
        measurements: const [],
        raw: original,
        issue: 'Service Data 中缺少 Device Information 字节',
      );
    }

    final infoByte = data[0];
    final info = BthomeDeviceInfo(
      raw: infoByte,
      version: (infoByte >> 5) & 0x07,
      encrypted: (infoByte & 0x01) != 0,
      triggerBased: (infoByte & 0x04) != 0,
    );

    if (info.encrypted) {
      return BthomePacket(
        deviceInfo: info,
        measurements: const [],
        raw: original,
        remaining: data.sublist(1),
        issue: '这是加密 BTHome 广播；当前调试器显示密文但不会在未配置密钥时猜测数据',
      );
    }

    final measurements = <BthomeMeasurement>[];
    final occurrences = <String, int>{};
    var offset = 1;
    String? issue;

    while (offset < data.length) {
      final objectOffset = offset;
      final objectId = data[offset++];
      try {
        final parsed = _parseObject(objectId, data, offset);
        offset = parsed.nextOffset;
        final count = (occurrences[parsed.measurement.key] ?? 0) + 1;
        occurrences[parsed.measurement.key] = count;
        final key = count == 1
            ? parsed.measurement.key
            : '${parsed.measurement.key}_$count';
        measurements.add(
          BthomeMeasurement(
            objectId: parsed.measurement.objectId,
            key: key,
            label: count == 1
                ? parsed.measurement.label
                : '${parsed.measurement.label} $count',
            value: parsed.measurement.value,
            displayValue: parsed.measurement.displayValue,
            kind: parsed.measurement.kind,
            raw: Uint8List.fromList(data.sublist(objectOffset, offset)),
            unit: parsed.measurement.unit,
            isAlarm: parsed.measurement.isAlarm,
            alarmWhenValue: parsed.measurement.alarmWhenValue,
          ),
        );
      } on _ParseFailure catch (error) {
        offset = objectOffset;
        issue = error.message;
        break;
      }
    }

    if (info.version != 2) {
      issue = issue == null
          ? 'Device Information 声明的 BTHome 版本为 ${info.version}，解析结果仅供参考'
          : '$issue；同时版本字段为 ${info.version}';
    }

    return BthomePacket(
      deviceInfo: info,
      measurements: List.unmodifiable(measurements),
      raw: original,
      issue: issue,
      remaining: offset < data.length ? data.sublist(offset) : const [],
    );
  }

  _ParsedObject _parseObject(int id, Uint8List data, int offset) {
    if (id == 0x53 || id == 0x54) {
      _require(data, offset, 1, id);
      final length = data[offset++];
      _require(data, offset, length, id);
      final bytes = data.sublist(offset, offset + length);
      final isText = id == 0x53;
      final value = isText
          ? utf8.decode(bytes, allowMalformed: true)
          : bytesToHex(bytes);
      return _ParsedObject(
        _measurement(
          id,
          isText ? 'text' : 'raw',
          isText ? '文本' : '原始数据',
          value,
          value,
          isText ? BthomeValueKind.text : BthomeValueKind.raw,
        ),
        offset + length,
      );
    }

    if (id == 0x3a) return _parseButton(data, offset);
    if (id == 0x3b) return _parseCommand(data, offset);
    if (id == 0x3c) return _parseDimmer(data, offset);
    if (id == 0xf1 || id == 0xf2) return _parseVersion(id, data, offset);

    final definition = _definitions[id];
    if (definition == null) {
      throw _ParseFailure(
        '遇到未知对象 0x${id.toRadixString(16).padLeft(2, '0').toUpperCase()}，已按协议停止后续解析',
      );
    }
    _require(data, offset, definition.length, id);
    final rawValue = _readInteger(
      data,
      offset,
      definition.length,
      signed: definition.signed,
    );
    final nextOffset = offset + definition.length;

    if (definition.kind == BthomeValueKind.binary) {
      final active = rawValue != 0;
      return _ParsedObject(
        _measurement(
          id,
          definition.key,
          definition.label,
          active,
          active ? definition.onText : definition.offText,
          definition.kind,
          isAlarm: definition.isAlarm,
          alarmWhenValue: definition.alarmWhenValue,
        ),
        nextOffset,
      );
    }

    if (id == 0x50) {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        rawValue * 1000,
        isUtc: true,
      );
      return _ParsedObject(
        _measurement(
          id,
          definition.key,
          definition.label,
          timestamp,
          timestamp.toIso8601String(),
          BthomeValueKind.timestamp,
        ),
        nextOffset,
      );
    }

    if (id == 0x64) {
      const labels = ['黑暗', '暮光', '明亮'];
      final display = rawValue >= 0 && rawValue < labels.length
          ? labels[rawValue]
          : '未知 ($rawValue)';
      return _ParsedObject(
        _measurement(
          id,
          definition.key,
          definition.label,
          rawValue,
          display,
          definition.kind,
        ),
        nextOffset,
      );
    }

    final scaled = rawValue * definition.factor;
    final value = definition.factor == 1 ? rawValue : scaled;
    final display = definition.factor == 1
        ? rawValue.toString()
        : scaled.toStringAsFixed(definition.decimals);
    return _ParsedObject(
      _measurement(
        id,
        definition.key,
        definition.label,
        value,
        display,
        definition.kind,
        unit: definition.unit,
      ),
      nextOffset,
    );
  }

  _ParsedObject _parseButton(Uint8List data, int offset) {
    _require(data, offset, 1, 0x3a);
    final eventId = data[offset];
    const names = <int, String>{
      0x00: '无事件',
      0x01: '单击',
      0x02: '双击',
      0x03: '三击',
      0x04: '长按',
      0x05: '长按后双击',
      0x06: '长按后三击',
      0x80: '持续按住',
    };
    return _ParsedObject(
      _measurement(
        0x3a,
        'button_event',
        '按键事件',
        eventId,
        names[eventId] ?? '未知事件 0x${eventId.toRadixString(16)}',
        BthomeValueKind.event,
      ),
      offset + 1,
    );
  }

  _ParsedObject _parseCommand(Uint8List data, int offset) {
    _require(data, offset, 2, 0x3b);
    final argumentLength = data[offset] & 0x1f;
    final opcode = data[offset + 1];
    _require(data, offset + 2, argumentLength, 0x3b);
    final arguments = data.sublist(offset + 2, offset + 2 + argumentLength);
    const names = <int, String>{
      0: '关闭',
      1: '开启',
      2: '切换',
      3: '步进增加',
      4: '步进减少',
    };
    final suffix = arguments.isEmpty ? '' : ' · 参数 ${bytesToHex(arguments)}';
    return _ParsedObject(
      _measurement(
        0x3b,
        'command',
        '命令事件',
        opcode,
        '${names[opcode] ?? '未知命令 0x${opcode.toRadixString(16)}'}$suffix',
        BthomeValueKind.event,
      ),
      offset + 2 + argumentLength,
    );
  }

  _ParsedObject _parseDimmer(Uint8List data, int offset) {
    _require(data, offset, 2, 0x3c);
    final eventId = data[offset];
    final steps = data[offset + 1];
    final display = switch (eventId) {
      0 => '无事件',
      1 => '向左旋转 $steps 步',
      2 => '向右旋转 $steps 步',
      _ => '未知旋钮事件 0x${eventId.toRadixString(16)} · $steps 步',
    };
    return _ParsedObject(
      _measurement(
        0x3c,
        'dimmer_event',
        '旋钮事件',
        eventId,
        display,
        BthomeValueKind.event,
      ),
      offset + 2,
    );
  }

  _ParsedObject _parseVersion(int id, Uint8List data, int offset) {
    final length = id == 0xf1 ? 4 : 3;
    _require(data, offset, length, id);
    final parts = data.sublist(offset, offset + length).reversed.toList();
    final version = parts.join('.');
    return _ParsedObject(
      _measurement(
        id,
        'firmware_version',
        '固件版本',
        version,
        version,
        BthomeValueKind.version,
      ),
      offset + length,
    );
  }

  BthomeMeasurement _measurement(
    int id,
    String key,
    String label,
    Object? value,
    String display,
    BthomeValueKind kind, {
    String unit = '',
    bool isAlarm = false,
    bool alarmWhenValue = true,
  }) => BthomeMeasurement(
    objectId: id,
    key: key,
    label: label,
    value: value,
    displayValue: display,
    unit: unit,
    kind: kind,
    raw: Uint8List(0),
    isAlarm: isAlarm,
    alarmWhenValue: alarmWhenValue,
  );

  int _readInteger(
    Uint8List data,
    int offset,
    int length, {
    required bool signed,
  }) {
    var value = 0;
    for (var index = 0; index < length; index++) {
      value |= data[offset + index] << (8 * index);
    }
    if (signed) {
      final bits = length * 8;
      final signBit = 1 << (bits - 1);
      if ((value & signBit) != 0) value -= 1 << bits;
    }
    return value;
  }

  void _require(Uint8List data, int offset, int length, int id) {
    if (offset + length > data.length) {
      throw _ParseFailure(
        '对象 0x${id.toRadixString(16).padLeft(2, '0').toUpperCase()} 数据不完整：需要 $length 字节',
      );
    }
  }
}

class _ParsedObject {
  const _ParsedObject(this.measurement, this.nextOffset);
  final BthomeMeasurement measurement;
  final int nextOffset;
}

class _ParseFailure implements Exception {
  const _ParseFailure(this.message);
  final String message;
}

class _Definition {
  const _Definition(
    this.key,
    this.label,
    this.length, {
    this.factor = 1,
    this.unit = '',
    this.signed = false,
    this.kind = BthomeValueKind.number,
    this.decimals = 0,
    this.onText = '开启',
    this.offText = '关闭',
    this.isAlarm = false,
    this.alarmWhenValue = true,
  });

  final String key;
  final String label;
  final int length;
  final double factor;
  final String unit;
  final bool signed;
  final BthomeValueKind kind;
  final int decimals;
  final String onText;
  final String offText;
  final bool isAlarm;
  final bool alarmWhenValue;
}

const _definitions = <int, _Definition>{
  0x00: _Definition('packet_id', '数据包序号', 1),
  0x01: _Definition('battery', '电量', 1, unit: '%'),
  0x02: _Definition(
    'temperature',
    '温度',
    2,
    factor: 0.01,
    unit: '°C',
    signed: true,
    decimals: 2,
  ),
  0x03: _Definition('humidity', '湿度', 2, factor: 0.01, unit: '%', decimals: 2),
  0x04: _Definition(
    'pressure',
    '气压',
    3,
    factor: 0.01,
    unit: 'hPa',
    decimals: 2,
  ),
  0x05: _Definition(
    'illuminance',
    '照度',
    3,
    factor: 0.01,
    unit: 'lx',
    decimals: 2,
  ),
  0x06: _Definition('mass_kg', '质量', 2, factor: 0.01, unit: 'kg', decimals: 2),
  0x07: _Definition('mass_lb', '质量', 2, factor: 0.01, unit: 'lb', decimals: 2),
  0x08: _Definition(
    'dewpoint',
    '露点',
    2,
    factor: 0.01,
    unit: '°C',
    signed: true,
    decimals: 2,
  ),
  0x09: _Definition('count', '计数', 1),
  0x0a: _Definition('energy', '能量', 3, factor: 0.001, unit: 'kWh', decimals: 3),
  0x0b: _Definition('power', '功率', 3, factor: 0.01, unit: 'W', decimals: 2),
  0x0c: _Definition('voltage', '电压', 2, factor: 0.001, unit: 'V', decimals: 3),
  0x0d: _Definition('pm25', 'PM2.5', 2, unit: 'µg/m³'),
  0x0e: _Definition('pm10', 'PM10', 2, unit: 'µg/m³'),
  0x0f: _Definition('generic_boolean', '开关', 1, kind: BthomeValueKind.binary),
  0x10: _Definition('power_state', '电源', 1, kind: BthomeValueKind.binary),
  0x11: _Definition(
    'opening',
    '开启状态',
    1,
    kind: BthomeValueKind.binary,
    onText: '打开',
    offText: '关闭',
  ),
  0x12: _Definition('co2', 'CO₂', 2, unit: 'ppm'),
  0x13: _Definition('tvoc', 'TVOC', 2, unit: 'µg/m³'),
  0x14: _Definition('moisture', '含水率', 2, factor: 0.01, unit: '%', decimals: 2),
  0x15: _Definition(
    'battery_low',
    '低电量',
    1,
    kind: BthomeValueKind.binary,
    onText: '电量低',
    offText: '正常',
    isAlarm: true,
  ),
  0x16: _Definition(
    'battery_charging',
    '充电状态',
    1,
    kind: BthomeValueKind.binary,
    onText: '充电中',
    offText: '未充电',
  ),
  0x17: _Definition(
    'carbon_monoxide',
    '一氧化碳',
    1,
    kind: BthomeValueKind.binary,
    onText: '检测到',
    offText: '正常',
    isAlarm: true,
  ),
  0x18: _Definition(
    'cold',
    '低温警报',
    1,
    kind: BthomeValueKind.binary,
    onText: '低温',
    offText: '正常',
    isAlarm: true,
  ),
  0x19: _Definition(
    'connectivity',
    '连接状态',
    1,
    kind: BthomeValueKind.binary,
    onText: '已连接',
    offText: '断开',
  ),
  0x1a: _Definition(
    'door',
    '门',
    1,
    kind: BthomeValueKind.binary,
    onText: '打开',
    offText: '关闭',
  ),
  0x1b: _Definition(
    'garage_door',
    '车库门',
    1,
    kind: BthomeValueKind.binary,
    onText: '打开',
    offText: '关闭',
  ),
  0x1c: _Definition(
    'gas',
    '燃气',
    1,
    kind: BthomeValueKind.binary,
    onText: '检测到',
    offText: '正常',
    isAlarm: true,
  ),
  0x1d: _Definition(
    'heat',
    '高温警报',
    1,
    kind: BthomeValueKind.binary,
    onText: '高温',
    offText: '正常',
    isAlarm: true,
  ),
  0x1e: _Definition(
    'light',
    '光线',
    1,
    kind: BthomeValueKind.binary,
    onText: '检测到',
    offText: '无',
  ),
  0x1f: _Definition(
    'lock',
    '门锁',
    1,
    kind: BthomeValueKind.binary,
    onText: '未锁',
    offText: '已锁',
  ),
  0x20: _Definition(
    'moisture_detected',
    '潮湿',
    1,
    kind: BthomeValueKind.binary,
    onText: '潮湿',
    offText: '干燥',
    isAlarm: true,
  ),
  0x21: _Definition(
    'motion',
    '移动',
    1,
    kind: BthomeValueKind.binary,
    onText: '检测到',
    offText: '无',
  ),
  0x22: _Definition(
    'moving',
    '运动状态',
    1,
    kind: BthomeValueKind.binary,
    onText: '运动中',
    offText: '静止',
  ),
  0x23: _Definition(
    'occupancy',
    '占用',
    1,
    kind: BthomeValueKind.binary,
    onText: '有人',
    offText: '无人',
  ),
  0x24: _Definition(
    'plug',
    '插头',
    1,
    kind: BthomeValueKind.binary,
    onText: '已接入',
    offText: '未接入',
  ),
  0x25: _Definition(
    'presence',
    '在家状态',
    1,
    kind: BthomeValueKind.binary,
    onText: '在家',
    offText: '离开',
  ),
  0x26: _Definition(
    'problem',
    '故障',
    1,
    kind: BthomeValueKind.binary,
    onText: '异常',
    offText: '正常',
    isAlarm: true,
  ),
  0x27: _Definition(
    'running',
    '运行状态',
    1,
    kind: BthomeValueKind.binary,
    onText: '运行中',
    offText: '停止',
  ),
  0x28: _Definition(
    'safety',
    '安全状态',
    1,
    kind: BthomeValueKind.binary,
    onText: '安全',
    offText: '不安全',
    isAlarm: true,
    alarmWhenValue: false,
  ),
  0x29: _Definition(
    'smoke',
    '烟雾',
    1,
    kind: BthomeValueKind.binary,
    onText: '检测到',
    offText: '正常',
    isAlarm: true,
  ),
  0x2a: _Definition(
    'sound',
    '声音',
    1,
    kind: BthomeValueKind.binary,
    onText: '检测到',
    offText: '无',
  ),
  0x2b: _Definition(
    'tamper',
    '防拆',
    1,
    kind: BthomeValueKind.binary,
    onText: '触发',
    offText: '正常',
    isAlarm: true,
  ),
  0x2c: _Definition(
    'vibration',
    '振动',
    1,
    kind: BthomeValueKind.binary,
    onText: '检测到',
    offText: '无',
  ),
  0x2d: _Definition(
    'window',
    '窗户',
    1,
    kind: BthomeValueKind.binary,
    onText: '打开',
    offText: '关闭',
  ),
  0x2e: _Definition('humidity', '湿度', 1, unit: '%'),
  0x2f: _Definition('moisture', '含水率', 1, unit: '%'),
  0x3d: _Definition('count', '计数', 2),
  0x3e: _Definition('count', '计数', 4),
  0x3f: _Definition(
    'rotation',
    '旋转角度',
    2,
    factor: 0.1,
    unit: '°',
    signed: true,
    decimals: 1,
  ),
  0x40: _Definition('distance_mm', '距离', 2, unit: 'mm'),
  0x41: _Definition('distance_m', '距离', 2, factor: 0.1, unit: 'm', decimals: 1),
  0x42: _Definition(
    'duration',
    '持续时间',
    3,
    factor: 0.001,
    unit: 's',
    decimals: 3,
  ),
  0x43: _Definition('current', '电流', 2, factor: 0.001, unit: 'A', decimals: 3),
  0x44: _Definition('speed', '速度', 2, factor: 0.01, unit: 'm/s', decimals: 2),
  0x45: _Definition(
    'temperature',
    '温度',
    2,
    factor: 0.1,
    unit: '°C',
    signed: true,
    decimals: 1,
  ),
  0x46: _Definition('uv_index', '紫外线指数', 1, factor: 0.1, decimals: 1),
  0x47: _Definition('volume', '体积', 2, factor: 0.1, unit: 'L', decimals: 1),
  0x48: _Definition('volume_ml', '体积', 2, unit: 'mL'),
  0x49: _Definition(
    'volume_flow_rate',
    '体积流量',
    2,
    factor: 0.001,
    unit: 'm³/h',
    decimals: 3,
  ),
  0x4a: _Definition('voltage', '电压', 2, factor: 0.1, unit: 'V', decimals: 1),
  0x4b: _Definition(
    'gas_volume',
    '燃气体积',
    3,
    factor: 0.001,
    unit: 'm³',
    decimals: 3,
  ),
  0x4c: _Definition(
    'gas_volume',
    '燃气体积',
    4,
    factor: 0.001,
    unit: 'm³',
    decimals: 3,
  ),
  0x4d: _Definition('energy', '能量', 4, factor: 0.001, unit: 'kWh', decimals: 3),
  0x4e: _Definition('volume', '体积', 4, factor: 0.001, unit: 'L', decimals: 3),
  0x4f: _Definition('water', '用水量', 4, factor: 0.001, unit: 'L', decimals: 3),
  0x50: _Definition('timestamp', '时间戳', 4, kind: BthomeValueKind.timestamp),
  0x51: _Definition(
    'acceleration',
    '加速度',
    2,
    factor: 0.001,
    unit: 'm/s²',
    decimals: 3,
  ),
  0x52: _Definition(
    'gyroscope',
    '角速度',
    2,
    factor: 0.001,
    unit: '°/s',
    decimals: 3,
  ),
  0x55: _Definition(
    'volume_storage',
    '存储体积',
    4,
    factor: 0.001,
    unit: 'L',
    decimals: 3,
  ),
  0x56: _Definition('conductivity', '电导率', 2, unit: 'µS/cm'),
  0x57: _Definition('temperature', '温度', 1, unit: '°C', signed: true),
  0x58: _Definition(
    'temperature',
    '温度',
    1,
    factor: 0.35,
    unit: '°C',
    signed: true,
    decimals: 2,
  ),
  0x59: _Definition('count', '计数', 1, signed: true),
  0x5a: _Definition('count', '计数', 2, signed: true),
  0x5b: _Definition('count', '计数', 4, signed: true),
  0x5c: _Definition(
    'power',
    '功率',
    4,
    factor: 0.01,
    unit: 'W',
    signed: true,
    decimals: 2,
  ),
  0x5d: _Definition(
    'current',
    '电流',
    2,
    factor: 0.001,
    unit: 'A',
    signed: true,
    decimals: 3,
  ),
  0x5e: _Definition('direction', '方向', 2, factor: 0.01, unit: '°', decimals: 2),
  0x5f: _Definition(
    'precipitation',
    '降水量',
    2,
    factor: 0.1,
    unit: 'mm',
    decimals: 1,
  ),
  0x60: _Definition('channel', '通道', 1),
  0x61: _Definition('rotational_speed', '转速', 2, unit: 'rpm'),
  0x62: _Definition(
    'speed',
    '速度',
    4,
    factor: 0.000001,
    unit: 'm/s',
    signed: true,
    decimals: 6,
  ),
  0x63: _Definition(
    'acceleration',
    '加速度',
    4,
    factor: 0.000001,
    unit: 'm/s²',
    signed: true,
    decimals: 6,
  ),
  0x64: _Definition('light_level', '光照等级', 1),
  0x65: _Definition('settings_revision', '设置修订号', 1),
  0xf0: _Definition('device_type_id', '设备类型 ID', 2),
};
