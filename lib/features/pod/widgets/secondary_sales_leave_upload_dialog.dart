import 'package:flutter/material.dart';

/// Confirms leaving the Secondary Sales / POD Upload screen.
///
/// Returns `true` when the user chooses Go Back, otherwise `false`/`null`.
Future<bool> showSecondarySalesLeaveUploadDialog(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.upload_file,
            color: Color(0xFF450095),
            size: 28,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Leave Upload?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
      content: const Text(
        'Do you want to go back from the Upload screen?',
        style: TextStyle(
          color: Color(0xFF7F8C8D),
          fontSize: 16,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Color(0xFF7F8C8D),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF450095),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'Go Back',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ],
    ),
  );
  return leave == true;
}
