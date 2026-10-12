import 'package:flutter_test/flutter_test.dart';
import 'package:zforce/features/pod/models/batch_model.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/models/statement_detail_model.dart';

void main() {
  group('Batch validation + name parsing', () {
    test('parses Batch #459-style validation-only completed payload', () {
      final batch = Batch.fromJson({
        'id': 459,
        'user_id': 1,
        'hospital_id': 0,
        'stockist_id': 869,
        'total_files': 1,
        'successful_files': 0,
        'failed_files': 0,
        'cancelled_files': 0,
        'status': 'completed',
        'has_validation_issue': true,
        'validation_message':
            'You can upload statements of the selected month only.',
        'hospital_name': 'M/S MEDICINE HOUSE',
        'stockist': 'MEDICINE HOUSE',
        'created_at': '2026-09-28T10:00:00+05:30',
        'updated_at': '2026-09-28T10:05:00+05:30',
      });

      expect(batch.status, 'completed');
      expect(batch.totalFiles, 1);
      expect(batch.successfulFiles, 0);
      expect(batch.failedFiles, 0);
      expect(batch.hasValidationIssue, isTrue);
      expect(
        batch.validationMessage,
        'You can upload statements of the selected month only.',
      );
      expect(batch.showsValidationIssue, isTrue);
      expect(batch.displayStatus, 'COMPLETED');
      expect(batch.isCompletedStatus, isTrue);
      expect(batch.hospitalName, 'M/S MEDICINE HOUSE');
      expect(batch.stockistName, 'MEDICINE HOUSE');
      expect(batch.stockistId, 869);
      expect(batch.hospitalName.contains('Unknown'), isFalse);
      expect(batch.stockistName.contains('Unknown'), isFalse);
    });

    test('maps backend status labels for list/detail badges', () {
      expect(
        Batch.fromJson({
          'id': 1,
          'status': 'completed',
          'created_at': '',
          'updated_at': '',
        }).displayStatus,
        'COMPLETED',
      );
      expect(
        Batch.fromJson({
          'id': 2,
          'status': 'queued',
          'created_at': '',
          'updated_at': '',
        }).displayStatus,
        'PROCESSING',
      );
      expect(
        Batch.fromJson({
          'id': 3,
          'status': 'processing',
          'created_at': '',
          'updated_at': '',
        }).displayStatus,
        'PROCESSING',
      );
      expect(
        Batch.fromJson({
          'id': 4,
          'status': 'failed',
          'created_at': '',
          'updated_at': '',
        }).displayStatus,
        'FAILED',
      );
    });

    test('parses statement month and period fields for details', () {
      final batch = Batch.fromJson({
        'id': 461,
        'status': 'completed',
        'statement_date': '2026-09-15',
        'statement_month': '2026-09',
        'period_from': '2026-09-01',
        'period_to': '2026-09-30',
        'hospital_name': 'HIMALAYA WELLNESS COMPANY',
        'stockist': 'MEDICINE HOUSE',
        'created_at': '2026-09-28T10:00:00+05:30',
        'updated_at': '2026-09-28T10:05:00+05:30',
      });

      expect(batch.displayStatus, 'COMPLETED');
      expect(batch.displayStatementMonth, 'Sep 2026');
      expect(batch.periodFrom, '2026-09-01');
      expect(batch.periodTo, '2026-09-30');
      expect(batch.resolvedHospitalName, 'HIMALAYA WELLNESS COMPANY');
      expect(batch.resolvedStockistName, 'MEDICINE HOUSE');
      expect(batch.effectiveStatementDate, DateTime(2026, 9, 15));
    });

    test('parses document ids for statement details navigation', () {
      final fromList = Batch.fromJson({
        'id': 461,
        'status': 'completed',
        'document_ids': [9021, 9022],
        'created_at': '',
        'updated_at': '',
      });
      expect(fromList.documentIds, [9021, 9022]);
      expect(fromList.primaryDocumentId, 9021);
      expect(fromList.canOpenStatementDetails, isTrue);

      final fromNested = Batch.fromJson({
        'id': 462,
        'status': 'completed',
        'documents': [
          {'id': 7001},
          {'document_id': 7002},
        ],
        'created_at': '',
        'updated_at': '',
      });
      expect(fromNested.documentIds, [7001, 7002]);
      expect(fromNested.primaryDocumentId, 7001);

      final fromMeta = Batch.fromJson({
        'id': 463,
        'status': 'completed',
        'metadata': {
          'pod_ids': [55],
        },
        'created_at': '',
        'updated_at': '',
      });
      expect(fromMeta.primaryDocumentId, 55);
    });

    test('supports camelCase validation fields', () {
      final batch = Batch.fromJson({
        'id': 1,
        'totalFiles': 1,
        'successfulFiles': 0,
        'failedFiles': 0,
        'status': 'completed',
        'hasValidationIssue': true,
        'validationMessage': 'Month mismatch',
        'hospitalName': 'Acme Hospital',
        'stockistName': 'Acme Stockist',
        'createdAt': '',
        'updatedAt': '',
      });
      expect(batch.hasValidationIssue, isTrue);
      expect(batch.validationMessage, 'Month mismatch');
      expect(batch.hospitalName, 'Acme Hospital');
      expect(batch.stockistName, 'Acme Stockist');
    });
  });

  group('Stockist Statements list parsing', () {
    test('keeps validation-only completed statements', () {
      final statement = SecondarySalesStockistStatement.fromJson({
        'id': 100,
        'document_id': 100,
        'batch_id': 459,
        'file_name': 'medicine_house.pdf',
        'status': 'completed',
        'stockist': 'MEDICINE HOUSE',
        'hospital_name': 'M/S MEDICINE HOUSE',
        'sales': 0,
        'product_count': 0,
        'has_validation_issue': true,
        'validation_message':
            'You can upload statements of the selected month only.',
        'statement_month': '2026-09',
      });

      expect(statement.isCompleted, isTrue);
      expect(statement.isFailed, isFalse);
      expect(statement.hasValidationIssue, isTrue);
      expect(statement.showsValidationIssue, isTrue);
      expect(statement.stockistName, 'MEDICINE HOUSE');
      expect(statement.hospitalName, 'M/S MEDICINE HOUSE');
      expect(statement.sales, 0);
      expect(statement.batchId, 459);
    });

    test('parses string stockist on performance rows (zero sales)', () {
      final row = SecondarySalesStockistPerformance.fromJson({
        'stockist_id': 869,
        'stockist': 'MEDICINE HOUSE',
        'sales': 0,
        'statements': 1,
        'completed_statements': 1,
        'kam_name': null,
      });
      expect(row.stockistId, 869);
      expect(row.stockistName, 'MEDICINE HOUSE');
      expect(row.documents, 1);
      expect(row.completedStatements, 1);
      expect(row.sales, 0);
      expect(row.kamLabel, 'Unassigned');
    });

    test('visibleStockists merges performance and breakdown rows', () {
      final data = SecondarySalesDashboardData.fromJson({
        'data': {
          'filters': {},
          'overview': {},
          'summary': {},
          'performance_breakdown': {
            'stockist': [
              {
                'id': 869,
                'name': 'MEDICINE HOUSE',
                'sales': 0,
                'processed': 1,
              },
            ],
          },
          'stockist_performance': [
            {
              'stockist_id': 2134,
              'stockist_name': 'KAMAL DRUG DISTRIBUTORS',
              'sales': 100,
              'statements': 2,
              'completed_statements': 2,
            },
          ],
          'recent_documents': [
            {
              'id': 99,
              'stockist_id': 869,
              'stockist_name': 'MEDICINE HOUSE',
              'name': 'latest.pdf',
              'status': 'completed',
              'uploaded_at': '2026-09-28T20:00:00+05:30',
            },
            {
              'id': 50,
              'stockist_id': 2134,
              'stockist_name': 'KAMAL DRUG DISTRIBUTORS',
              'name': 'older.pdf',
              'status': 'completed',
              'uploaded_at': '2026-09-10T10:00:00+05:30',
            },
          ],
        },
      });

      final visible = data.visibleStockists;
      expect(visible.length, 2);
      expect(visible.first.stockistId, 869);
      expect(visible.first.stockistName, 'MEDICINE HOUSE');
      expect(visible[1].stockistId, 2134);
    });
  });

  group('StatementDetail validation', () {
    test('parses validation fields and flat hospital/stockist names', () {
      final detail = StatementDetail.fromJson({
        'id': 100,
        'status': 'completed',
        'has_validation_issue': true,
        'validation_message':
            'You can upload statements of the selected month only.',
        'hospital_name': 'M/S MEDICINE HOUSE',
        'stockist': 'MEDICINE HOUSE',
        'items': [],
      });

      expect(detail.status, 'completed');
      expect(detail.hasValidationIssue, isTrue);
      expect(detail.showsValidationIssue, isTrue);
      expect(
        detail.validationMessage,
        'You can upload statements of the selected month only.',
      );
      expect(detail.hospitalDisplayName, 'M/S MEDICINE HOUSE');
      expect(detail.stockistDisplayName, 'MEDICINE HOUSE');
    });
  });
}
