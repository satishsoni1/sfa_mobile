import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zforce/features/pod/services/secondary_sales_background_monitor.dart';
import 'package:zforce/features/pod/services/secondary_sales_upload_history_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SecondarySalesCompletionTracker.resetForTest();
  });

  test('active status label never claims known OCR percentage', () {
    expect(
      secondarySalesActiveStatusLabel('processing'),
      'Processing in background…',
    );
    expect(
      secondarySalesActiveStatusLabel('extracting'),
      'Processing in background…',
    );
    expect(
      secondarySalesActiveStatusLabel('queued'),
      contains('background'),
    );
    expect(
      secondarySalesActiveStatusLabel('extracting'),
      isNot(contains('100%')),
    );
  });

  test('completion tracker notifies only once per batch', () async {
    expect(await SecondarySalesCompletionTracker.claim('461'), isTrue);
    expect(await SecondarySalesCompletionTracker.claim('461'), isFalse);
    expect(await SecondarySalesCompletionTracker.claim('462'), isTrue);
  });

  test('normalize keeps queued as active processing', () {
    expect(normalizeSecondarySalesUploadStatus('queued'), 'processing');
    expect(isSecondarySalesActiveUploadStatus('queued'), isTrue);
    expect(isSecondarySalesTerminalUploadStatus('completed'), isTrue);
    expect(isSecondarySalesTerminalUploadStatus('failed'), isTrue);
  });
}
