import 'package:flutter_test/flutter_test.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/secondary_sales_validation_failure.dart';
import 'package:zforce/data/services/fcm_notification_service.dart';

void main() {
  group('SecondarySalesValidationFailure', () {
    test('parses FCM string data safely', () {
      final failure = SecondarySalesValidationFailure.fromMessageData({
        'action': 'stock_validation_failed',
        'batch_id': '99',
        'upload_id': 'u-1',
        'validation_code': 'CLOSING_EXCEEDS_MAX',
        'opening_stock': '1000',
        'purchases': '100',
        'closing_stock': '1250',
        'maximum_allowed_closing_stock': '1100',
      });

      expect(failure.batchId, 99);
      expect(failure.uploadId, 'u-1');
      expect(failure.openingStock, '1000');
      expect(failure.purchases, '100');
      expect(failure.closingStock, '1250');
      expect(failure.maximumAllowedClosingStock, '1100');
      expect(failure.display(null), '—');
    });

    test(' tolerates missing numeric batch id', () {
      final failure = SecondarySalesValidationFailure.fromMessageData({
        'batch_id': 'abc',
        'opening_stock': '10',
      });
      expect(failure.batchId, isNull);
      expect(failure.openingStock, '10');
    });
  });

  group('FCM actions and URLs', () {
    test('known action constants', () {
      expect(kFcmActionProcessingCompleted, 'processing_completed');
      expect(kFcmActionStockValidationFailed, 'stock_validation_failed');
    });

    test('reprocess URL matches Laravel contract', () {
      expect(
        secondarySalesBatchReprocessUrl(42),
        endsWith('secondary-sales/batches/42/reprocess'),
      );
    });
  });
}
