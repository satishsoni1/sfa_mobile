import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/secondary_sales_stock_correction_models.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';

class SecondarySalesStockCorrectionException implements Exception {
  const SecondarySalesStockCorrectionException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  bool get isForbidden => statusCode == 403;
  bool get isUnauthorized => statusCode == 401;
  bool get isValidation => statusCode == 422;

  @override
  String toString() => message;
}

/// Client for GET/POST /secondary-sales/{statement}/corrections.
class SecondarySalesStockCorrectionService {
  SecondarySalesStockCorrectionService({
    ApiClient? client,
    Future<http.Response> Function(Uri uri)? getter,
    Future<http.Response> Function(Uri uri, {Object? body})? poster,
  })  : _client = client ?? ApiClient(),
        _getter = getter,
        _poster = poster;

  final ApiClient _client;
  final Future<http.Response> Function(Uri uri)? _getter;
  final Future<http.Response> Function(Uri uri, {Object? body})? _poster;

  Future<http.Response> _get(Uri uri) {
    final getter = _getter;
    if (getter != null) return getter(uri);
    return _client.get(uri);
  }

  Future<http.Response> _post(Uri uri, {Object? body}) {
    final poster = _poster;
    if (poster != null) return poster(uri, body: body);
    return _client.post(uri, body: body);
  }

  Future<SecondarySalesCorrectionResponse> fetchCorrections(
    int statementId,
  ) async {
    if (statementId <= 0) {
      throw const SecondarySalesStockCorrectionException(
        'Invalid statement id.',
      );
    }
    final response = await _get(
      Uri.parse(secondarySalesCorrectionsUrl(statementId)),
    );
    _throwIfHttpError(
      response,
      fallback403: 'You do not have permission to view stock corrections.',
      fallback: 'Unable to load stock corrections. Please try again.',
    );
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const SecondarySalesStockCorrectionException(
          'Unable to load stock corrections. Please try again.',
        );
      }
      return SecondarySalesCorrectionResponse.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on SecondarySalesStockCorrectionException {
      rethrow;
    } catch (_) {
      throw const SecondarySalesStockCorrectionException(
        'Unable to load stock corrections. Please try again.',
      );
    }
  }

  Future<SecondarySalesCorrectionResponse> saveCorrections({
    required int statementId,
    required String reason,
    required List<SecondarySalesCorrectionLine> originalLines,
    required Map<int, SecondarySalesCorrectionDraft> drafts,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.length < 5) {
      throw const SecondarySalesStockCorrectionException(
        'Please enter a reason (at least 5 characters).',
        422,
      );
    }

    final payload = buildSecondarySalesCorrectionPayload(
      reason: trimmedReason,
      originalLines: originalLines,
      drafts: drafts,
    );
    final corrections = payload['corrections'] as List? ?? const [];
    if (corrections.isEmpty) {
      throw const SecondarySalesStockCorrectionException(
        'No quantity changes to save.',
        422,
      );
    }

    final response = await _post(
      Uri.parse(secondarySalesCorrectionsUrl(statementId)),
      body: jsonEncode(payload),
    );
    _throwIfHttpError(
      response,
      fallback403: 'You do not have permission to modify stock quantities.',
      fallback: 'Unable to save stock corrections. Please try again.',
    );

    // Prefer refreshed GET payload; fall back to POST body if Laravel returns it.
    try {
      return await fetchCorrections(statementId);
    } catch (_) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return SecondarySalesCorrectionResponse.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {}
      rethrow;
    }
  }

  void _throwIfHttpError(
    http.Response response, {
    required String fallback403,
    required String fallback,
  }) {
    final code = response.statusCode;
    if (code == 200 || code == 201 || code == 202) return;
    if (code == 401) {
      throw const SecondarySalesStockCorrectionException(
        'Your session has expired. Please login again.',
        401,
      );
    }
    if (code == 403) {
      throw SecondarySalesStockCorrectionException(
        _messageFromBody(response.body) ?? fallback403,
        403,
      );
    }
    if (code == 404) {
      throw SecondarySalesStockCorrectionException(
        _messageFromBody(response.body) ?? 'Statement not found.',
        404,
      );
    }
    if (code == 422) {
      throw SecondarySalesStockCorrectionException(
        secondarySalesFormatLaravelValidationMessage(response.body) ??
            _messageFromBody(response.body) ??
            'Validation failed. Please check the quantities and try again.',
        422,
      );
    }
    if (code == 429) {
      throw const SecondarySalesStockCorrectionException(
        'Too many requests. Please wait a moment and try again.',
        429,
      );
    }
    throw SecondarySalesStockCorrectionException(fallback, code);
  }

  String? _messageFromBody(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        final msg = decoded['message'].toString().trim();
        if (msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    return null;
  }
}
