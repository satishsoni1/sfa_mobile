import 'package:http_parser/http_parser.dart';

/// Document types selectable from the Secondary Sales "Documents" picker.
const List<String> kSecondarySalesDocumentExtensions = [
  'jpg',
  'jpeg',
  'png',
  'pdf',
  'xls',
  'xlsx',
  'txt',
  'doc',
  'docx',
  'zip',
  'html',
  'htm',
];

const bool kSecondarySalesDocumentPickerAllowsMultiple = true;

const String kSecondarySalesSupportedFormatsLabel =
    'Supported formats: JPG, JPEG, PNG, PDF, XLS, XLSX, TXT, DOC, DOCX, ZIP';

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

String secondarySalesNormalizedExtension(String? value) {
  return (value ?? '').toLowerCase().replaceFirst(RegExp(r'^\.'), '').trim();
}

bool isSecondarySalesDocumentExtension(String? extension) {
  final ext = secondarySalesNormalizedExtension(extension);
  return kSecondarySalesDocumentExtensions.contains(ext);
}

bool isSecondarySalesExcelExtension(String? extension) {
  final ext = secondarySalesNormalizedExtension(extension);
  return ext == 'xls' || ext == 'xlsx';
}

/// Prefer a supported path or picker extension so Android MIME mismatches
/// cannot reject a valid .xls / .xlsx file.
String secondarySalesResolvedExtension({
  String? pathExtension,
  String? pickerExtension,
}) {
  final fromPath = secondarySalesNormalizedExtension(pathExtension);
  final fromPicker = secondarySalesNormalizedExtension(pickerExtension);
  if (isSecondarySalesDocumentExtension(fromPath)) return fromPath;
  if (isSecondarySalesDocumentExtension(fromPicker)) return fromPicker;
  return fromPath.isNotEmpty ? fromPath : fromPicker;
}

MediaType secondarySalesContentTypeForExtension(String extension) {
  switch (secondarySalesNormalizedExtension(extension)) {
    case 'pdf':
      return MediaType('application', 'pdf');
    case 'xls':
      return MediaType('application', 'vnd.ms-excel');
    case 'xlsx':
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
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
    case 'zip':
      return MediaType('application', 'zip');
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'png':
      return MediaType('image', 'png');
    default:
      return MediaType('application', 'octet-stream');
  }
}
