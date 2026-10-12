import 'package:flutter/material.dart';
import 'package:zforce/features/pod/models/secondary_sales_validation_failure.dart';

/// In-app dialog for FCM `stock_validation_failed`.
class SecondarySalesStockValidationFailedDialog extends StatelessWidget {
  const SecondarySalesStockValidationFailedDialog({
    super.key,
    required this.failure,
    required this.onReprocess,
    required this.onReupload,
    this.isReprocessing = false,
  });

  final SecondarySalesValidationFailure failure;
  final VoidCallback onReprocess;
  final VoidCallback onReupload;
  final bool isReprocessing;

  static Future<void> show(
    BuildContext context, {
    required SecondarySalesValidationFailure failure,
    required Future<void> Function() onReprocess,
    required VoidCallback onReupload,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var busy = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return SecondarySalesStockValidationFailedDialog(
              failure: failure,
              isReprocessing: busy,
              onReprocess: () async {
                if (busy) return;
                setState(() => busy = true);
                try {
                  await onReprocess();
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } catch (_) {
                  if (context.mounted) setState(() => busy = false);
                }
              },
              onReupload: () {
                if (busy) return;
                Navigator.of(dialogContext).pop();
                onReupload();
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Stock Statement Validation Failed',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('Opening Stock', failure.display(failure.openingStock)),
            _row('Purchases', failure.display(failure.purchases)),
            _row('Closing Stock', failure.display(failure.closingStock)),
            const SizedBox(height: 8),
            _row(
              'Maximum allowed Closing Stock',
              failure.display(failure.maximumAllowedClosingStock),
              emphasize: true,
            ),
            const SizedBox(height: 14),
            Text(
              'Closing Stock cannot be greater than Opening Stock + Purchases.\n\n'
              'Please reprocess the file or upload the correct stock statement.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: isReprocessing ? null : onReupload,
          child: const Text('Re-upload'),
        ),
        ElevatedButton(
          onPressed: isReprocessing ? null : onReprocess,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF450095),
            foregroundColor: Colors.white,
          ),
          child: isReprocessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Reprocess'),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
                color: const Color(0xFF5D6570),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: emphasize
                    ? const Color(0xFF450095)
                    : const Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
