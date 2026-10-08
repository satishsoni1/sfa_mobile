import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/config/secondary_sales_multi_page_upload.dart';
import 'package:zforce/features/pod/config/secondary_sales_upload_files.dart';
import 'package:zforce/features/pod/models/secondary_sales_multi_page_upload_models.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';

class SecondarySalesMultiPageUploadException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  const SecondarySalesMultiPageUploadException(
    this.message, [
    this.statusCode,
    this.responseBody,
  ]);

  @override
  String toString() => message;
}

typedef MultiPageUploadProgress = void Function({
  required double overallProgress,
  required int currentPage,
  required int totalPages,
});

/// API layer for POST /secondary-sales/upload-multiple.
/// Sends individual page images as files[] — never merges into a PDF.
class SecondarySalesMultiPageUploadService {
  SecondarySalesMultiPageUploadService({
    Uuid? uuid,
    http.Client? httpClient,
  })  : _uuid = uuid ?? const Uuid(),
        _httpClient = httpClient;

  final Uuid _uuid;
  final http.Client? _httpClient;

  static const int minPages = kSecondarySalesMultiPageMinPages;
  static const int maxPages = kSecondarySalesMultiPageMaxPages;

  /// Validates selection before upload. Returns null when valid.
  String? validateBeforeUpload({
    required int? stockistId,
    required String? month,
    required List<File> files,
  }) {
    if (stockistId == null || stockistId <= 0) {
      return kSecondarySalesMultiPageMissingStockistMessage;
    }
    if (month == null || month.trim().isEmpty) {
      return kSecondarySalesMultiPageMissingMonthMessage;
    }
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(month.trim())) {
      return kSecondarySalesMultiPageMissingMonthMessage;
    }
    if (files.length < minPages) {
      return kSecondarySalesMultiPageEmptyPagesMessage;
    }
    if (files.length > maxPages) {
      return kSecondarySalesMultiPageMaxPagesMessage;
    }
    for (final file in files) {
      if (!file.existsSync()) {
        return 'One or more pages could not be read. Please retake and try again.';
      }
      final length = file.lengthSync();
      if (length <= 0) {
        return 'One or more pages could not be read. Please retake and try again.';
      }
      if (length > kSecondarySalesMaxUploadBytes) {
        return kSecondarySalesMultiPageImagesTooLargeMessage;
      }
      final ext = secondarySalesNormalizedExtension(p.extension(file.path));
      if (ext != 'jpg' && ext != 'jpeg' && ext != 'png') {
        return 'Every page must be a valid image (JPG or PNG).';
      }
    }
    return null;
  }

  String newClientUploadId() => _uuid.v4();

  /// Multipart field map for upload-multiple (testable without network).
  static Map<String, String> buildMultipartFields({
    required int stockistId,
    required String month,
    required String clientUploadId,
    String? notes,
    int? onBehalfOfEmployeeId,
  }) {
    return {
      'stockist_id': stockistId.toString(),
      'month': month.trim(),
      'is_multi_page': 'true',
      'client_upload_id': clientUploadId,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (onBehalfOfEmployeeId != null && onBehalfOfEmployeeId > 0)
        'on_behalf_of_employee_id': onBehalfOfEmployeeId.toString(),
    };
  }

  /// Ordered page filenames attached as files[] in page order.
  static List<String> orderedPageFilenames(List<File> files) {
    return List.generate(files.length, (i) {
      final ext = secondarySalesNormalizedExtension(p.extension(files[i].path));
      final safeExt = (ext == 'png') ? 'png' : 'jpg';
      return 'page_${i + 1}.$safeExt';
    });
  }

  /// Uploads individual page images to POST /secondary-sales/upload-multiple.
  Future<SecondarySalesMultiPageUploadResponse> uploadMultipleStockStatement({
    required int stockistId,
    required String month,
    required List<File> files,
    required String clientUploadId,
    String? notes,
    int? onBehalfOfEmployeeId,
    MultiPageUploadProgress? onProgress,
  }) async {
    final validationError = validateBeforeUpload(
      stockistId: stockistId,
      month: month,
      files: files,
    );
    if (validationError != null) {
      throw SecondarySalesMultiPageUploadException(validationError);
    }
    if (clientUploadId.trim().isEmpty) {
      throw const SecondarySalesMultiPageUploadException(
        'Upload session is invalid. Please try again.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null || token.isEmpty) {
      throw const SecondarySalesMultiPageUploadException(
        'Your session has expired. Please login again.',
        401,
      );
    }

    final uploadId = clientUploadId.trim();
    final fields = buildMultipartFields(
      stockistId: stockistId,
      month: month,
      clientUploadId: uploadId,
      notes: notes,
      onBehalfOfEmployeeId: onBehalfOfEmployeeId,
    );
    final filenames = orderedPageFilenames(files);
    final totalPages = files.length;

    debugPrint(
      '[SS_MULTI_PAGE] POST $API_SECONDARY_SALES_UPLOAD_MULTIPLE_URL '
      'files=$totalPages is_multi_page=true '
      'stockist_id=${fields['stockist_id']} month=${fields['month']} '
      'client_upload_id=$uploadId',
    );

    final client = _httpClient ?? http.Client();
    final ownsClient = _httpClient == null;
    try {
      final uri = Uri.parse(API_SECONDARY_SALES_UPLOAD_MULTIPLE_URL);
      final req = http.MultipartRequest('POST', uri);
      req.headers['Authorization'] = 'Bearer $token';
      req.headers['Accept'] = 'application/json';
      req.headers['Connection'] = 'close';
      req.fields.addAll(fields);

      for (var i = 0; i < files.length; i++) {
        final filename = filenames[i];
        final isPng = filename.toLowerCase().endsWith('.png');
        req.files.add(
          await http.MultipartFile.fromPath(
            'files[]',
            files[i].path,
            filename: filename,
            contentType: MediaType('image', isPng ? 'png' : 'jpeg'),
          ),
        );
        onProgress?.call(
          overallProgress: ((i + 1) / (totalPages + 1)).clamp(0.0, 1.0),
          currentPage: i + 1,
          totalPages: totalPages,
        );
      }

      final streamed = await client
          .send(req)
          .timeout(const Duration(minutes: 3));
      final responseBody = await streamed.stream
          .bytesToString()
          .timeout(const Duration(minutes: 3));
      final status = streamed.statusCode;

      onProgress?.call(
        overallProgress: 1,
        currentPage: totalPages,
        totalPages: totalPages,
      );

      debugPrint(
        '[SS_MULTI_PAGE] status=$status body=${_safeBodyForLog(responseBody)}',
      );

      return _parseUploadHttpResponse(
        status: status,
        body: responseBody,
        stockistId: stockistId,
        month: month.trim(),
        pageCount: totalPages,
        clientUploadId: uploadId,
      );
    } on SecondarySalesMultiPageUploadException {
      rethrow;
    } on SocketException {
      throw const SecondarySalesMultiPageUploadException(
        kSecondarySalesMultiPageUploadInterruptedMessage,
      );
    } on http.ClientException {
      throw const SecondarySalesMultiPageUploadException(
        kSecondarySalesMultiPageUploadInterruptedMessage,
      );
    } catch (e) {
      if (e is SecondarySalesMultiPageUploadException) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout')) {
        throw const SecondarySalesMultiPageUploadException(
          kSecondarySalesMultiPageUploadInterruptedMessage,
        );
      }
      throw const SecondarySalesMultiPageUploadException(
        kSecondarySalesMultiPageServerErrorMessage,
      );
    } finally {
      if (ownsClient) client.close();
    }
  }

  SecondarySalesMultiPageUploadResponse _parseUploadHttpResponse({
    required int status,
    required String body,
    required int stockistId,
    required String month,
    required int pageCount,
    required String clientUploadId,
  }) {
    if (status == 401) {
      throw SecondarySalesMultiPageUploadException(
        'Your session has expired. Please login again.',
        401,
        body,
      );
    }
    if (status == 403) {
      throw SecondarySalesMultiPageUploadException(
        secondarySalesUploadForbiddenMessage(body),
        403,
        body,
      );
    }
    if (status == 413) {
      throw SecondarySalesMultiPageUploadException(
        kSecondarySalesMultiPageImagesTooLargeMessage,
        413,
        body,
      );
    }
    if (status == 422) {
      final message = secondarySalesFormatLaravelValidationMessage(body) ??
          'Upload validation failed. Please check the pages, stockist, and month.';
      throw SecondarySalesMultiPageUploadException(message, 422, body);
    }
    if (status == 429) {
      throw SecondarySalesMultiPageUploadException(
        'Too many upload attempts. Please wait and try again.',
        429,
        body,
      );
    }
    if (status == 400) {
      final message = secondarySalesFormatLaravelValidationMessage(body) ??
          kSecondarySalesMultiPageServerErrorMessage;
      throw SecondarySalesMultiPageUploadException(message, 400, body);
    }
    if (status == 500 || status == 502 || status == 503 || status == 504) {
      throw SecondarySalesMultiPageUploadException(
        kSecondarySalesMultiPageServerErrorMessage,
        status,
        body,
      );
    }
    // Accept 200 / 201 / 202.
    if (!secondarySalesShouldNavigateToStatus(status)) {
      final message = secondarySalesFormatLaravelValidationMessage(body) ??
          kSecondarySalesMultiPageUploadInterruptedMessage;
      throw SecondarySalesMultiPageUploadException(message, status, body);
    }

    Map<String, dynamic>? raw;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        raw = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      raw = null;
    }
    if (raw == null) {
      throw SecondarySalesMultiPageUploadException(
        'Invalid response from server.',
        status,
        body,
      );
    }

    final parsed = SecondarySalesMultiPageUploadResponse.fromJson(raw);
    final batchId = parsed.batchId;
    if (batchId == null) {
      throw SecondarySalesMultiPageUploadException(
        parsed.message.isNotEmpty
            ? parsed.message
            : 'Upload failed. Batch was not created.',
        status,
        body,
      );
    }
    return SecondarySalesMultiPageUploadResponse(
      success: true,
      message: parsed.message.isNotEmpty
          ? parsed.message
          : '$pageCount pages uploaded successfully. They will be processed as one stock statement.',
      instruction: parsed.instruction,
      batchId: batchId,
      stockistId: parsed.stockistId ?? stockistId,
      month: parsed.month ?? month,
      totalPages: parsed.totalPages > 0 ? parsed.totalPages : pageCount,
      status: parsed.status.isNotEmpty ? parsed.status : 'queued',
      clientUploadId: parsed.clientUploadId ?? clientUploadId,
      pages: parsed.pages,
    );
  }

  String _safeBodyForLog(String body) {
    if (body.length <= 2000) return body;
    return '${body.substring(0, 2000)}…';
  }
}
