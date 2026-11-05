import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/files/file_delivery_service.dart';

/// UX-019: on iPad the share sheet is a popover and share_plus fails
/// without an anchor, so every export and shared backup failed there.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  late Directory temp;
  Map<Object?, Object?>? sent;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('monivo_share_');
    sent = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          sent = call.arguments as Map<Object?, Object?>;
          return 'com.example.chosen';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    temp.deleteSync(recursive: true);
  });

  test('the share sheet is anchored to the control that opened it', () async {
    final file = File('${temp.path}/report.csv')..writeAsStringSync('a,b');

    final outcome = await const FileDeliveryService().deliver(
      file: file,
      fileName: 'report.csv',
      mimeType: 'text/csv',
      extension: 'csv',
      destination: FileDestination.share,
      shareOrigin: const Rect.fromLTWH(10, 20, 300, 56),
    );

    expect(outcome, FileDeliveryOutcome.shared);
    expect(sent, containsPair('originX', 10.0));
    expect(sent, containsPair('originY', 20.0));
    expect(sent, containsPair('originWidth', 300.0));
    expect(sent, containsPair('originHeight', 56.0));
  });
}
