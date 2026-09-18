import 'package:flutter/material.dart';
import 'package:zforce/features/pod/config/secondary_sales_upload_files.dart';

class SecondarySalesUploadSourceSheet extends StatelessWidget {
  const SecondarySalesUploadSourceSheet({
    super.key,
    required this.onCamera,
    required this.onDocuments,
    required this.onGallery,
    required this.onScanner,
  });

  final VoidCallback onCamera;
  final VoidCallback onDocuments;
  final VoidCallback onGallery;
  final VoidCallback onScanner;

  static const Color _iconColor = Color(0xFF450095);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(kSecondarySalesUploadFilesTitle),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _option(
            context,
            icon: Icons.camera_alt,
            title: kSecondarySalesCameraOptionTitle,
            subtitle: kSecondarySalesCameraOptionSubtitle,
            onTap: onCamera,
          ),
          _option(
            context,
            icon: Icons.insert_drive_file,
            title: kSecondarySalesDocumentsOptionTitle,
            subtitle: kSecondarySalesDocumentsOptionSubtitle,
            onTap: onDocuments,
          ),
          _option(
            context,
            icon: Icons.photo_library,
            title: kSecondarySalesGalleryOptionTitle,
            subtitle: kSecondarySalesGalleryOptionSubtitle,
            onTap: onGallery,
          ),
          _option(
            context,
            icon: Icons.document_scanner,
            title: kSecondarySalesScannerOptionTitle,
            subtitle: kSecondarySalesScannerOptionSubtitle,
            onTap: onScanner,
          ),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: _iconColor),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}
