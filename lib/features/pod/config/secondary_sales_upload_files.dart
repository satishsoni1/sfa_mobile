import 'package:http_parser/http_parser.dart';

/// Document types selectable from the Secondary Sales "Documents" picker.
const List<String> kSecondarySalesDocumentExtensions = [
  'pdf',
  'doc',
  'docx',
  'txt',
  'jpg',
  'jpeg',
  'png',
  'html',
  'htm',
];

const bool kSecondarySalesDocumentPickerAllowsMultiple = true;

const String kSecondarySalesUploadFilesTitle = 'Upload Files';
const String kSecondarySalesCameraOptionTitle = 'Camera';
const String kSecondarySalesCameraOptionSubtitle = 'Take a photo';
const String kSecondarySalesDocumentsOptionTitle = 'Documents';
const String kSecondarySalesDocumentsOptionSubtitle =
    'Select files from device';
const String kSecondarySalesGalleryOptionTitle = 'Gallery';
const String kSecondarySalesGalleryOptionSubtitle = 'Select photos';
const String kSecondarySalesScannerOptionTitle = 'Scanner';
const String kSecondarySalesScannerOptionSubtitle = 'Scan a document';

bool isSecondarySalesDocumentExtension(String extension) {
  final ext = extension.toLowerCase().replaceFirst('.', '');
  return kSecondarySalesDocumentExtensions.contains(ext);
}

MediaType secondarySalesContentTypeForExtension(String extension) {
  switch (extension.toLowerCase().replaceFirst('.', '')) {
    case 'pdf':
      return MediaType('application', 'pdf');
    case 'doc':
      return MediaType('application', 'msword');
    case 'docx':
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    case 'txt':
      return MediaType('text', 'plain');
    case 'html':
    case 'htm':
      return MediaType('text', 'html');
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'png':
      return MediaType('image', 'png');
    default:
      return MediaType('application', 'octet-stream');
  }
}
