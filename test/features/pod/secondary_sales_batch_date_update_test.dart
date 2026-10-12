import 'package:flutter_test/flutter_test.dart';
import 'package:zforce/features/pod/models/batch_model.dart';
import 'package:zforce/features/pod/services/secondary_sales_data_refresh.dart';

void main() {
  group('Batch statement date', () {
    test('parses statement date aliases and allows change when completed', () {
      final batch = Batch.fromJson({
        'id': 461,
        'status': 'completed',
        'total_files': 1,
        'successful_files': 0,
        'failed_files': 0,
        'statement_date': '2026-08-28',
        'has_validation_issue': true,
        'validation_message':
            'You can upload statements of the selected month only.',
        'hospital_name': 'M/S MEDICINE HOUSE',
        'stockist': 'MEDICINE HOUSE',
        'created_at': '2026-08-28T10:00:00+05:30',
        'updated_at': '2026-08-28T10:05:00+05:30',
      });

      expect(batch.statementDate, '2026-08-28');
      expect(batch.parsedStatementDate, DateTime(2026, 8, 28));
      expect(batch.canChangeStatementDate, isTrue);
      expect(batch.showsValidationIssue, isTrue);
    });

    test('hides change-date for processing batches', () {
      final batch = Batch.fromJson({
        'id': 462,
        'status': 'processing',
        'date': '2026-09-01',
        'created_at': '',
        'updated_at': '',
      });
      expect(batch.isProcessingStatus, isTrue);
      expect(batch.canChangeStatementDate, isFalse);
    });

    test('clears validation when API returns false/null', () {
      final batch = Batch.fromJson({
        'id': 461,
        'status': 'completed',
        'date': '2026-09-28',
        'has_validation_issue': false,
        'validation_message': null,
        'created_at': '',
        'updated_at': '',
      });
      expect(batch.hasValidationIssue, isFalse);
      expect(batch.validationMessage, isNull);
      expect(batch.showsValidationIssue, isFalse);
      expect(batch.statementDate, '2026-09-28');
      expect(batch.canChangeStatementDate, isTrue);
    });
  });

  group('SecondarySalesDataRefresh', () {
    test('notify bumps tick for listeners', () {
      final before = SecondarySalesDataRefresh.tick.value;
      var heard = 0;
      void listener() => heard++;
      SecondarySalesDataRefresh.tick.addListener(listener);
      SecondarySalesDataRefresh.notify();
      SecondarySalesDataRefresh.tick.removeListener(listener);
      expect(SecondarySalesDataRefresh.tick.value, before + 1);
      expect(heard, 1);
    });
  });
}
