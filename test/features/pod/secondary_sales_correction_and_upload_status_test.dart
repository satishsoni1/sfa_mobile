import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/secondary_sales_stock_correction_models.dart';
import 'package:zforce/features/pod/models/secondary_sales_upload_status_models.dart';
import 'package:zforce/features/pod/services/secondary_sales_stock_correction_service.dart';
import 'package:zforce/features/pod/services/secondary_sales_upload_status_service.dart';

void main() {
  group('SecondarySalesCorrection models', () {
    test('parses GET correction data with permissions and validation', () {
      final response = SecondarySalesCorrectionResponse.fromJson({
        'success': true,
        'data': {
          'statement_id': 1552,
          'enabled': true,
          'permissions': {'can_correct_stock': true},
          'stockist_name': 'RICHA PHARMA',
          'statement_month': '2026-10',
          'lines': [
            {
              'line_index': 0,
              'product_name': 'ABC TABLETS',
              'extracted_opening_qty': 100,
              'effective_opening_qty': 105,
              'opening_corrected': true,
              'extracted_closing_qty': 40,
              'effective_closing_qty': 45,
              'closing_corrected': true,
              'receipt_qty': 20,
              'sales_qty': 75,
              'sample_qty': 0,
              'expiry_qty': 0,
              'stock_validation': {
                'status': 'valid',
                'expected_closing_qty': 45,
                'actual_closing_qty': 45,
                'variance': 0,
              },
            },
          ],
          'correction_history': [
            {
              'product_name': 'ABC TABLETS',
              'field': 'opening',
              'previous_qty': 100,
              'new_qty': 105,
              'corrected_by': 'Manager',
              'reason': 'Physical count',
              'corrected_at': '2026-10-01T10:00:00Z',
            },
          ],
          'stock_validation': {
            'status': 'valid',
            'invalid_lines': 0,
            'valid_lines': 1,
            'message': 'All good',
          },
        },
      });

      expect(response.statementId, 1552);
      expect(response.canCorrectStock, isTrue);
      expect(response.lines, hasLength(1));
      expect(response.lines.first.effectiveOpeningQty, 105);
      expect(response.lines.first.effectiveClosingQty, 45);
      expect(response.lines.first.openingCorrected, isTrue);
      expect(response.lines.first.closingCorrected, isTrue);
      expect(response.stockValidation.displayStatus, 'VALID');
      expect(response.correctionHistory, hasLength(1));
    });

    test('permission false disables editing', () {
      final response = SecondarySalesCorrectionResponse.fromJson({
        'data': {
          'statement_id': 1,
          'enabled': true,
          'permissions': {'can_correct_stock': false},
          'lines': [],
          'correction_history': [],
          'stock_validation': {'status': 'not_validated'},
        },
      });
      expect(response.canCorrectStock, isFalse);
      expect(response.permissions.canCorrectStock, isFalse);
      expect(response.stockValidation.displayStatus, 'NOT VALIDATED');
    });

    test('builds save payload with only changed fields', () {
      const lines = [
        SecondarySalesCorrectionLine(
          lineIndex: 4,
          productName: 'A',
          effectiveOpeningQty: 100,
          effectiveClosingQty: 40,
        ),
        SecondarySalesCorrectionLine(
          lineIndex: 7,
          productName: 'B',
          effectiveOpeningQty: 10,
          effectiveClosingQty: 5,
        ),
      ];
      final drafts = {
        4: SecondarySalesCorrectionDraft(
          lineIndex: 4,
          openingQty: 105,
          closingQty: 45,
        ),
        7: SecondarySalesCorrectionDraft(
          lineIndex: 7,
          openingQty: 50,
          closingQty: 5,
        ),
      };
      final payload = buildSecondarySalesCorrectionPayload(
        reason: 'Verified physical stock against statement',
        originalLines: lines,
        drafts: drafts,
      );
      expect(payload['reason'], contains('Verified'));
      final corrections = payload['corrections'] as List;
      expect(corrections, hasLength(2));
      expect(corrections[0]['line_index'], 4);
      expect(corrections[0]['opening_qty'], 105);
      expect(corrections[0]['closing_qty'], 45);
      expect(corrections[1]['line_index'], 7);
      expect(corrections[1]['opening_qty'], 50);
      expect(corrections[1].containsKey('closing_qty'), isFalse);
    });

    test('negative quantity validation helper', () {
      expect(validateCorrectionQuantityInput('-1'), contains('negative'));
      expect(validateCorrectionQuantityInput('abc'), contains('valid number'));
      expect(validateCorrectionQuantityInput('10.5'), isNull);
      expect(validateCorrectionQuantityInput(''), isNull);
    });
  });

  group('SecondarySalesStockCorrectionService', () {
    test('GET correction data loads successfully', () async {
      final service = SecondarySalesStockCorrectionService(
        getter: (uri) async {
          expect(uri.toString(), contains('secondary-sales/1552/corrections'));
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'statement_id': 1552,
                'enabled': true,
                'permissions': {'can_correct_stock': true},
                'lines': [
                  {
                    'line_index': 0,
                    'product_name': 'ABC',
                    'extracted_opening_qty': 100,
                    'effective_opening_qty': 100,
                    'extracted_closing_qty': 40,
                    'effective_closing_qty': 40,
                  },
                ],
                'correction_history': [],
                'stock_validation': {'status': 'invalid', 'invalid_lines': 1},
              },
            }),
            200,
          );
        },
      );
      final data = await service.fetchCorrections(1552);
      expect(data.statementId, 1552);
      expect(data.stockValidation.displayStatus, 'INVALID');
    });

    test('403 on GET shows permission message', () async {
      final service = SecondarySalesStockCorrectionService(
        getter: (_) async => http.Response('{}', 403),
      );
      expect(
        () => service.fetchCorrections(1),
        throwsA(
          isA<SecondarySalesStockCorrectionException>()
              .having((e) => e.isForbidden, 'forbidden', isTrue)
              .having((e) => e.message, 'message', contains('permission')),
        ),
      );
    });

    test('save requires reason and changed fields', () async {
      final service = SecondarySalesStockCorrectionService();
      expect(
        () => service.saveCorrections(
          statementId: 1,
          reason: 'abc',
          originalLines: const [],
          drafts: const {},
        ),
        throwsA(
          isA<SecondarySalesStockCorrectionException>().having(
            (e) => e.message,
            'message',
            contains('reason'),
          ),
        ),
      );
    });

    test('POST save then refresh succeeds', () async {
      var postCalled = false;
      var getCount = 0;
      final service = SecondarySalesStockCorrectionService(
        getter: (_) async {
          getCount++;
          return http.Response(
            jsonEncode({
              'data': {
                'statement_id': 9,
                'enabled': true,
                'permissions': {'can_correct_stock': true},
                'lines': [
                  {
                    'line_index': 4,
                    'product_name': 'A',
                    'effective_opening_qty': 105,
                    'effective_closing_qty': 45,
                    'opening_corrected': true,
                    'closing_corrected': true,
                    'stock_validation': {'status': 'valid'},
                  },
                ],
                'correction_history': [],
                'stock_validation': {'status': 'valid', 'valid_lines': 1},
              },
            }),
            200,
          );
        },
        poster: (uri, {body}) async {
          postCalled = true;
          expect(uri.toString(), contains('/corrections'));
          final decoded = jsonDecode(body.toString()) as Map;
          expect(decoded['reason'], isNotEmpty);
          expect(decoded['corrections'], isA<List>());
          return http.Response(jsonEncode({'success': true}), 200);
        },
      );

      final result = await service.saveCorrections(
        statementId: 9,
        reason: 'Verified physical stock against statement',
        originalLines: const [
          SecondarySalesCorrectionLine(
            lineIndex: 4,
            productName: 'A',
            effectiveOpeningQty: 100,
            effectiveClosingQty: 40,
          ),
        ],
        drafts: {
          4: SecondarySalesCorrectionDraft(
            lineIndex: 4,
            openingQty: 105,
            closingQty: 45,
          ),
        },
      );
      expect(postCalled, isTrue);
      expect(getCount, greaterThanOrEqualTo(1));
      expect(result.stockValidation.displayStatus, 'VALID');
      expect(result.lines.first.effectiveOpeningQty, 105);
    });

    test('422 validation errors are surfaced', () async {
      final service = SecondarySalesStockCorrectionService(
        poster: (_, {body}) async => http.Response(
          jsonEncode({
            'message': 'The given data was invalid.',
            'errors': {
              'corrections.0.opening_qty': ['Opening qty is invalid.'],
            },
          }),
          422,
        ),
      );
      expect(
        () => service.saveCorrections(
          statementId: 1,
          reason: 'Verified physical stock against statement',
          originalLines: const [
            SecondarySalesCorrectionLine(
              lineIndex: 0,
              productName: 'A',
              effectiveOpeningQty: 1,
            ),
          ],
          drafts: {
            0: SecondarySalesCorrectionDraft(lineIndex: 0, openingQty: 2),
          },
        ),
        throwsA(
          isA<SecondarySalesStockCorrectionException>()
              .having((e) => e.isValidation, 'validation', isTrue)
              .having(
                (e) => e.message,
                'message',
                contains('Opening qty is invalid.'),
              ),
        ),
      );
    });
  });

  group('Upload Status models and service', () {
    test('parses summary and rows without inventing fields', () {
      final report = SecondarySalesUploadStatusResponse.fromJson({
        'success': true,
        'data': {
          'month': '2026-10',
          'level': 'team',
          'summary': {
            'total_customer': 2733,
            'data_uploaded': 5,
            'data_not_uploaded': 2728,
            'data_uploaded_percentage': 0.18,
            'data_not_uploaded_percentage': 99.82,
          },
          'rows': [
            {
              'id': 10,
              'name': 'Team Alpha',
              'level': 'team',
              'total_customer': 100,
              'data_uploaded': 2,
              'data_not_uploaded': 98,
              'data_uploaded_percentage': 2.0,
              'data_not_uploaded_percentage': 98.0,
            },
          ],
          'pagination': {
            'page': 1,
            'per_page': 50,
            'total': 120,
            'last_page': 3,
          },
        },
      });
      expect(report.summary.totalCustomer, 2733);
      expect(report.summary.dataUploadedPercentage, 0.18);
      expect(report.rows, hasLength(1));
      expect(report.pagination.hasMore, isTrue);
      expect(report.pagination.lastPage, 3);
    });

    test('filter options parse defensively', () {
      final options = SecondarySalesUploadStatusFilterOption.listFrom({
        'data': [
          {'id': 1, 'name': 'ZANDRA', 'code': 'ZANDRA'},
          {'id': 2, 'label': 'Other'},
        ],
      });
      expect(options.map((o) => o.id), [1, 2]);
      expect(options.first.code, 'ZANDRA');
    });

    test('load report with month/division/level', () async {
      final service = SecondarySalesUploadStatusService(
        getter: (uri) async {
          expect(uri.path, contains('upload-status'));
          expect(uri.queryParameters['month'], '2026-10');
          expect(uri.queryParameters['division'], 'ZANDRA');
          expect(uri.queryParameters['level'], 'team');
          return http.Response(
            jsonEncode({
              'data': {
                'month': '2026-10',
                'level': 'team',
                'summary': {
                  'total_customer': 10,
                  'data_uploaded': 1,
                  'data_not_uploaded': 9,
                  'data_uploaded_percentage': 10,
                  'data_not_uploaded_percentage': 90,
                },
                'rows': [],
                'pagination': {
                  'page': 1,
                  'per_page': 50,
                  'total': 0,
                  'last_page': 1,
                },
              },
            }),
            200,
          );
        },
      );
      final report = await service.fetchReport(
        month: '2026-10',
        level: 'team',
        division: 'ZANDRA',
      );
      expect(report.summary.totalCustomer, 10);
      expect(report.rows, isEmpty);
    });

    test('cascading filter keys and pagination URL', () {
      expect(
        secondarySalesUploadStatusFilterUrl('divisions'),
        endsWith('upload-status/filters/divisions'),
      );
      expect(
        secondarySalesUploadStatusFilterUrl('zms'),
        endsWith('upload-status/filters/zms'),
      );
      expect(
        secondarySalesUploadStatusFilterUrl('sms'),
        endsWith('upload-status/filters/sms'),
      );
      expect(
        secondarySalesUploadStatusFilterUrl('nsms'),
        endsWith('upload-status/filters/nsms'),
      );
      expect(
        secondarySalesUploadStatusFilterUrl('states'),
        endsWith('upload-status/filters/states'),
      );
      expect(
        secondarySalesUploadStatusFilterUrl('teams'),
        endsWith('upload-status/filters/teams'),
      );
      expect(
        secondarySalesUploadStatusFilterUrl('employees'),
        endsWith('upload-status/filters/employees'),
      );
      expect(
        secondarySalesUploadStatusFilterUrl('stockists'),
        endsWith('upload-status/filters/stockists'),
      );
      expect(
        secondarySalesUploadStatusStockistSummaryUrl(44),
        endsWith('upload-status/stockists/44/summary'),
      );
      expect(
        secondarySalesCorrectionsUrl(1552),
        endsWith('secondary-sales/1552/corrections'),
      );
    });

    test('stockist summary parse uses Laravel monetary values', () {
      final summary = SecondarySalesUploadStatusStockistSummary.fromJson({
        'data': {
          'stockist_id': 44,
          'stockist_name': 'RICHA PHARMA',
          'month': '2026-10',
          'consolidated': {
            'opening_value': 1000.5,
            'purchase_value': 200,
            'sales_value': 300,
            'closing_value': 900.5,
            'opening_qty': 10,
            'purchase_qty': 2,
            'sales_qty': 3,
            'closing_qty': 9,
          },
        },
      });
      expect(summary.openingValue, 1000.5);
      expect(summary.receiptValue, 200);
      expect(summary.salesValue, 300);
      expect(summary.closingQty, 9);
    });

    test('403 hierarchy restriction', () async {
      final service = SecondarySalesUploadStatusService(
        getter: (_) async => http.Response('{}', 403),
      );
      expect(
        () => service.fetchReport(month: '2026-10', level: 'team'),
        throwsA(
          isA<SecondarySalesUploadStatusException>()
              .having((e) => e.isForbidden, 'forbidden', isTrue),
        ),
      );
    });

    test('network/API failure is handled', () async {
      final service = SecondarySalesUploadStatusService(
        getter: (_) async => http.Response('boom', 500),
      );
      expect(
        () => service.fetchReport(month: '2026-10', level: 'customer'),
        throwsA(isA<SecondarySalesUploadStatusException>()),
      );
    });

    test('customer level is supported', () {
      expect(
        kSecondarySalesUploadStatusLevels.any((e) => e.key == 'customer'),
        isTrue,
      );
    });
  });
}
