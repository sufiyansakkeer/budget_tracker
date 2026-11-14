import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/settings/domain/services/json_off_main.dart';

/// UX-109: backups, exports and restores encoded and decoded JSON on the
/// UI isolate.
void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('json_off'));
  tearDown(() async => dir.delete(recursive: true));

  final payload = <String, Object?>{
    'type': 'monivo_backup',
    'backupFormatVersion': 2,
    'data': {
      'budgets': [
        {'id': 'b1', 'name': 'Muscat', 'currency': 'OMR', 'amount': 120.5},
        {'id': 'b2', 'name': 'घर ₹', 'currency': 'INR', 'amount': 30000},
      ],
      'notes': null,
    },
  };

  test('writes the same bytes the UI isolate wrote', () async {
    final file = File('${dir.path}/backup.json');
    await JsonOffMain.writeIndented(file, payload);

    final before = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    expect(await file.readAsBytes(), before);
  });

  test('reads back what it wrote', () async {
    final file = File('${dir.path}/backup.json');
    await JsonOffMain.writeIndented(file, payload);
    expect(await JsonOffMain.decodeFile(file.path), payload);
  });

  test('a file that is not JSON is still a FormatException', () async {
    final file = File('${dir.path}/broken.json');
    await file.writeAsString('{"type": "monivo_backup", ');
    await expectLater(
      JsonOffMain.decodeFile(file.path),
      throwsA(isA<FormatException>()),
    );
  });

  test('decoding leaves the UI isolate free to run', () async {
    final big = jsonEncode([
      for (var i = 0; i < 20000; i++)
        {'id': 'expense_$i', 'amount': i * 1.5, 'note': 'Coffee $i'},
    ]);
    final order = <String>[];
    // On the UI isolate the whole decode runs before this timer can fire.
    final timer = Future<void>.delayed(Duration.zero, () => order.add('ui'));
    final decoded = JsonOffMain.decode(big).then((_) => order.add('decoded'));
    await Future.wait([timer, decoded]);
    expect(order, ['ui', 'decoded']);
  });
}
