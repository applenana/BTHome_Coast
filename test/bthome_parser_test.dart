import 'package:bthome_coast/bthome/bthome_models.dart';
import 'package:bthome_coast/bthome/bthome_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = BthomeParser();

  group('BthomeParser', () {
    test('parses the official temperature and humidity example', () {
      final packet = parser.parse([0x40, 0x02, 0xc4, 0x09, 0x03, 0xbf, 0x13]);

      expect(packet.deviceInfo.version, 2);
      expect(packet.deviceInfo.encrypted, isFalse);
      expect(packet.measurements, hasLength(2));
      expect(packet.measurements[0].key, 'temperature');
      expect(packet.measurements[0].value, 25.0);
      expect(packet.measurements[0].displayValue, '25.00');
      expect(packet.measurements[1].value, closeTo(50.55, 0.000001));
      expect(packet.issue, isNull);
    });

    test('accepts service data with a prefixed 0xFCD2 UUID', () {
      final packet = parser.parse([0xd2, 0xfc, 0x40, 0x01, 0x61]);
      expect(packet.measurements.single.key, 'battery');
      expect(packet.measurements.single.value, 97);
    });

    test('parses alarm flags and signed temperatures', () {
      final packet = parser.parse([
        0x40,
        0x00,
        0x07,
        0x02,
        0x9c,
        0xff,
        0x18,
        0x01,
        0x1d,
        0x00,
      ]);

      expect(packet.firstByKey('packet_id')?.value, 7);
      expect(packet.firstByKey('temperature')?.value, -1.0);
      expect(packet.firstByKey('cold')?.value, isTrue);
      expect(packet.firstByKey('heat')?.value, isFalse);
      expect(packet.hasActiveAlarm, isTrue);
    });

    test('treats an unsafe safety object as the active alarm state', () {
      final unsafe = parser.parse([0x40, 0x28, 0x00]);
      final safe = parser.parse([0x40, 0x28, 0x01]);

      expect(unsafe.firstByKey('safety')?.displayValue, '不安全');
      expect(unsafe.hasActiveAlarm, isTrue);
      expect(safe.firstByKey('safety')?.displayValue, '安全');
      expect(safe.hasActiveAlarm, isFalse);
    });

    test('parses repeated values, text, raw data and events', () {
      final packet = parser.parse([
        0x40,
        0x02,
        0xc4,
        0x09,
        0x02,
        0x28,
        0x0a,
        0x53,
        0x03,
        0x53,
        0x65,
        0x61,
        0x54,
        0x02,
        0xde,
        0xad,
        0x3a,
        0x04,
        0x3c,
        0x02,
        0x0a,
      ]);

      expect(packet.measurements[1].key, 'temperature_2');
      expect(packet.firstByKey('text')?.value, 'Sea');
      expect(packet.firstByKey('raw')?.value, 'DE AD');
      expect(packet.firstByKey('button_event')?.displayValue, '长按');
      expect(packet.firstByKey('dimmer_event')?.displayValue, '向右旋转 10 步');
    });

    test('marks encrypted frames without decoding ciphertext', () {
      final packet = parser.parse([0x41, 0xde, 0xad, 0xbe, 0xef]);
      expect(packet.deviceInfo.encrypted, isTrue);
      expect(packet.measurements, isEmpty);
      expect(packet.remaining, [0xde, 0xad, 0xbe, 0xef]);
      expect(packet.issue, contains('加密'));
    });

    test('stops safely on unknown or truncated objects', () {
      final unknown = parser.parse([0x40, 0x66, 0x01, 0x02]);
      expect(unknown.measurements, isEmpty);
      expect(unknown.remaining, [0x66, 0x01, 0x02]);
      expect(unknown.issue, contains('未知对象'));

      final truncated = parser.parse([0x40, 0x02, 0x01]);
      expect(truncated.measurements, isEmpty);
      expect(truncated.issue, contains('数据不完整'));
    });

    test('decodes firmware versions in display order', () {
      final packet = parser.parse([
        0x40,
        0xf1,
        0x00,
        0x01,
        0x02,
        0x04,
        0xf2,
        0x00,
        0x01,
        0x06,
      ]);
      expect(packet.measurements[0].displayValue, '4.2.1.0');
      expect(packet.measurements[1].key, 'firmware_version_2');
      expect(packet.measurements[1].displayValue, '6.1.0');
      expect(packet.measurements[0].kind, BthomeValueKind.version);
    });
  });
}
