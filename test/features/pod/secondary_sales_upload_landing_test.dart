import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/upload_record.dart';
import 'package:zforce/features/pod/screens/modern_document_upload_screen.dart';
import 'package:zforce/features/pod/services/secondary_sales_background_monitor.dart';
import 'package:zforce/features/pod/services/upload_record_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SecondarySalesBackgroundMonitor.instance.stop();
  });

  testWidgets(
      'upload landing shows only active Background Processing cards',
      (tester) async {
    await UploadRecordStore.instance.upsert(
      UploadRecord(
        batchId: '456',
        uploadType: kUploadTypeSecondarySales,
        fileNames: const ['active.jpg'],
        documentIds: const [1],
        status: 'processing',
        createdAt: DateTime(2026, 9, 18),
        totalFiles: 1,
      ),
    );
    await UploadRecordStore.instance.upsert(
      UploadRecord(
        batchId: '455',
        uploadType: kUploadTypeSecondarySales,
        fileNames: const ['done.jpg'],
        documentIds: const [2],
        status: 'completed',
        createdAt: DateTime(2026, 9, 17),
        totalFiles: 1,
      ),
    );
    await UploadRecordStore.instance.upsert(
      UploadRecord(
        batchId: '454',
        uploadType: kUploadTypeSecondarySales,
        fileNames: const ['bad.jpeg'],
        documentIds: const [3],
        status: 'failed',
        createdAt: DateTime(2026, 9, 16),
        totalFiles: 1,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: ModernDocumentUploadScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Background Processing'), findsOneWidget);
    expect(find.text('Batch #456'), findsOneWidget);
    expect(find.textContaining('COMPLETED'), findsNothing);
    expect(find.textContaining('FAILED'), findsNothing);
    expect(find.text('Secondary Sales • COMPLETED'), findsNothing);
    expect(find.text('View Uploaded Batches'), findsOneWidget);
    SecondarySalesBackgroundMonitor.instance.stop();
  });

  testWidgets('hides Background Processing when no active batches',
      (tester) async {
    await UploadRecordStore.instance.upsert(
      UploadRecord(
        batchId: '455',
        uploadType: kUploadTypeSecondarySales,
        fileNames: const ['done.jpg'],
        documentIds: const [2],
        status: 'completed',
        createdAt: DateTime(2026, 9, 17),
        totalFiles: 1,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: ModernDocumentUploadScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Background Processing'), findsNothing);
    expect(find.text('Batch #455'), findsNothing);
    expect(find.text('View Uploaded Batches'), findsOneWidget);
    SecondarySalesBackgroundMonitor.instance.stop();
  });
}
