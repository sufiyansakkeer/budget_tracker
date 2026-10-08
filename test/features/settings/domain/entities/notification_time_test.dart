import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/settings/domain/entities/notification_settings.dart';

void main() {
  group('NotificationTime.fromString', () {
    const evening = NotificationTime(hour: 20, minute: 0);

    test('parses a stored "HH:mm" value', () {
      expect(
        NotificationTime.fromString('21:30', fallback: evening),
        const NotificationTime(hour: 21, minute: 30),
      );
    });

    test('returns the fallback for a missing or malformed value', () {
      expect(NotificationTime.fromString(null, fallback: evening), evening);
      expect(NotificationTime.fromString('', fallback: evening), evening);
      expect(NotificationTime.fromString('8pm', fallback: evening), evening);
      expect(NotificationTime.fromString('ab:cd', fallback: evening), evening);
    });

    test('keeps the old 9:00 default when no fallback is given', () {
      expect(
        NotificationTime.fromString(null),
        const NotificationTime(hour: 9, minute: 0),
      );
    });

    test('clamps out-of-range parts', () {
      expect(
        NotificationTime.fromString('27:75', fallback: evening),
        const NotificationTime(hour: 23, minute: 59),
      );
    });
  });
}
