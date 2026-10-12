import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/config/secondary_sales_multi_page_upload.dart';
import 'package:zforce/features/pod/models/batch_model.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/models/secondary_sales_multi_page_upload_models.dart';
import 'package:zforce/features/pod/services/secondary_sales_multi_page_upload_service.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';

void main() {
  group('SecondarySalesMultiPageUploadService validation', () {
    late SecondarySalesMultiPageUploadService service;
    late Directory tempDir;
    late List<File> imageFiles;

    setUp(() async {
      service = SecondarySalesMultiPageUploadService();
      tempDir = await Directory.systemTemp.createTemp('ss_multi_page_');
      imageFiles = [];
      for (var i = 1; i <= 3; i++) {
        final f = File('${tempDir.path}/page_$i.jpg');
        await f.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
        imageFiles.add(f);
      }
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('rejects one page', () {
      expect(
        service.validateBeforeUpload(
          stockistId: 45,
          month: '2026-09',
          files: [imageFiles.first],
        ),
        kSecondarySalesMultiPageEmptyPagesMessage,
      );
    });

    test('accepts 2 pages', () {
      expect(
        service.validateBeforeUpload(
          stockistId: 45,
          month: '2026-09',
          files: imageFiles.take(2).toList(),
        ),
        isNull,
      );
    });

    test('accepts multiple pages', () {
      expect(
        service.validateBeforeUpload(
          stockistId: 45,
          month: '2026-09',
          files: imageFiles,
        ),
        isNull,
      );
    });

    test('accepts maximum 10 pages', () async {
      final files = <File>[];
      for (var i = 1; i <= 10; i++) {
        final f = File('${tempDir.path}/max_$i.jpg');
        await f.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
        files.add(f);
      }
      expect(
        service.validateBeforeUpload(
          stockistId: 45,
          month: '2026-09',
          files: files,
        ),
        isNull,
      );
    });

    test('rejects more than 10 pages', () async {
      final files = <File>[];
      for (var i = 1; i <= 11; i++) {
        final f = File('${tempDir.path}/over_$i.jpg');
        await f.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
        files.add(f);
      }
      expect(
        service.validateBeforeUpload(
          stockistId: 45,
          month: '2026-09',
          files: files,
        ),
        kSecondarySalesMultiPageMaxPagesMessage,
      );
    });

    test('rejects missing stockist', () {
      expect(
        service.validateBeforeUpload(
          stockistId: null,
          month: '2026-09',
          files: imageFiles,
        ),
        kSecondarySalesMultiPageMissingStockistMessage,
      );
    });

    test('rejects missing month', () {
      expect(
        service.validateBeforeUpload(
          stockistId: 45,
          month: null,
          files: imageFiles,
        ),
        kSecondarySalesMultiPageMissingMonthMessage,
      );
    });

    test('rejects empty page list', () {
      expect(
        service.validateBeforeUpload(
          stockistId: 45,
          month: '2026-09',
          files: const [],
        ),
        kSecondarySalesMultiPageEmptyPagesMessage,
      );
    });

    test('generates client_upload_id UUID', () {
      final a = service.newClientUploadId();
      final b = service.newClientUploadId();
      expect(a, isNotEmpty);
      expect(b, isNotEmpty);
      expect(a, isNot(b));
      expect(
        RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(a),
        isTrue,
      );
    });

    test('multipart fields include is_multi_page=true', () {
      final fields = SecondarySalesMultiPageUploadService.buildMultipartFields(
        stockistId: 45,
        month: '2026-09',
        clientUploadId: 'abc-uuid',
        notes: 'field note',
      );
      expect(fields['stockist_id'], '45');
      expect(fields['month'], '2026-09');
      expect(fields['is_multi_page'], 'true');
      expect(fields['client_upload_id'], 'abc-uuid');
      expect(fields['notes'], 'field note');
      expect(fields.containsKey('statement_month'), isFalse);
    });

    test('page filenames preserve capture order', () {
      final names =
          SecondarySalesMultiPageUploadService.orderedPageFilenames(imageFiles);
      expect(names, ['page_1.jpg', 'page_2.jpg', 'page_3.jpg']);
    });
  });

  group('Laravel 422 parsing for multi-page upload', () {
    test('surfaces files validation error instead of Validation failed', () {
      final message = secondarySalesFormatLaravelValidationMessage({
        'message': 'Validation failed',
        'errors': {
          'files': ['The files field is required.'],
        },
      });
      expect(
        message,
        'Upload validation failed: The files field is required.',
      );
    });
  });

  group('Multi-page upload-multiple request', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'authToken': 'test-token'});
      tempDir = await Directory.systemTemp.createTemp('ss_multi_upload_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('uploads individual images via files[] in page order', () async {
      final client = _CapturingHttpClient(
        statusCode: 202,
        body: jsonEncode({
          'success': true,
          'batch_id': 123,
          'status': 'queued',
          'total_pages': 3,
          'message':
              '3 pages uploaded successfully. They will be processed as one stock statement.',
        }),
      );

      final files = <File>[];
      for (var i = 1; i <= 3; i++) {
        final f = File('${tempDir.path}/cam_$i.jpg');
        await f.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9, i]);
        files.add(f);
      }

      final service = SecondarySalesMultiPageUploadService(httpClient: client);
      final response = await service.uploadMultipleStockStatement(
        stockistId: 45,
        month: '2026-09',
        files: files,
        clientUploadId: 'uuid-multi-1',
      );

      expect(response.batchId, 123);
      expect(response.totalPages, 3);
      expect(response.status, 'queued');
      expect(client.captured, isA<http.MultipartRequest>());
      final multipart = client.captured as http.MultipartRequest;
      expect(multipart.method, 'POST');
      expect(multipart.url.toString(), API_SECONDARY_SALES_UPLOAD_MULTIPLE_URL);
      expect(multipart.fields['stockist_id'], '45');
      expect(multipart.fields['month'], '2026-09');
      expect(multipart.fields['is_multi_page'], 'true');
      expect(multipart.fields['client_upload_id'], 'uuid-multi-1');
      expect(multipart.files, hasLength(3));
      expect(multipart.files.map((f) => f.field).toList(), [
        'files[]',
        'files[]',
        'files[]',
      ]);
      expect(multipart.files.map((f) => f.filename).toList(), [
        'page_1.jpg',
        'page_2.jpg',
        'page_3.jpg',
      ]);
      expect(
        multipart.files.every((f) => f.contentType?.mimeType == 'image/jpeg'),
        isTrue,
      );
    });

    test('retry can reuse same client_upload_id', () async {
      final ids = <String>[];
      final client = _CapturingHttpClient(
        statusCode: 202,
        body: jsonEncode({
          'success': true,
          'batch_id': 55,
          'status': 'queued',
          'total_pages': 2,
        }),
        onRequest: (req) {
          if (req is http.MultipartRequest) {
            ids.add(req.fields['client_upload_id'] ?? '');
          }
        },
      );

      final files = <File>[];
      for (var i = 1; i <= 2; i++) {
        final f = File('${tempDir.path}/r_$i.jpg');
        await f.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9, i]);
        files.add(f);
      }

      const reuseId = 'same-uuid-for-retry';
      final service = SecondarySalesMultiPageUploadService(httpClient: client);
      await service.uploadMultipleStockStatement(
        stockistId: 45,
        month: '2026-09',
        files: files,
        clientUploadId: reuseId,
      );
      await service.uploadMultipleStockStatement(
        stockistId: 45,
        month: '2026-09',
        files: files,
        clientUploadId: reuseId,
      );
      expect(ids, [reuseId, reuseId]);
    });

    test('maps Laravel 422 body to useful exception message', () async {
      final client = _CapturingHttpClient(
        statusCode: 422,
        body: jsonEncode({
          'message': 'Validation failed',
          'errors': {
            'files': ['At least 2 pages are required.'],
          },
        }),
      );

      final files = <File>[];
      for (var i = 1; i <= 2; i++) {
        final f = File('${tempDir.path}/v_$i.jpg');
        await f.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
        files.add(f);
      }

      final service = SecondarySalesMultiPageUploadService(httpClient: client);
      await expectLater(
        () => service.uploadMultipleStockStatement(
          stockistId: 45,
          month: '2026-09',
          files: files,
          clientUploadId: 'uuid-422',
        ),
        throwsA(
          isA<SecondarySalesMultiPageUploadException>().having(
            (e) => e.message,
            'message',
            'Upload validation failed: At least 2 pages are required.',
          ),
        ),
      );
    });
  });

  group('Multi-page response parsing', () {
    test('parses successful upload-multiple response', () {
      final parsed = SecondarySalesMultiPageUploadResponse.fromJson({
        'success': true,
        'message':
            '3 pages uploaded successfully. They will be processed as one stock statement.',
        'instruction':
            'Please take photos of all pages of the same stock statement for the same stockist and month.',
        'batch_id': 123,
        'stockist_id': 45,
        'month': '2026-09',
        'total_pages': 3,
        'status': 'queued',
        'pages': [
          {'page_number': 1, 'filename': 'page1.jpg', 'status': 'processing'},
          {'page_number': 2, 'filename': 'page2.jpg', 'status': 'processing'},
          {'page_number': 3, 'filename': 'page3.jpg', 'status': 'processing'},
        ],
      });

      expect(parsed.success, isTrue);
      expect(parsed.batchId, 123);
      expect(parsed.stockistId, 45);
      expect(parsed.month, '2026-09');
      expect(parsed.totalPages, 3);
      expect(parsed.status, 'queued');
      expect(parsed.pages, hasLength(3));
      expect(parsed.pages.map((p) => p.pageNumber).toList(), [1, 2, 3]);
      expect(parsed.pages.first.filename, 'page1.jpg');
    });
  });

  group('Batch multi-page status parsing', () {
    test('parses total/processed/failed pages and is_multi_page', () {
      final batch = Batch.fromJson({
        'id': 123,
        'status': 'processing',
        'total_files': 3,
        'successful_files': 2,
        'failed_files': 0,
        'cancelled_files': 0,
        'stockist_id': 45,
        'month': '2026-09',
        'is_multi_page': true,
        'total_pages': 3,
        'processed_pages': 2,
        'failed_pages': 0,
        'pages': [
          {'page_number': 1, 'status': 'completed'},
          {'page_number': 2, 'status': 'completed'},
          {'page_number': 3, 'status': 'processing'},
        ],
        'created_at': '',
        'updated_at': '',
      });

      expect(batch.isMultiPage, isTrue);
      expect(batch.totalPages, 3);
      expect(batch.processedPages, 2);
      expect(batch.failedPages, 0);
      expect(batch.pages, hasLength(3));
      expect(batch.stockistId, 45);
      expect(batch.multiPageProgressLabel, contains('2/3'));
    });
  });

  group('Stockist statement multi-page card', () {
    test('renders one statement for multi-page batch', () {
      final statement = SecondarySalesStockistStatement.fromJson({
        'id': 10,
        'batch_id': 123,
        'status': 'processing',
        'stockist_name': 'ABC DISTRIBUTORS',
        'statement_month': '2026-09',
        'is_multi_page': true,
        'total_pages': 3,
        'processed_pages': 2,
        'failed_pages': 0,
      });

      expect(statement.isMultiPage, isTrue);
      expect(statement.totalPages, 3);
      expect(statement.multiPageSummary, 'Processing: 2/3');
      expect(statement.fileName, 'Stock Statement');
    });
  });

  group('Single-file upload contract regression', () {
    test('single-file endpoint constant remains unchanged', () {
      expect(
        API_SECONDARY_SALES_UPLOAD_URL,
        endsWith('secondary-sales/upload'),
      );
      expect(
        API_SECONDARY_SALES_UPLOAD_MULTIPLE_URL,
        endsWith('secondary-sales/upload-multiple'),
      );
      expect(
        API_SECONDARY_SALES_UPLOAD_URL,
        isNot(API_SECONDARY_SALES_UPLOAD_MULTIPLE_URL),
      );
    });

    test('single-file fields helper still uses statement_month', () {
      final fields = buildSecondarySalesUploadFields(
        stockistId: 45,
        selectedMonth: DateTime(2026, 9),
      );
      expect(fields['stockist_id'], '45');
      expect(fields['statement_month'], '2026-09');
      expect(fields.containsKey('is_multi_page'), isFalse);
    });
  });
}

/// Captures the raw [http.BaseRequest] (including multipart fields/files).
class _CapturingHttpClient extends http.BaseClient {
  _CapturingHttpClient({
    required this.statusCode,
    required this.body,
    this.onRequest,
  });

  final int statusCode;
  final String body;
  final void Function(http.BaseRequest request)? onRequest;
  http.BaseRequest? captured;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    captured = request;
    onRequest?.call(request);
    await request.finalize().drain<void>();
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([utf8.encode(body)]),
      statusCode,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}
