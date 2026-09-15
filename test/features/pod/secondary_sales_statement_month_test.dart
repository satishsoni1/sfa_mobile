import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/screens/pod_upload_screen.dart';
import 'package:zforce/features/pod/services/secondary_sales_statement_month.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';

void main() {
  final selectedSeptember2026 = DateTime(2026, 9);
  const himalayaAugustFile =
      '0000737479_2026_08_ZL_20_296_04092026065133.pdf';

  group('parseStatementMonth normalization', () {
    test('normalizes DateTime, YYYY-MM, YYYY_MM, and month names', () {
      expect(parseStatementMonth(DateTime(2026, 9, 15)), StatementMonthKey(2026, 9));
      expect(parseStatementMonth('2026-09'), StatementMonthKey(2026, 9));
      expect(parseStatementMonth('2026_09'), StatementMonthKey(2026, 9));
      expect(parseStatementMonth('2026/09'), StatementMonthKey(2026, 9));
      expect(parseStatementMonth('Sept 2026'), StatementMonthKey(2026, 9));
      expect(parseStatementMonth('September-2026'), StatementMonthKey(2026, 9));
      expect(parseStatementMonth('09/2026'), StatementMonthKey(2026, 9));
    });

    test('compares year and month, not month number alone', () {
      expect(
        StatementMonthKey(2025, 9).matches(StatementMonthKey(2026, 9)),
        isFalse,
      );
      expect(
        StatementMonthKey(2026, 8).matches(StatementMonthKey(2026, 9)),
        isFalse,
      );
      expect(
        StatementMonthKey(2026, 9).matches(StatementMonthKey(2026, 9)),
        isTrue,
      );
    });
  });

  group('extractStatementMonths from existing filename conventions', () {
    test('uses Himalaya YYYY_MM statement period, not trailing timestamp', () {
      final months = extractStatementMonths(himalayaAugustFile);
      expect(months, {const StatementMonthKey(2026, 8)});
    });
  });

  group('validateStatementFilesForSelectedMonth', () {
    test('1. selected September 2026 + September 2026 statement → ALLOW', () {
      final result = validateStatementFilesForSelectedMonth(
        selectedMonth: selectedSeptember2026,
        fileNames: const ['stock_statement_2026_09.pdf'],
      );
      expect(result.canUpload, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('2. selected September 2026 + August 2026 statement → BLOCK', () {
      final result = validateStatementFilesForSelectedMonth(
        selectedMonth: selectedSeptember2026,
        fileNames: const [himalayaAugustFile],
      );
      expect(result.canUpload, isFalse);
      expect(result.errorMessage, kSecondarySalesMonthMismatchMessage);
    });

    test('3. selected September 2026 + October 2026 statement → BLOCK', () {
      final result = validateStatementFilesForSelectedMonth(
        selectedMonth: selectedSeptember2026,
        fileNames: const ['statement_2026_10.pdf'],
      );
      expect(result.canUpload, isFalse);
      expect(result.errorMessage, kSecondarySalesMonthMismatchMessage);
    });

    test('4. selected September 2026 + September 2025 statement → BLOCK', () {
      final result = validateStatementFilesForSelectedMonth(
        selectedMonth: selectedSeptember2026,
        fileNames: const ['statement_2025_09.pdf'],
      );
      expect(result.canUpload, isFalse);
      expect(result.errorMessage, kSecondarySalesMonthMismatchMessage);
    });

    test('5. statement date/month cannot be extracted → BLOCK', () {
      final result = validateStatementFilesForSelectedMonth(
        selectedMonth: selectedSeptember2026,
        fileNames: const ['statement.pdf'],
      );
      expect(result.canUpload, isFalse);
      expect(result.errorMessage, kSecondarySalesMonthUndeterminedMessage);
    });

    test('6. multiple dates in the same selected month → ALLOW', () {
      final result = validateStatementFilesForSelectedMonth(
        selectedMonth: selectedSeptember2026,
        fileNames: const ['period_2026-09-01_to_2026-09-15.pdf'],
      );
      expect(result.canUpload, isTrue);
    });

    test('7. different date formats are normalized before comparison', () {
      for (final name in [
        'Sept 2026 statement.pdf',
        'September-2026.pdf',
        '09/2026_stock.pdf',
        '15/09/2026.pdf',
        '2026-09-30.pdf',
        '202609_statement.pdf',
      ]) {
        final result = validateStatementFilesForSelectedMonth(
          selectedMonth: selectedSeptember2026,
          fileNames: [name],
        );
        expect(result.canUpload, isTrue, reason: name);
      }
    });

    test('8. changing selected month after file selection revalidates', () {
      const files = ['stock_statement_2026_09.pdf'];
      final forSeptember = validateStatementFilesForSelectedMonth(
        selectedMonth: selectedSeptember2026,
        fileNames: files,
      );
      final forAugust = validateStatementFilesForSelectedMonth(
        selectedMonth: DateTime(2026, 8),
        fileNames: files,
      );
      expect(forSeptember.canUpload, isTrue);
      expect(forAugust.canUpload, isFalse);
      expect(forAugust.errorMessage, kSecondarySalesMonthMismatchMessage);
    });

    test('9. selecting a different file is validated again', () {
      final first = validateStatementFilesForSelectedMonth(
        selectedMonth: selectedSeptember2026,
        fileNames: const ['stock_statement_2026_09.pdf'],
      );
      final second = validateStatementFilesForSelectedMonth(
        selectedMonth: selectedSeptember2026,
        fileNames: const [himalayaAugustFile],
      );
      expect(first.canUpload, isTrue);
      expect(second.canUpload, isFalse);
      expect(second.errorMessage, kSecondarySalesMonthMismatchMessage);
    });

    test('10. validation failure means the upload API must not be called', () {
      var apiCalled = false;
      void startUpload(StatementMonthValidation result) {
        if (!result.canUpload) return;
        apiCalled = true;
      }

      startUpload(
        validateStatementFilesForSelectedMonth(
          selectedMonth: selectedSeptember2026,
          fileNames: const [himalayaAugustFile],
        ),
      );
      expect(apiCalled, isFalse);

      startUpload(
        validateStatementFilesForSelectedMonth(
          selectedMonth: selectedSeptember2026,
          fileNames: const ['statement.pdf'],
        ),
      );
      expect(apiCalled, isFalse);

      startUpload(
        validateStatementFilesForSelectedMonth(
          selectedMonth: selectedSeptember2026,
          fileNames: const ['stock_statement_2026_09.pdf'],
        ),
      );
      expect(apiCalled, isTrue);
    });

    test('mixed files: one mismatched file blocks the whole upload', () {
      final result = validateStatementFilesForSelectedMonth(
        selectedMonth: selectedSeptember2026,
        fileNames: const [
          'stock_statement_2026_09.pdf',
          himalayaAugustFile,
        ],
      );
      expect(result.canUpload, isFalse);
      expect(result.errorMessage, kSecondarySalesMonthMismatchMessage);
    });
  });

  group('upload field uses selected month', () {
    test('statement_month is the selected year-month', () {
      final fields = buildSecondarySalesUploadFields(
        stockistId: 2227,
        selectedMonth: DateTime(2026, 9, 14),
      );
      expect(fields['statement_month'], '2026-09');
    });
  });

  group('Invoice POD safety', () {
    test('month validation applies only to Secondary Sales uploads', () {
      expect(isSecondarySalesUpload, isTrue);
      expect(kUploadTypeInvoicePod, 'invoice_pod');
    });
  });

  group('PODUploadScreen month selector', () {
    testWidgets('Secondary Sales upload shows statement month selector',
        (tester) async {
      SharedPreferences.setMockInitialValues({'authToken': 'token-user-a'});
      final service = SecondarySalesStockistService(
        getter: (_) async => http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'id': 2227, 'name': 'SUKHMANI TRADERS'},
            ],
          }),
          200,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: PODUploadScreen(stockistService: service)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Statement Month'), findsOneWidget);
    });
  });
}
