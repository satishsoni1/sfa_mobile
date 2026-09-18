import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/screens/pod_upload_screen.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';

void main() {
  group('selected month is sent to Laravel', () {
    test('upload request includes statement_month as YYYY-MM', () {
      final fields = buildSecondarySalesUploadFields(
        stockistId: 2227,
        selectedMonth: DateTime(2026, 9, 14),
      );
      expect(fields['statement_month'], '2026-09');
      expect(fields['stockist_id'], '2227');
    });
  });

  group('filename is not used for statement-month validation', () {
    test('filename without a month is allowed to proceed to API', () {
      expect(
        secondarySalesClientBlocksOnFilenameMonth('35263133277806.jpg'),
        isFalse,
      );
      expect(secondarySalesShouldNavigateToStatus(200), isTrue);
    });

    test('JPG/PNG/PDF/Excel filenames without dates are not rejected client-side',
        () {
      const files = [
        '35263133277806.jpg',
        'scan.png',
        'statement.pdf',
        'stock.xlsx',
        'stock.xls',
      ];
      for (final name in files) {
        expect(
          secondarySalesClientBlocksOnFilenameMonth(name),
          isFalse,
          reason: name,
        );
      }
    });
  });

  group('Laravel 422 statement-month messages', () {
    test('displays selected-month mismatch message', () {
      final message = secondarySalesUploadUnprocessableMessage(
        jsonEncode({
          'success': false,
          'message': kSecondarySalesMonthMismatchMessage,
        }),
      );
      expect(message, 'You can upload statements of the selected month only.');
      expect(secondarySalesShouldNavigateToStatus(422), isFalse);
    });

    test('displays undetermined-month message', () {
      final message = secondarySalesUploadUnprocessableMessage(
        jsonEncode({
          'success': false,
          'message': kSecondarySalesMonthUndeterminedMessage,
        }),
      );
      expect(
        message,
        'Unable to determine the statement month. Please upload a valid stock statement.',
      );
      expect(secondarySalesShouldNavigateToStatus(422), isFalse);
    });
  });

  group('successful upload behavior remains unchanged', () {
    test('200/201/202 still navigate to upload status', () {
      expect(secondarySalesShouldNavigateToStatus(200), isTrue);
      expect(secondarySalesShouldNavigateToStatus(201), isTrue);
      expect(secondarySalesShouldNavigateToStatus(202), isTrue);
      expect(secondarySalesShouldNavigateToStatus(403), isFalse);
      expect(secondarySalesShouldNavigateToStatus(422), isFalse);
    });
  });

  group('Invoice POD safety', () {
    test('Himalaya Secondary Sales remains the active upload type', () {
      expect(isSecondarySalesUpload, isTrue);
      expect(kUploadTypeInvoicePod, 'invoice_pod');
    });
  });

  group('PODUploadScreen month selector', () {
    testWidgets('keeps the statement month selector', (tester) async {
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
