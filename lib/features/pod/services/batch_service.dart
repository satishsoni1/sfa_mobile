import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/models/batch_model.dart';

class BatchDateUpdateException implements Exception {
  final String message;
  final int? statusCode;

  const BatchDateUpdateException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class BatchService {
  final ApiClient _apiClient = ApiClient();

  Future<BatchListResponse> fetchBatches({int page = 1}) async {
    final uri = Uri.parse('${API_BATCHES_URL}?page=$page');
    final http.Response response = await _apiClient.get(uri);
    print('Batches response: ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load batches (${response.statusCode})');
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected Map');
      }
      return BatchListResponse.fromJson(decoded);
    } catch (e) {
      print('Error parsing batches response: $e');
      print('Response body: ${response.body}');
      rethrow;
    }
  }

  Future<Batch> fetchBatchById(int batchId) async {
    final uri = Uri.parse('$API_BATCHES_URL/$batchId');
    final http.Response response = await _apiClient.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load batch details (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    // Handle both single object and wrapped in data
    final batchData = decoded['data'] is Map
        ? Map<String, dynamic>.from(decoded['data'] as Map)
        : decoded;
    final batch = Batch.fromJson(batchData);
    assert(() {
      // Safe summary only — no OCR/document/credentials.
      // ignore: avoid_print
      print(
        '[BATCH DETAILS] id=${batch.id} status=${batch.status} '
        'total=${batch.totalFiles} success=${batch.successfulFiles} '
        'failed=${batch.failedFiles} has_validation_issue=${batch.hasValidationIssue} '
        'validation_message=${batch.validationMessage != null} '
        'date=${batch.statementDate} '
        'stockist=${batch.stockistName} hospital=${batch.hospitalName}',
      );
      return true;
    }());
    return batch;
  }

  /// Updates the statement/business date of an already-extracted batch.
  /// Calls Laravel only — does not upload, OCR, or re-extract.
  Future<Batch> updateStatementDate({
    required int batchId,
    required DateTime date,
  }) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse(secondarySalesBatchDateUrl(batchId));

    http.Response response;
    try {
      response = await _apiClient
          .put(uri, body: jsonEncode({'date': dateStr}))
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const BatchDateUpdateException(
        'Request timed out while updating the statement date.',
      );
    } on UnauthorizedException {
      rethrow;
    }

    assert(() {
      // ignore: avoid_print
      print(
        '[BATCH DATE UPDATE] PUT ${secondarySalesBatchDateUrl(batchId)} '
        'date=$dateStr status=${response.statusCode}',
      );
      return true;
    }());

    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 202) {
      final decoded = _tryDecodeMap(response.body);
      final data = decoded?['data'];
      if (data is Map) {
        return Batch.fromJson(Map<String, dynamic>.from(data));
      }
      if (decoded != null && decoded.containsKey('id')) {
        return Batch.fromJson(decoded);
      }
      // Success without body payload — caller should refetch.
      return fetchBatchById(batchId);
    }

    throw BatchDateUpdateException(
      _extractErrorMessage(
        response.body,
        fallback: _fallbackForStatus(response.statusCode),
      ),
      response.statusCode,
    );
  }

  /// Asks Laravel to reprocess an existing Secondary Sales batch.
  Future<void> reprocessBatch(int batchId) async {
    if (batchId <= 0) {
      throw const BatchDateUpdateException('Invalid batch id for reprocess.');
    }
    final uri = Uri.parse(secondarySalesBatchReprocessUrl(batchId));
    http.Response response;
    try {
      response = await _apiClient
          .post(uri, body: jsonEncode({}))
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const BatchDateUpdateException(
        'Request timed out while starting reprocess.',
      );
    } on UnauthorizedException {
      rethrow;
    }

    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 202) {
      return;
    }

    throw BatchDateUpdateException(
      _extractErrorMessage(
        response.body,
        fallback: switch (response.statusCode) {
          403 => 'You are not authorized to reprocess this batch.',
          404 => 'Batch not found.',
          409 || 422 =>
            'This batch cannot be reprocessed right now.',
          _ => 'Unable to reprocess batch (${response.statusCode}).',
        },
      ),
      response.statusCode,
    );
  }

  Map<String, dynamic>? _tryDecodeMap(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  String _extractErrorMessage(String body, {required String fallback}) {
    final decoded = _tryDecodeMap(body);
    if (decoded == null) return fallback;

    final message = decoded['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;

    final error = decoded['error']?.toString().trim();
    if (error != null && error.isNotEmpty) return error;

    final errors = decoded['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          final first = value.first?.toString().trim();
          if (first != null && first.isNotEmpty) return first;
        }
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return fallback;
  }

  String _fallbackForStatus(int statusCode) {
    switch (statusCode) {
      case 403:
        return 'You are not authorized to change this statement date.';
      case 404:
        return 'Batch not found.';
      case 409:
      case 422:
        return 'Cannot change the date while this batch is still processing.';
      default:
        return 'Unable to update statement date ($statusCode).';
    }
  }
}
