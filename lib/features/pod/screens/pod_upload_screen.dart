// Mobile-only POD Upload Screen - Android/iOS
// All web logic removed - uses native Flutter plugins

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zforce/features/pod/models/_SplitOut.dart';
import 'package:zforce/features/pod/models/upload_record.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/config/secondary_sales_upload_files.dart';
import 'package:zforce/features/pod/screens/upload_status_screen.dart';
import 'package:zforce/features/pod/routes/pod_routes.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/screens/secondary_sales_kam_stockists_screen.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_list_controller.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';
import 'package:zforce/features/pod/services/upload_record_store.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/widgets/secondary_sales_stockist_picker.dart';
import 'package:zforce/features/pod/widgets/secondary_sales_upload_source_sheet.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:zforce/features/pod/widgets/PdfPreviewScreen.dart'; // ← ADD
import 'dart:math'; // For min() function

// PDF Splitting API
const String _SPLIT_API_BASE = 'https://anujakkulkarni-splitpdffile.hf.space';

/// Build MultipartFile from File
Future<http.MultipartFile> _multipartFromFile({
  required String fieldName,
  required File file,
  MediaType? contentType,
}) async {
  final filename = p.basename(file.path);
  return http.MultipartFile.fromPath(
    fieldName,
    file.path,
    filename: filename,
    contentType: contentType,
  );
}

/// Split PDF via API
/// Split PDF via API with retry logic, response validation, and fallback
/// Split PDF via API with compression support and better error handling
Future<List<SplitOut>> _splitPdfViaApi(File pdfFile) async {
  const int maxRetries = 3;
  const Duration retryDelay = Duration(seconds: 2);

  for (int attempt = 0; attempt < maxRetries; attempt++) {
    try {
      debugPrint(
        '[SPLIT] Attempt ${attempt + 1}/$maxRetries for ${p.basename(pdfFile.path)}',
      );

      final uri = Uri.parse('$_SPLIT_API_BASE/split-invoices');

      final req =
          http.MultipartRequest('POST', uri)
            ..files.add(
              await _multipartFromFile(
                fieldName: 'file',
                file: pdfFile,
                contentType: MediaType('application', 'pdf'),
              ),
            )
            ..fields['include_pdf'] = 'true'
            ..fields['initial_dpi'] = '300'
            // ✅ NEW: Request compressed response
            ..headers['Accept-Encoding'] = 'gzip, deflate';

      debugPrint('[SPLIT] Sending request...');
      final streamed = await req.send();

      debugPrint('[SPLIT] Response status: ${streamed.statusCode}');
      debugPrint('[SPLIT] Response headers: ${streamed.headers}');

      // ✅ NEW: Monitor response streaming with progress
      int receivedBytes = 0;
      int lastLogBytes = 0;
      final responseChunks = <List<int>>[];

      await for (final chunk in streamed.stream) {
        responseChunks.add(chunk);
        receivedBytes += chunk.length;

        // Log progress every 500KB
        if (receivedBytes - lastLogBytes >= 500000) {
          debugPrint(
            '[SPLIT] Received ${(receivedBytes / 1024 / 1024).toStringAsFixed(2)}MB.. .',
          );
          lastLogBytes = receivedBytes;
        }
      }

      debugPrint(
        '[SPLIT] Total received: ${(receivedBytes / 1024 / 1024).toStringAsFixed(2)}MB',
      );

      // ✅ NEW: Check if response was compressed
      final isCompressed =
          streamed.headers['content-encoding']?.contains('gzip') ?? false;
      debugPrint('[SPLIT] Response compressed: $isCompressed');

      // Combine chunks
      final responseBytes = responseChunks.expand((x) => x).toList();

      // ✅ NEW: Decompress if needed (http package usually does this automatically)
      final bodyBytes = Uint8List.fromList(responseBytes);

      // Handle HTTP errors
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final bodyPreview = utf8.decode(
          bodyBytes.sublist(0, min(200, bodyBytes.length)),
        );
        debugPrint('[SPLIT] HTTP ${streamed.statusCode}: $bodyPreview');

        if (streamed.statusCode >= 500 || streamed.statusCode == 408) {
          if (attempt < maxRetries - 1) {
            debugPrint('[SPLIT] Server error, retrying.. .');
            await Future.delayed(retryDelay);
            continue;
          }
        }

        return _fallbackUnsplitPdf(pdfFile);
      }

      // ✅ NEW: Validate response size
      if (bodyBytes.isEmpty) {
        debugPrint('[SPLIT] ⚠️ Empty response body (Airtel truncation?)');

        if (attempt < maxRetries - 1) {
          debugPrint('[SPLIT] Retrying due to empty body.. .');
          await Future.delayed(retryDelay);
          continue;
        }

        return _fallbackUnsplitPdf(pdfFile);
      }

      // Parse JSON
      String bodyString;
      try {
        bodyString = utf8.decode(bodyBytes);
      } catch (e) {
        debugPrint('[SPLIT] ⚠️ UTF-8 decode failed: $e');

        if (attempt < maxRetries - 1) {
          await Future.delayed(retryDelay);
          continue;
        }

        return _fallbackUnsplitPdf(pdfFile);
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(bodyString);
      } catch (jsonErr) {
        debugPrint('[SPLIT] ⚠️ JSON decode failed: $jsonErr');
        debugPrint('[SPLIT] Body length: ${bodyString.length} chars');
        debugPrint(
          '[SPLIT] Body preview: ${bodyString.substring(0, min(500, bodyString.length))}',
        );
        debugPrint(
          '[SPLIT] Body end: ${bodyString.length > 500 ? bodyString.substring(bodyString.length - 100) : "N/A"}',
        );

        // Check if response was truncated
        if (!bodyString.endsWith('}') && !bodyString.endsWith(']')) {
          debugPrint(
            '[SPLIT] ⚠️ Response appears truncated (doesn\'t end with } or ])',
          );
        }

        if (attempt < maxRetries - 1) {
          debugPrint('[SPLIT] Retrying due to invalid JSON...');
          await Future.delayed(retryDelay);
          continue;
        }

        return _fallbackUnsplitPdf(pdfFile);
      }

      // Validate structure
      if (decoded is! Map) {
        debugPrint('[SPLIT] ⚠️ Response is not a Map: ${decoded.runtimeType}');

        if (attempt < maxRetries - 1) {
          await Future.delayed(retryDelay);
          continue;
        }

        return _fallbackUnsplitPdf(pdfFile);
      }

      if (decoded['parts'] is! List) {
        debugPrint('[SPLIT] ⚠️ Missing "parts" field');
        debugPrint('[SPLIT] Available keys: ${decoded.keys.toList()}');

        if (attempt < maxRetries - 1) {
          await Future.delayed(retryDelay);
          continue;
        }

        return _fallbackUnsplitPdf(pdfFile);
      }

      final parts = decoded['parts'] as List;

      if (parts.isEmpty) {
        debugPrint('[SPLIT] ⚠️ Received 0 parts');

        if (attempt < maxRetries - 1) {
          await Future.delayed(retryDelay);
          continue;
        }

        return _fallbackUnsplitPdf(pdfFile);
      }

      debugPrint('[SPLIT] Processing ${parts.length} parts.. .');

      // ✅ NEW: Log expected vs received size
      if (decoded.containsKey('total_size_bytes')) {
        final expectedSize = decoded['total_size_bytes'] as int?;
        final actualSize = parts.fold<int>(
          0,
          (sum, p) => sum + ((p as Map)['pdf_base64'] as String? ?? '').length,
        );
        debugPrint(
          '[SPLIT] Expected base64 size: ${expectedSize ?? 0}, Actual: $actualSize',
        );

        if (expectedSize != null && actualSize < expectedSize * 0.9) {
          debugPrint(
            '[SPLIT] ⚠️ Response may be truncated (received ${(actualSize / expectedSize * 100).toStringAsFixed(1)}%)',
          );

          if (attempt < maxRetries - 1) {
            debugPrint('[SPLIT] Retrying due to incomplete data...');
            await Future.delayed(retryDelay);
            continue;
          }
        }
      }

      // Process parts
      final tmp = await getTemporaryDirectory();
      final out = <SplitOut>[];
      int skippedParts = 0;

      for (int i = 0; i < parts.length; i++) {
        final e = parts[i];
        if (e is! Map) {
          debugPrint('[SPLIT] Part $i: Not a Map');
          skippedParts++;
          continue;
        }

        final String? b64 = e['pdf_base64'] as String?;
        if (b64 == null || b64.isEmpty) {
          debugPrint('[SPLIT] Part $i: Missing pdf_base64');
          skippedParts++;
          continue;
        }

        debugPrint('[SPLIT] Part $i: base64 length = ${b64.length} chars');

        Uint8List? bytes;
        try {
          bytes = Uint8List.fromList(base64.decode(base64.normalize(b64)));
          debugPrint('[SPLIT] Part $i: Decoded ${bytes.length} bytes');
        } catch (err) {
          debugPrint('[SPLIT] Part $i: Base64 decode failed - $err');
          skippedParts++;
          continue;
        }

        if (bytes.isEmpty) {
          debugPrint('[SPLIT] Part $i: Decoded to 0 bytes');
          skippedParts++;
          continue;
        }

        final fileName =
            'split_${i + 1}_${p.basenameWithoutExtension(pdfFile.path)}.pdf';
        final file = File(p.join(tmp.path, fileName));

        try {
          await file.writeAsBytes(bytes);
        } catch (writeErr) {
          debugPrint('[SPLIT] Part $i: Write failed - $writeErr');
          skippedParts++;
          continue;
        }

        final invoiceNo = e['invoice_no'] as String?;
        final pagesDynamic = e['pages'] as List<dynamic>?;
        final pages = pagesDynamic?.map((p) => p as int).toList();
        final sizeBytes = bytes.length;

        out.add(
          SplitOut(
            file: file,
            invoiceNo: invoiceNo,
            pages: pages,
            sizeBytes: sizeBytes,
          ),
        );
      }

      debugPrint(
        '[SPLIT] Result: ${out.length} valid parts, $skippedParts skipped',
      );

      // ✅ NEW: Validate we got most parts
      if (out.isNotEmpty && out.length >= parts.length * 0.8) {
        // Got at least 80% of parts - consider success
        debugPrint(
          '[SPLIT] ✓ Successfully processed ${out.length}/${parts.length} parts',
        );
        return out;
      } else if (out.isNotEmpty) {
        // Got some but not enough
        debugPrint(
          '[SPLIT] ⚠️ Only got ${out.length}/${parts.length} parts (${(out.length / parts.length * 100).toStringAsFixed(1)}%)',
        );

        if (attempt < maxRetries - 1) {
          debugPrint('[SPLIT] Retrying to get all parts...');
          await Future.delayed(retryDelay);
          continue;
        }

        // Return partial results rather than nothing
        debugPrint('[SPLIT] Returning ${out.length} partial results');
        return out;
      } else {
        debugPrint('[SPLIT] ⚠️ Failed to extract any valid parts');

        if (attempt < maxRetries - 1) {
          await Future.delayed(retryDelay);
          continue;
        }

        return _fallbackUnsplitPdf(pdfFile);
      }
    } on SocketException catch (e) {
      debugPrint('[SPLIT] ❌ Network error: $e');

      if (attempt < maxRetries - 1) {
        debugPrint('[SPLIT] Retrying after network error...');
        await Future.delayed(retryDelay);
        continue;
      }

      return _fallbackUnsplitPdf(pdfFile);
    } on FormatException catch (e) {
      debugPrint('[SPLIT] ❌ Format error: $e');

      if (attempt < maxRetries - 1) {
        await Future.delayed(retryDelay);
        continue;
      }

      return _fallbackUnsplitPdf(pdfFile);
    } catch (e, stackTrace) {
      debugPrint('[SPLIT] ❌ Unexpected error: $e');
      debugPrint(
        '[SPLIT] Stack: ${stackTrace.toString().split('\n').take(5).join('\n')}',
      );

      if (attempt < maxRetries - 1) {
        await Future.delayed(retryDelay);
        continue;
      }

      return _fallbackUnsplitPdf(pdfFile);
    }
  }

  return _fallbackUnsplitPdf(pdfFile);
}

List<SplitOut> _fallbackUnsplitPdf(File pdfFile) {
  debugPrint('[SPLIT] ⚠️ Fallback: Returning PDF as single document');

  final sizeBytes = pdfFile.existsSync() ? pdfFile.lengthSync() : 0;

  return [
    SplitOut(file: pdfFile, invoiceNo: null, pages: null, sizeBytes: sizeBytes),
  ];
}

class PODUploadScreen extends StatefulWidget {
  const PODUploadScreen({super.key, this.stockistService});

  final SecondarySalesStockistService? stockistService;

  @override
  State<PODUploadScreen> createState() => _PODUploadScreenState();
}

class _PODUploadScreenState extends State<PODUploadScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoadingLists = false;
  bool _isUploading = false;
  bool _isRefreshing = false;
  bool _isBusy = false;
  bool _isProcessingDocuments = false;
  String _currentProcessingMessage = '';

  late TabController _tabController;
  late final SecondarySalesStockistService _stockistService;
  late final SecondarySalesStockistListController _stockistListController;

  List<_SelectItem> _allStockists = [];
  List<_SelectItem> _allChemists = [];
  _SelectItem? _selectedStockist;
  List<SecondarySalesStockistInfo> _authorizedStockists = [];
  SecondarySalesStockistInfo? _authorizedSelected;
  String? _stockistsLoadedForToken;
  DateTime _selectedStatementMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  Timer? _stockistSearchTimer;
  Timer? _hospitalSearchTimer;
  bool _isSearchingStockists = false;
  bool _isSearchingHospitals = false;
  _SelectItem? _selectedChemist;

  List<DocumentInfo> _capturedDocuments = [];

  Key _stockistKey = UniqueKey();
  Key _chemistKey = UniqueKey();

  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _stockistService = widget.stockistService ?? SecondarySalesStockistService();
    _stockistListController = SecondarySalesStockistListController(
      service: _stockistService,
    );
    _stockistListController.addListener(_onAuthorizedStockistsChanged);
    _loadLists();
  }

  int get _goodQualityCount =>
      _capturedDocuments
          .where((d) => d.isValid && (d.isGoodForExtraction ?? true))
          .length;

  int get _badQualityCount =>
      _capturedDocuments
          .where((d) => d.isValid && (d.isGoodForExtraction == false))
          .length;

  @override
  void dispose() {
    _stockistSearchTimer?.cancel();
    _hospitalSearchTimer?.cancel();
    _stockistListController.removeListener(_onAuthorizedStockistsChanged);
    _stockistListController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _updateBusyState() {
    setState(() {
      _isBusy =
          _isUploading ||
          _isLoadingLists ||
          _isRefreshing ||
          _isProcessingDocuments;
    });
  }

  Future<void> _onRefresh() async {
    if (_isBusy) return;

    setState(() {
      _isRefreshing = true;
      _updateBusyState();
    });

    try {
      setState(() {
        _selectedStockist = null;
        _selectedChemist = null;
        _authorizedSelected = null;
        _authorizedStockists = [];
        _stockistsLoadedForToken = null;
        _stockistKey = UniqueKey();
        _chemistKey = UniqueKey();
      });
      _stockistService.clear();
      _stockistListController.reset();

      await _loadLists();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Page refreshed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _updateBusyState();
        });
      }
    }
  }

  Future<void> _loadLists() async {
    if (isSecondarySalesUpload) {
      try {
        await _loadAuthorizedSecondarySalesStockists();
      } on UnauthorizedException {
        debugPrint('Stockist list load stopped: unauthorized');
      } catch (e) {
        debugPrint('Failed to load lists: $e');
        if (!mounted) return;
        setState(() {
          _authorizedStockists = _stockistListController.stockists;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load lists: $e')));
      }
      return;
    }

    if (_isLoadingLists) return;

    setState(() {
      _isLoadingLists = true;
      _updateBusyState();
    });

    try {
      final results = await Future.wait([
        _fetchSelectItems(API_STOCKISTS_URL),
        _fetchSelectItems(API_HOSPITALS_URL),
      ]);

      if (!mounted) return;
      setState(() {
        _allStockists = results[0];
        _allChemists = results[1];
      });
    } on UnauthorizedException {
      // ApiClient / AuthService already handles session expiry.
      debugPrint('Stockist list load stopped: unauthorized');
    } catch (e) {
      debugPrint('Failed to load lists: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load lists: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLists = false;
          _updateBusyState();
        });
      }
    }
  }

  void _onAuthorizedStockistsChanged() {
    _authorizedStockists = _stockistListController.stockists;
  }

  Future<void> _loadAuthorizedSecondarySalesStockists() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (_stockistsLoadedForToken != null &&
        _stockistsLoadedForToken != token) {
      _authorizedStockists = [];
      _authorizedSelected = null;
      _selectedStockist = null;
      _stockistService.clear();
      _stockistListController.reset();
    }

    try {
      await _stockistListController.refresh(authToken: token);
      if (!mounted) return;

      final stockists = _stockistListController.stockists;
      SecondarySalesStockistInfo? stillValid;
      if (_authorizedSelected != null) {
        for (final item in stockists) {
          if (item.id == _authorizedSelected!.id) {
            stillValid = item;
            break;
          }
        }
      }

      setState(() {
        _authorizedStockists = stockists;
        if (stillValid != null) {
          _authorizedSelected = stillValid;
          _selectedStockist = _SelectItem(
            id: stillValid.id.toString(),
            label: stillValid.name,
          );
        }
        _stockistsLoadedForToken = token;
      });
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() {
        _authorizedStockists = [];
        _authorizedSelected = null;
        _selectedStockist = null;
        _stockistsLoadedForToken = null;
      });
      rethrow;
    } on SecondarySalesStockistException {
      if (!mounted) return;
      setState(() {
        _authorizedStockists = _stockistListController.stockists;
        _stockistsLoadedForToken = null;
      });
    }
  }

  Future<List<_SelectItem>> _searchStockists(String query) async {
    if (isSecondarySalesUpload) {
      return filterAuthorizedStockists(_authorizedStockists, query)
          .map((s) => _SelectItem(id: s.id.toString(), label: s.name))
          .toList();
    }

    if (query.length < 3) {
      return _allStockists.take(50).toList();
    }

    setState(() {
      _isSearchingStockists = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final searchUrl = '${API_STOCKISTS_URL}?search=$query';

      final resp = await http.get(
        Uri.parse(searchUrl),
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      );

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final decoded = _safeDecode(resp.bodyBytes);
      final rawList = _unwrapToList(decoded);

      final items =
          rawList
              .map((e) => _SelectItem.fromDynamic(e))
              .where((e) => e != null)
              .cast<_SelectItem>()
              .toList();

      return items;
    } catch (e) {
      debugPrint('Stockist search error: $e');
      return _allStockists
          .where(
            (item) => item.label.toLowerCase().contains(query.toLowerCase()),
          )
          .take(50)
          .toList();
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingStockists = false;
        });
      }
    }
  }

  Future<List<_SelectItem>> _searchHospitals(String query) async {
    if (query.length < 3) {
      return _allChemists.take(50).toList();
    }

    setState(() {
      _isSearchingHospitals = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final searchUrl = '${API_HOSPITALS_URL}? search=$query';

      final resp = await http.get(
        Uri.parse(searchUrl),
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      );

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final decoded = _safeDecode(resp.bodyBytes);
      final rawList = _unwrapToList(decoded);

      final items =
          rawList
              .map((e) => _SelectItem.fromDynamic(e))
              .where((e) => e != null)
              .cast<_SelectItem>()
              .toList();

      return items;
    } catch (e) {
      debugPrint('Hospital search error: $e');
      return _allChemists
          .where(
            (item) => item.label.toLowerCase().contains(query.toLowerCase()),
          )
          .take(50)
          .toList();
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingHospitals = false;
        });
      }
    }
  }

  Future<List<_SelectItem>> _fetchSelectItems(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    final resp = await http.get(
      Uri.parse(url),
      headers: token != null ? {'Authorization': 'Bearer $token'} : null,
    );
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.body}');
    }
    final decoded = _safeDecode(resp.bodyBytes);
    final rawList = _unwrapToList(decoded);

    final items =
        rawList
            .map((e) => _SelectItem.fromDynamic(e))
            .where((e) => e != null)
            .cast<_SelectItem>()
            .toList();

    return items;
  }

  dynamic _safeDecode(Uint8List bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } catch (_) {
      try {
        return jsonDecode(String.fromCharCodes(bytes));
      } catch (_) {
        return null;
      }
    }
  }

  List<dynamic> _unwrapToList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      if (decoded.containsKey('data') && decoded['data'] is List) {
        return decoded['data'];
      }
      if (decoded.containsKey('items') && decoded['items'] is List) {
        return decoded['items'];
      }
    }
    return [];
  }

  /// ===================== DOCUMENT PROCESSING =====================

  Future<void> _showDocumentSourceDialog() async {
    if (_isBusy) return;

    showDialog(
      context: context,
      builder: (context) => SecondarySalesUploadSourceSheet(
        onCamera: _useRegularCamera,
        onDocuments: _pickDocumentFiles,
        onGallery: _pickFromGallery,
        onScanner: _scanDocument,
      ),
    );
  }

  Future<void> _scanDocument() async {
    if (_isBusy) return;

    // ── iOS Guard ────────────────────────────────────────────────────────────
    // google_mlkit_document_scanner is Android-only (requires Google Play Services).
    // On iOS we fall back to the standard camera via _useRegularCamera().
    if (!Platform.isAndroid) {
      debugPrint('[SCANNER] MLKit not available on this platform — using regular camera.');
      await _useRegularCamera();
      return;
    }
    // ── Android-only MLKit path below ────────────────────────────────────────

    setState(() {
      _isProcessingDocuments = true;
      _currentProcessingMessage = 'Initializing scanner...';
      _updateBusyState();
    });

    try {
      setState(() {
        _currentProcessingMessage = 'Preparing document scanner...';
      });

      // Initialize ML Kit Document Scanner
      // TODO [iOS]: google_mlkit_document_scanner is Android-only.
      // On iOS, _useRegularCamera() is used instead (see Platform check above).
      final options = DocumentScannerOptions(
        // documentFormat removed — not a valid parameter in google_mlkit_document_scanner ^0.4.x
        mode: ScannerMode.full,
        pageLimit: 1,
      );

      final documentScanner = DocumentScanner(options: options);

      setState(() {
        _currentProcessingMessage = 'Opening document scanner...';
      });

      // Scan document
      final DocumentScanningResult result =
          await documentScanner.scanDocument();

      final images = result.images ?? [];
      final pdfUri = result.pdf?.uri;
      if (images.isNotEmpty) {
        for (final scannedImage in images) {
          // Convert scanned image path to file
          final file = File(scannedImage);

          await _processAndAddDocumentFile(file, isFromScanner: true);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ ${images.length} document(s) scanned successfully',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (pdfUri != null && pdfUri.isNotEmpty) {
        final local = pdfUri.replaceFirst('file://', '');
        await _processAndAddDocumentFile(File(local), isFromScanner: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Document scanned successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document scan cancelled'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // Clean up
      documentScanner.close();
    } on PlatformException catch (e) {
      // ✅ FIX: Handle PlatformException specifically
      debugPrint('[CAMERA] PlatformException: ${e.code} - ${e.message}');

      // Check if user cancelled the operation
      if (e.code == 'DocumentScanner' &&
          (e.message?.toLowerCase().contains('cancel') ?? false)) {
        // User cancelled - this is normal, just show a friendly message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📷 Document scan cancelled'),
              backgroundColor: Colors.grey,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return; // Exit without showing error
      }

      // For other PlatformExceptions, check if it's ML Kit related
      final errorMessage = e.message?.toLowerCase() ?? '';
      final isMLKitError =
          e.code.toLowerCase().contains('mlkit') ||
          errorMessage.contains('not available') ||
          errorMessage.contains('initialization');

      if (isMLKitError && mounted) {
        final shouldRetry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Scanner Issue'),
                  ],
                ),
                content: Text(
                  'The document scanner encountered an issue:\n\n${e.message}\n\nWould you like to try again? ',
                  style: const TextStyle(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF450095),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
        );

        if (shouldRetry == true) {
          await Future.delayed(const Duration(milliseconds: 500));
          _scanDocument();
          return;
        }
      } else {
        // Other platform errors
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scanner error: ${e.message ?? "Unknown error"}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _scanDocument(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      // ✅ General catch for other exceptions
      debugPrint('[CAMERA] General Error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unexpected error: ${e.toString().split('\n').first}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _scanDocument(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingDocuments = false;
          _currentProcessingMessage = '';
          _updateBusyState();
        });
      }
    }
  }

  // Add this helper method for regular camera fallback
  Future<void> _useRegularCamera() async {
    if (_isBusy) return;

    setState(() {
      _isProcessingDocuments = true;
      _currentProcessingMessage = 'Opening camera...';
      _updateBusyState();
    });

    try {
      // Original camera file: no maxWidth/maxHeight and no JPEG recompress.
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        await _processAndAddDocumentFile(
          File(photo.path),
          isFromScanner: false,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Photo captured successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingDocuments = false;
          _currentProcessingMessage = '';
          _updateBusyState();
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isBusy) return;

    setState(() {
      _isProcessingDocuments = true;
      _currentProcessingMessage = 'Opening gallery...';
      _updateBusyState();
    });

    try {
      final imgs = await _imagePicker.pickMultiImage(imageQuality: 100);

      if (imgs.isNotEmpty) {
        for (int i = 0; i < imgs.length; i++) {
          await _processAndAddDocumentFile(
            File(imgs[i].path),
            isFromScanner: false,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Processing image ${i + 1}/${imgs.length}'),
                duration: const Duration(milliseconds: 400),
              ),
            );
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${imgs.length} image(s) selected'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gallery error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingDocuments = false;
          _currentProcessingMessage = '';
          _updateBusyState();
        });
      }
    }
  }

  Future<void> _pickDocumentFiles() async {
    if (_isBusy) return;

    final extensions = isSecondarySalesUpload
        ? kSecondarySalesDocumentExtensions
        : const ['pdf'];

    setState(() {
      _isProcessingDocuments = true;
      _currentProcessingMessage = isSecondarySalesUpload
          ? 'Selecting document files...'
          : 'Selecting PDF files...';
      _updateBusyState();
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: isSecondarySalesUpload
            ? kSecondarySalesDocumentPickerAllowsMultiple
            : true,
      );

      if (result != null && result.files.isNotEmpty) {
        int added = 0;
        for (final f in result.files) {
          if (f.path == null) continue;

          await _processAndAddDocumentFile(
            File(f.path!),
            isFromScanner: true,
            pickerExtension: f.extension,
          );

          added++;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Added file $added/${result.files.length}',
                ),
                duration: const Duration(milliseconds: 400),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pick file error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingDocuments = false;
          _currentProcessingMessage = '';
          _updateBusyState();
        });
      }
    }
  }

  Future<void> _processAndAddDocumentFile(
    File originalFile, {
    required bool isFromScanner,
    String? pickerExtension,
  }) async {
    setState(() {
      _isProcessingDocuments = true;
      _currentProcessingMessage = 'Processing file...';
      _updateBusyState();
    });

    try {
      final pathExtension = p.extension(originalFile.path).toLowerCase();
      final resolvedExtension = isSecondarySalesUpload
          ? secondarySalesResolvedExtension(
              pathExtension: pathExtension,
              pickerExtension: pickerExtension,
            )
          : pathExtension.replaceFirst('.', '');
      final dottedExtension = '.$resolvedExtension';
      final allowed = isSecondarySalesUpload
          ? kSecondarySalesDocumentExtensions.map((e) => '.$e').toList()
          : const [
              '.pdf',
              '.jpg',
              '.jpeg',
              '.png',
              '.gif',
              '.bmp',
              '.webp',
            ];

      if (allowed.contains(dottedExtension)) {
        var displayName = p.basename(originalFile.path);
        if (isSecondarySalesUpload &&
            secondarySalesNormalizedExtension(p.extension(displayName)) !=
                resolvedExtension &&
            resolvedExtension.isNotEmpty) {
          displayName = '$displayName.$resolvedExtension';
        }
        setState(() {
          _currentProcessingMessage = 'Adding $displayName...';
        });

        final newDoc = DocumentInfo(
          file: originalFile,
          displayName: displayName,
          isValid: true,
          qrData: null,
          qrStatus: QRProcessingStatus.completed,
          originalRawFile: null,
          isGoodForExtraction: true,
          ocrConfidence: 100.0,
          qualityMessage: 'File - Backend will process',
        );

        setState(() {
          _capturedDocuments.add(newDoc);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ File added: $displayName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unsupported file format: $dottedExtension'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      _scheduleScrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isProcessingDocuments = false;
        _currentProcessingMessage = '';
        _updateBusyState();
      });
    }
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// ===================== UPLOAD =====================

  Future<void> _uploadCaptured() async {
    if (_isBusy) return;

    final validDocs =
        _capturedDocuments
            .where((d) => d.isValid && (d.isGoodForExtraction ?? true))
            .toList();

    if (validDocs.isEmpty) {
      final badQualityCount =
          _capturedDocuments
              .where((d) => d.isValid && (d.isGoodForExtraction == false))
              .length;

      if (badQualityCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No good quality documents to upload. $badQualityCount file(s) have low quality.  Please reupload with better quality.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid documents to upload')),
        );
      }
      return;
    }

    if (_selectedStockist == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select Stockist for Secondary Sales.')));
      return;
    }

    final stockistIdStr = _selectedStockist!.id.trim();

    if (stockistIdStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stockist is empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final stockistId = int.tryParse(stockistIdStr);

    if (stockistId == null || stockistId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid Stockist ID: "$stockistIdStr"'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _performUpload(validDocs);
  }

  Future<void> _performUpload(List<DocumentInfo> validDocs) async {
    setState(() {
      _isUploading = true;
      _updateBusyState();
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final stockistId = int.parse(_selectedStockist!.id.trim());

      const int maxRetries = 3;
      const Duration connectTimeout = Duration(minutes: 3);
      const Duration responseTimeout = Duration(minutes: 5);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sending files to server...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // ──────────────────────────────────────────────────────────────────────
      // NEW UPLOAD ENDPOINT
      // POST ${API_SECONDARY_SALES_UPLOAD_URL}
      // (https://himalaya.globalspace.in/api/secondary-sales/upload)
      // Accepts: files[], stockist_id, statement_month, company_name, remarks
      // ──────────────────────────────────────────────────────────────────────

      // [OLD — Case A / Case B] The split-file-processor pipeline selected the
      // endpoint based on whether the batch contained non-PDF files.
      // Kept here for reference — no longer used by _performUpload.
      //
      // final bool hasNonPdf = validDocs.any(
      //   (d) => p.extension(d.displayName).toLowerCase() != '.pdf',
      // );
      // final String uploadUrl = hasNonPdf
      //     ? Multi_Api_POD_UPLOAD_URL_IMAGES   // Case B — images allowed
      //     : Multi_Api_POD_UPLOAD_URL;          // Case A — PDF only
      // debugPrint('[UPLOAD] API Endpoint: $uploadUrl (hasNonPdf=$hasNonPdf)');

      // Himalaya: Secondary Sales API. Other clients keep the Invoice POD APIs.
      final bool secondarySales = isSecondarySalesUpload;
      final String uploadUrl;
      if (secondarySales) {
        uploadUrl = API_SECONDARY_SALES_UPLOAD_URL;
      } else {
        final bool hasNonPdf = validDocs.any(
          (d) => p.extension(d.displayName).toLowerCase() != '.pdf',
        );
        uploadUrl = hasNonPdf
            ? Multi_Api_POD_UPLOAD_URL_IMAGES
            : Multi_Api_POD_UPLOAD_URL;
      }
      debugPrint(
        '[UPLOAD] API Endpoint: $uploadUrl (uploadType=$POD_CLIENT_UPLOAD_TYPE)',
      );

      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          final uri = Uri.parse(uploadUrl);
          final req = http.MultipartRequest('POST', uri);

          // ── Attach files as files[] multipart array ──────────────────────
          for (final d in validDocs) {
            final filename = secondarySales &&
                    isSecondarySalesDocumentExtension(
                      p.extension(d.displayName),
                    )
                ? d.displayName
                : p.basename(d.file.path);
            final contentType = _inferContentTypeFile(
              d.file,
              displayName: d.displayName,
            );

            req.files.add(
              await http.MultipartFile.fromPath(
                'files[]',
                d.file.path,
                filename: filename,
                contentType: contentType,
              ),
            );

            debugPrint(
              '[UPLOAD] Attached file: $filename (${contentType.mimeType})',
            );
          }

          // ── Auth header ────────────────────────────────────────────────────
          if (token != null) {
            req.headers['Authorization'] = 'Bearer $token';
          }

          // Force fresh connection to reduce stale keep-alive socket aborts.
          req.headers['Connection'] = 'close';

          if (secondarySales) {
            // Secondary Sales — POST /api/secondary-sales/upload
            req.fields.addAll(
              buildSecondarySalesUploadFields(
                stockistId: stockistId,
                selectedMonth: _selectedStatementMonth,
              ),
            );
            debugPrint(
              '[UPLOAD] Fields: stockist_id=$stockistId, statement_month=${req.fields['statement_month']}',
            );
          } else {
            // Invoice POD — existing split-file-processor / allow-images fields.
            req.fields['stockistId'] = stockistId.toString();
            req.fields['file_einvoice_sequence'] = _buildPhpStyleJson(validDocs);
            req.fields['doc_type'] = 'POD';
            req.fields['document_count'] = validDocs.length.toString();
            req.fields['multi_page'] = (validDocs.length > 1).toString();
            req.fields['ocr_enhanced'] = 'true';
            req.fields['dpi'] = '300';
          }

          debugPrint(
            '[UPLOAD] Attempt ${attempt + 1}/$maxRetries: sending ${validDocs.length} file(s)',
          );
          debugPrint(
            '[UPLOAD] Files: ${validDocs.map((d) => d.displayName).join(', ')}',
          );

          final resp = await req.send().timeout(connectTimeout);

          final responseBody = await resp.stream.bytesToString().timeout(
            responseTimeout,
          );

          if (secondarySales && resp.statusCode == 403) {
            debugPrint('[UPLOAD] Forbidden for selected stockist: $responseBody');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(secondarySalesUploadForbiddenMessage(responseBody)),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          if (secondarySales && resp.statusCode == 422) {
            debugPrint('[UPLOAD] Laravel rejected statement month: $responseBody');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    secondarySalesUploadUnprocessableMessage(responseBody),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          if (secondarySalesShouldNavigateToStatus(resp.statusCode)) {
            await _onUploadAccepted(
              responseBody: responseBody,
              validDocs: validDocs,
              statusCode: resp.statusCode,
            );
            return;
          }

          if (_isRetryableUploadStatus(resp.statusCode) &&
              attempt < maxRetries - 1) {
            final wait = _uploadRetryDelay(attempt);
            debugPrint(
              '[UPLOAD] Retryable HTTP ${resp.statusCode}. Retrying in ${wait.inSeconds}s',
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Server is busy (HTTP ${resp.statusCode}). Retrying ${attempt + 2}/$maxRetries...',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            }

            await Future.delayed(wait);
            continue;
          }

          debugPrint(
            'Upload failed: ${resp.statusCode} ${responseBody.isNotEmpty ? "- $responseBody" : ""}',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_uploadHttpErrorMessage(resp.statusCode, responseBody)),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        } catch (e) {
          final canRetry =
              _isRetryableUploadError(e) && attempt < maxRetries - 1;
          debugPrint('[UPLOAD] Attempt ${attempt + 1} failed: $e');

          if (canRetry) {
            final wait = _uploadRetryDelay(attempt);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Network issue while uploading. Retrying ${attempt + 2}/$maxRetries...',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            }

            await Future.delayed(wait);
            continue;
          }

          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _updateBusyState();
        });
      }
    }
  }

  Future<void> _onUploadAccepted({
    required String responseBody,
    required List<DocumentInfo> validDocs,
    required int statusCode,
  }) async {
    Map<String, dynamic>? responseData;
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        responseData = decoded;
      }
    } catch (e) {
      debugPrint('[UPLOAD] Response parse error: $e');
    }

    if (responseData != null && responseData['success'] == false) {
      debugPrint('Upload rejected by server: $responseBody');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseData['message']?.toString() ??
                  'Upload failed: $statusCode',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final fileNames = validDocs.map((d) => d.displayName).toList();
    final record = responseData == null
        ? null
        : UploadRecord.tryFromUploadResponse(
            response: responseData,
            uploadType: POD_CLIENT_UPLOAD_TYPE,
            fileNames: fileNames,
            totalFiles: validDocs.length,
          );

    if (record != null) {
      await UploadRecordStore.instance.upsert(record);
      if (!mounted) return;
      setState(() {
        _capturedDocuments.clear();
      });
      // Push (do not replace) so the user can go back and start another upload
      // while this batch keeps processing on the server.
      Navigator.pushNamed(
        context,
        PodRoutes.uploadStatus,
        arguments: {
          'uploadData': responseData,
          'totalFiles': validDocs.length,
          'batchId': record.batchId,
          'fileNames': fileNames,
          'uploadType': record.uploadType,
        },
      );
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploaded ${validDocs.length} file(s). Backend processing…',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
    setState(() {
      _capturedDocuments.clear();
    });
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _uploadHttpErrorMessage(int statusCode, String body) {
    switch (statusCode) {
      case 401:
        return 'Session expired. Please log in again.';
      case 403:
        if (isSecondarySalesUpload) {
          return secondarySalesUploadForbiddenMessage(body);
        }
        return 'You do not have permission to upload.';
      case 413:
        return 'File is too large to upload.';
      case 422:
        if (isSecondarySalesUpload) {
          return secondarySalesUploadUnprocessableMessage(body);
        }
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map && decoded['message'] != null) {
            return decoded['message'].toString();
          }
        } catch (_) {}
        return 'The upload was rejected. Please check the file and try again.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return 'Upload failed: $statusCode${body.isNotEmpty ? ' - $body' : ''}';
    }
  }

  Duration _uploadRetryDelay(int attempt) {
    const baseSeconds = 2;
    final seconds = baseSeconds * (attempt + 1);
    return Duration(seconds: seconds);
  }

  bool _isRetryableUploadStatus(int statusCode) {
    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }

  bool _isRetryableUploadError(Object error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;

    if (error is http.ClientException) {
      final message = error.message.toLowerCase();
      return message.contains('socketexception') ||
          message.contains('connection abort') ||
          message.contains('connection reset') ||
          message.contains('timed out') ||
          message.contains('connection closed');
    }

    return false;
  }

  MediaType _inferContentTypeFile(File file, {String? displayName}) {
    final ext = p.extension(file.path).toLowerCase();
    if (isSecondarySalesUpload) {
      final resolved = secondarySalesResolvedExtension(
        pathExtension: ext,
        pickerExtension:
            displayName != null ? p.extension(displayName) : null,
      );
      return secondarySalesContentTypeForExtension(resolved);
    }
    switch (ext) {
      case '.pdf':
        return MediaType('application', 'pdf');
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  String _buildPhpStyleJson(List<DocumentInfo> docs) {
    final entries = <Map<String, dynamic>>[];
    for (int i = 0; i < docs.length; i++) {
      final doc = docs[i];
      final name = doc.displayName;
      entries.add({
        'index': i,
        'filename': name,
        'qr_data': doc.qrData,
        'is_valid': doc.isValid,
      });
    }
    return jsonEncode(entries);
  }

  void _clearAllDocuments() {
    if (_isBusy) return;
    setState(() {
      _capturedDocuments.clear();
    });
  }

  void _showClearAllDialog() {
    if (_isBusy) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Documents'),
            content: Text(
              'Are you sure you want to remove all ${_capturedDocuments.length} documents?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _clearAllDocuments();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All documents cleared'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  /// ===================== UI BUILD =====================

  @override
  Widget build(BuildContext context) {
    final showTopLoader = _isLoadingLists || _isProcessingDocuments;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Secondary Sales Documents Upload',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            Text(
              'Upload secondary sales documents',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF450095),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back',
          onPressed: () {
            Navigator.maybePop(context);
          },
        ),
      ),
      body: SafeArea(
        // ✅ ADD THIS
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color(0xFF450095),
          backgroundColor: Colors.white,
          strokeWidth: 2.5,
          displacement: 40.0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (showTopLoader || _isRefreshing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            const LinearProgressIndicator(),
                            const SizedBox(height: 8),
                            Text(
                              _isRefreshing
                                  ? 'Refreshing page...'
                                  : _isProcessingDocuments
                                  ? _currentProcessingMessage
                                  : 'Loading lists...',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isSecondarySalesUpload)
                      _buildSectionCard(
                        icon: Icons.calendar_month_rounded,
                        title: 'Statement Month',
                        subtitle: 'Upload statements for this month only',
                        child: SecondarySalesMonthBar(
                          selectedMonth: _selectedStatementMonth,
                          onMonthChanged: (month) {
                            setState(() {
                              _selectedStatementMonth =
                                  DateTime(month.year, month.month);
                            });
                          },
                        ),
                      ),
                    _buildSectionCard(
                      icon: Icons.store_mall_directory,
                      title: 'Stockist',
                      subtitle: 'Select Stockist',
                      child: isSecondarySalesUpload
                          ? SecondarySalesStockistPicker(
                              controller: _stockistListController,
                              selected: _authorizedSelected,
                              onSelected: (stockist) {
                                setState(() {
                                  _authorizedSelected = stockist;
                                  _selectedStockist = _SelectItem(
                                    id: stockist.id.toString(),
                                    label: stockist.name,
                                  );
                                });
                              },
                              onClear: () {
                                setState(() {
                                  _authorizedSelected = null;
                                  _selectedStockist = null;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Stockist selection cleared'),
                                    duration: Duration(seconds: 1),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              },
                            )
                          : _customAutocomplete(
                        key: _stockistKey,
                        options: _allStockists,
                        selected: _selectedStockist,
                        label: 'Search Stockist',
                        onSelected:
                            (opt) => setState(() => _selectedStockist = opt),
                        onClear: () {
                          setState(() {
                            _selectedStockist = null;
                            _stockistKey = UniqueKey();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Stockist selection cleared'),
                              duration: Duration(seconds: 1),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                        isStockist: true,
                      ),
                    ),
                    _buildSectionCard(
                      icon: Icons.add_a_photo,
                      title: 'Upload Files',
                      subtitle: 'Documents sent for processing',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed:
                                _isBusy ? null : _showDocumentSourceDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Upload Files'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF450095),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                          if (isSecondarySalesUpload) ...[
                            const SizedBox(height: 8),
                            Text(
                              kSecondarySalesSupportedFormatsLabel,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_capturedDocuments.isNotEmpty) ...[
                      _buildSectionCard(
                        icon: Icons.collections,
                        title: 'Documents',
                        subtitle: 'View all uploaded files',
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                tabs: [
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'All Documents (${_capturedDocuments.where((d) => d.isValid).length})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...(_capturedDocuments
                                    .where((d) => d.isValid)
                                    .toList()
                                    .isEmpty
                                ? [
                                  SizedBox(
                                    height: 200,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.folder_open,
                                            size: 64,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No documents yet',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ]
                                : _capturedDocuments
                                    .where((d) => d.isValid)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                      final doc = entry.value;
                                      final docIndex = _capturedDocuments
                                          .indexOf(doc);
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: _buildDocumentCard(
                                          doc,
                                          docIndex,
                                        ),
                                      );
                                    })
                                    .toList()),
                          ],
                        ),
                      ),
                      _buildSectionCard(
                        icon: Icons.info,
                        title: 'Summary',
                        subtitle:
                            'Total documents: ${_capturedDocuments.length}',
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    'Total',
                                    _capturedDocuments.length,
                                    Colors.blue,
                                  ),
                                  _buildStatItem(
                                    'Good Quality',
                                    _goodQualityCount,
                                    Colors.green,
                                  ),
                                  _buildStatItem(
                                    'Low Quality',
                                    _badQualityCount,
                                    Colors.red,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isBusy ? null : _showClearAllDialog,
                                icon: const Icon(Icons.clear_all, size: 18),
                                label: const Text('Clear All Documents'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade600,
                                  side: BorderSide(color: Colors.red.shade300),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isBusy ? null : _uploadCaptured,
                        icon:
                            _isBusy
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Icon(Icons.cloud_upload),
                        label: Text(
                          _isBusy
                              ? (_isUploading
                                  ? 'Uploading...'
                                  : _isProcessingDocuments
                                  ? 'Processing Documents...'
                                  : 'Loading.. .')
                              : 'Upload $_goodQualityCount Secondary sales Documents',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isBusy ? Colors.grey : const Color(0xFF450095),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    // ✅ ADD BOTTOM PADDING FOR SAFE AREA
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ), // ✅ CLOSE SafeArea HERE
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF450095), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _customAutocomplete({
    Key? key,
    required List<_SelectItem> options,
    required _SelectItem? selected,
    required String label,
    required Function(_SelectItem) onSelected,
    required VoidCallback onClear,
    required bool isStockist,
  }) {
    return Autocomplete<_SelectItem>(
      key: key,
      displayStringForOption: (o) => o.label,
      optionsBuilder: (TextEditingValue tv) async {
        final text = tv.text.trim();

        if (text.isEmpty) {
          return options.take(50);
        }
        if (text.length < 3) {
          return options
              .where((o) => o.label.toLowerCase().contains(text.toLowerCase()))
              .take(50);
        }

        if (isStockist) {
          _stockistSearchTimer?.cancel();
        } else {
          _hospitalSearchTimer?.cancel();
        }

        return options
            .where((o) => o.label.toLowerCase().contains(text.toLowerCase()))
            .take(50);
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            hintText: selected?.label ?? 'Type to search...',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isStockist && _isSearchingStockists)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (!isStockist && _isSearchingHospitals)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (selected != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: onClear,
                    tooltip: 'Clear selection',
                    color: Colors.red.shade600,
                  ),
              ],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF450095)),
            ),
          ),
          onFieldSubmitted: (value) => onFieldSubmitted(),
          readOnly: selected != null,
          onChanged: (value) async {
            if (value.length >= 3) {
              if (isStockist) {
                _stockistSearchTimer?.cancel();
                _stockistSearchTimer = Timer(
                  const Duration(milliseconds: 300),
                  () async {
                    final results = await _searchStockists(value);
                    if (mounted) {
                      setState(() {
                        _allStockists = results;
                      });
                    }
                  },
                );
              } else {
                _hospitalSearchTimer?.cancel();
                _hospitalSearchTimer = Timer(
                  const Duration(milliseconds: 300),
                  () async {
                    final results = await _searchHospitals(value);
                    if (mounted) {
                      setState(() {
                        _allChemists = results;
                      });
                    }
                  },
                );
              }
            }
          },
        );
      },
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildDocumentCard(DocumentInfo doc, int index) {
    final fileSize = _getDocSizeString(doc);
    final isGoodQuality = doc.isGoodForExtraction ?? true;
    Color borderColor =
        doc.isValid ? (isGoodQuality ? Colors.green : Colors.red) : Colors.grey;
    double borderWidth = 2;

    return Dismissible(
      key: Key('doc_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete, color: Colors.red, size: 24),
      ),
      confirmDismiss: (direction) async {
        return await _showRemoveDialog(doc.displayName);
      },
      onDismissed: (direction) {
        _removeDocument(index);
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
        child: InkWell(
          onTap: () => _previewDocument(doc),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _documentListIcon(doc),
                      color: borderColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doc.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _removeDocument(index),
                      icon: const Icon(Icons.close, size: 18),
                      color: Colors.red.shade600,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Size: $fileSize',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      doc.isGoodForExtraction == false
                          ? Icons.error
                          : Icons.check_circle,
                      size: 14,
                      color:
                          doc.isGoodForExtraction == false
                              ? Colors.red
                              : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      doc.isGoodForExtraction == false
                          ? 'Low Quality (${doc.ocrConfidence?.toStringAsFixed(1) ?? "N/A"}%)'
                          : 'Good Quality',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            doc.isGoodForExtraction == false
                                ? Colors.red
                                : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDocSizeString(DocumentInfo doc) {
    try {
      final bytes = doc.file.lengthSync();
      if (bytes == 0) return 'Unknown';
      if (bytes < 1024) return '${bytes}B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    } catch (_) {
      return 'Unknown';
    }
  }

  Future<bool> _showRemoveDialog(String fileName) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Remove Document'),
                content: Text('Are you sure you want to remove "$fileName"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  IconData _documentListIcon(DocumentInfo doc) {
    if (isSecondarySalesExcelExtension(p.extension(doc.displayName))) {
      return Icons.table_chart;
    }
    return Icons.description;
  }

  void _previewDocument(DocumentInfo doc) {
    final extension = p.extension(doc.displayName).toLowerCase();
    if (isSecondarySalesExcelExtension(extension) ||
        const ['.txt', '.doc', '.docx', '.zip', '.html', '.htm']
            .contains(extension)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preview is not available for this file type'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }
    final isPdf = extension == '.pdf';
    final isImage = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
    ].contains(extension);

    if (isImage) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => Scaffold(
                appBar: AppBar(
                  title: Text(doc.displayName),
                  backgroundColor: const Color(0xFF450095),
                  foregroundColor: Colors.white,
                ),
                body: InteractiveViewer(
                  child: Center(child: Image.file(doc.file)),
                ),
              ),
        ),
      );
      return;
    }

    if (isPdf) {
      // Navigate to PDF preview with file
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  PdfPreviewScreen(pdfFile: doc.file, title: doc.displayName),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unsupported file format: $extension'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _removeDocument(int index) {
    if (_isBusy) return;
    setState(() {
      _capturedDocuments.removeAt(index);
    });
  }
}

/// ===================== DATA MODELS =====================

enum QRProcessingStatus { notStarted, processing, completed, failed }

class DocumentInfo {
  final File file; // Always required
  final String displayName;
  final bool isValid;
  final Map<String, dynamic>? qrData;
  final QRProcessingStatus qrStatus;
  final String? errorMessage;
  final File? originalRawFile;
  final bool? isGoodForExtraction;
  final double? ocrConfidence;
  final String? qualityMessage;

  DocumentInfo({
    required this.file,
    required this.displayName,
    required this.isValid,
    this.qrData,
    this.qrStatus = QRProcessingStatus.notStarted,
    this.errorMessage,
    this.originalRawFile,
    this.isGoodForExtraction,
    this.ocrConfidence,
    this.qualityMessage,
  });

  DocumentInfo copyWith({
    File? file,
    String? displayName,
    bool? isValid,
    Map<String, dynamic>? qrData,
    QRProcessingStatus? qrStatus,
    String? errorMessage,
    File? originalRawFile,
    bool? isGoodForExtraction,
    double? ocrConfidence,
    String? qualityMessage,
  }) {
    return DocumentInfo(
      file: file ?? this.file,
      displayName: displayName ?? this.displayName,
      isValid: isValid ?? this.isValid,
      qrData: qrData ?? this.qrData,
      qrStatus: qrStatus ?? this.qrStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      originalRawFile: originalRawFile ?? this.originalRawFile,
      isGoodForExtraction: isGoodForExtraction ?? this.isGoodForExtraction,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      qualityMessage: qualityMessage ?? this.qualityMessage,
    );
  }
}

class _SelectItem {
  final String id;
  final String label;
  _SelectItem({required this.id, required this.label});

  static _SelectItem? fromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is String) return _SelectItem(id: value, label: value);
    if (value is Map) {
      final id = _pickId(value, const [
        'id',
        'ID',
        'stockistId',
        'hospitalId',
        'podId',
      ]);
      final label = _pickString(value, const [
        'name',
        'Name',
        'title',
        'Title',
        'label',
        'Label',
      ]);
      if (id != null && label != null) return _SelectItem(id: id, label: label);
      if (id != null) return _SelectItem(id: id, label: id);
      if (label != null) return _SelectItem(id: label, label: label);
    }
    return null;
  }

  static String? _pickString(Map m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  static String? _pickId(Map m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
      if (v is int) return v.toString();
    }
    return null;
  }
}
