import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/upload_record.dart';
import 'package:zforce/features/pod/services/secondary_sales_upload_history_sync.dart';
import 'package:zforce/features/pod/services/upload_record_store.dart';

UploadRecord _ss({
  required String batchId,
  String status = 'processing',
  List<String> files = const ['file.jpg'],
  DateTime? createdAt,
}) {
  return UploadRecord(
    batchId: batchId,
    batchDbId: int.tryParse(batchId),
    uploadType: kUploadTypeSecondarySales,
    fileNames: files,
    documentIds: const [101],
    status: status,
    createdAt: createdAt ?? DateTime(2026, 9, 18),
    totalFiles: files.length,
  );
}

UploadRecord _pod({required String batchId, String status = 'completed'}) {
  return UploadRecord(
    batchId: batchId,
    uploadType: kUploadTypeInvoicePod,
    fileNames: const ['invoice.pdf'],
    documentIds: const [9],
    status: status,
    createdAt: DateTime(2026, 8, 1),
    totalFiles: 1,
  );
}

SecondarySalesServerSnapshot _server({
  required String batchId,
  String status = 'processing',
  List<String> files = const ['file.jpg'],
}) {
  return SecondarySalesServerSnapshot(
    batchId: batchId,
    batchDbId: int.tryParse(batchId),
    status: status,
    fileNames: files,
    documentIds: const [101],
    createdAt: DateTime(2026, 9, 18),
    totalFiles: files.length,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reconcileSecondarySalesHistory', () {
    test('1. local + server exist → remains and status is synchronized', () {
      final result = reconcileSecondarySalesHistory(
        local: [_ss(batchId: '11', status: 'processing')],
        server: [_server(batchId: '11', status: 'processing')],
      );
      expect(result.records, hasLength(1));
      expect(result.records.first.batchId, '11');
      expect(result.records.first.status, 'processing');
      expect(result.removedBatchIds, isEmpty);
    });

    test('2. local PROCESSING + server PROCESSING → remains PROCESSING', () {
      final result = reconcileSecondarySalesHistory(
        local: [_ss(batchId: '11', status: 'processing')],
        server: [_server(batchId: '11', status: 'processing')],
      );
      expect(result.records.single.status, 'processing');
    });

    test('3. local PROCESSING + server COMPLETED → changes to COMPLETED', () {
      final result = reconcileSecondarySalesHistory(
        local: [_ss(batchId: '10', status: 'processing')],
        server: [_server(batchId: '10', status: 'completed')],
      );
      expect(result.records.single.status, 'completed');
      expect(result.removedBatchIds, isEmpty);
    });

    test('4. local COMPLETED + server deleted/not found → removed', () {
      final result = reconcileSecondarySalesHistory(
        local: [_ss(batchId: '10', status: 'completed')],
        server: const [],
        existenceByBatchId: const {
          '10': SecondarySalesRecordExistence.notFound,
        },
      );
      expect(result.records, isEmpty);
      expect(result.removedBatchIds, {'10'});
    });

    test('5. local PROCESSING + server batch deleted → removed and polling stops',
        () {
      final result = reconcileSecondarySalesHistory(
        local: [_ss(batchId: '11', status: 'processing')],
        server: const [],
        existenceByBatchId: const {
          '11': SecondarySalesRecordExistence.notFound,
        },
      );
      expect(result.records, isEmpty);
      expect(result.removedBatchIds, {'11'});
      expect(secondarySalesShouldRemoveAfterMissingPolls(2), isFalse);
      expect(secondarySalesShouldRemoveAfterMissingPolls(3), isTrue);
    });

    test('6. local record exists + API temporarily fails → do NOT delete', () {
      final result = reconcileSecondarySalesHistory(
        local: [_ss(batchId: '11', status: 'processing')],
        server: const [],
        existenceByBatchId: const {
          '11': SecondarySalesRecordExistence.unknown,
        },
      );
      expect(result.records, hasLength(1));
      expect(result.records.single.batchId, '11');
      expect(result.removedBatchIds, isEmpty);
    });

    test('7. new server record not present locally → appears once', () {
      final result = reconcileSecondarySalesHistory(
        local: const [],
        server: [_server(batchId: '12', files: const ['new.jpg'])],
      );
      expect(result.records, hasLength(1));
      expect(result.records.single.batchId, '12');
      expect(result.records.single.fileNames, ['new.jpg']);
    });

    test('8. same batch returned by API multiple times → only one UI record', () {
      final result = reconcileSecondarySalesHistory(
        local: [_ss(batchId: '11')],
        server: [
          _server(batchId: '11', files: const ['a.jpg']),
          _server(batchId: '11', files: const ['b.jpg']),
        ],
      );
      expect(result.records.where((r) => r.batchId == '11'), hasLength(1));
    });

    test('9. Invoice POD local records are completely unaffected', () {
      final result = reconcileSecondarySalesHistory(
        local: [
          _ss(batchId: '11', status: 'completed'),
          _pod(batchId: 'pod-1'),
        ],
        server: const [],
        existenceByBatchId: const {
          '11': SecondarySalesRecordExistence.notFound,
        },
      );
      expect(result.records, hasLength(1));
      expect(result.records.single.uploadType, kUploadTypeInvoicePod);
      expect(result.records.single.batchId, 'pod-1');
    });

    test('10. deleted Laravel batch does not reappear from local cache', () {
      final first = reconcileSecondarySalesHistory(
        local: [_ss(batchId: '10', status: 'completed')],
        server: const [],
        existenceByBatchId: const {
          '10': SecondarySalesRecordExistence.notFound,
        },
      );
      final second = reconcileSecondarySalesHistory(
        local: first.records,
        server: const [],
        existenceByBatchId: const {},
      );
      expect(second.records.where((r) => r.batchId == '10'), isEmpty);
    });
  });

  group('UploadRecordStore Secondary Sales replace', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('does not wipe Invoice POD records when replacing Secondary Sales',
        () async {
      final store = UploadRecordStore.instance;
      await store.upsert(_pod(batchId: 'pod-1'));
      await store.upsert(_ss(batchId: '11'));
      await store.replaceSecondarySales(const []);
      final remaining = await store.loadAll();
      expect(remaining.where((r) => r.batchId == '11'), isEmpty);
      expect(remaining.single.batchId, 'pod-1');
      expect(remaining.single.uploadType, kUploadTypeInvoicePod);
    });
  });
}
