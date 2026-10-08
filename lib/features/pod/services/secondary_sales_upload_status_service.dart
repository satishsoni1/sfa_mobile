import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/secondary_sales_upload_status_models.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';

class SecondarySalesUploadStatusException implements Exception {
  const SecondarySalesUploadStatusException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  bool get isForbidden => statusCode == 403;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Builds query params for GET /secondary-sales/upload-status.
/// Only includes applicable non-empty values.
Map<String, String> buildSecondarySalesUploadStatusQuery({
  required String month,
  required String level,
  int page = 1,
  int perPage = 50,
  String? division,
  int? zmId,
  int? smId,
  int? nsmId,
  int? stateId,
  int? teamId,
  int? employeeId,
  int? stockistId,
  String? search,
}) {
  final qp = <String, String>{
    'month': month,
    'level': level,
    'page': page.toString(),
    'per_page': perPage.toString(),
  };
  void put(String key, Object? value) {
    if (value == null) return;
    final text = value.toString().trim();
    if (text.isEmpty || text == '0') return;
    qp[key] = text;
  }

  put('division', division);
  put('zm_id', zmId);
  put('sm_id', smId);
  put('nsm_id', nsmId);
  put('state_id', stateId);
  put('team_id', teamId);
  put('employee_id', employeeId);
  put('stockist_id', stockistId);
  final trimmedSearch = search?.trim();
  if (trimmedSearch != null && trimmedSearch.isNotEmpty) {
    qp['search'] = trimmedSearch;
  }
  return qp;
}

/// Placeholder for the Upload Status search field by report level.
String secondarySalesUploadStatusSearchHint(String level) {
  switch (level.trim().toLowerCase()) {
    case 'zm':
      return 'Search ZM';
    case 'sm':
      return 'Search SM';
    case 'nsm':
      return 'Search NSM';
    case 'state':
      return 'Search State';
    case 'team':
      return 'Search Team';
    case 'employee':
      return 'Search Employee';
    case 'customer':
      return 'Search Stockist';
    default:
      return 'Search';
  }
}

/// Client for hierarchy-aware Upload Status Report APIs.
class SecondarySalesUploadStatusService {
  SecondarySalesUploadStatusService({
    ApiClient? client,
    Future<http.Response> Function(Uri uri)? getter,
  })  : _client = client ?? ApiClient(),
        _getter = getter;

  final ApiClient _client;
  final Future<http.Response> Function(Uri uri)? _getter;

  Future<http.Response> _get(Uri uri) {
    final getter = _getter;
    if (getter != null) return getter(uri);
    return _client.get(uri);
  }

  Future<SecondarySalesUploadStatusResponse> fetchReport({
    required String month,
    required String level,
    int page = 1,
    int perPage = 50,
    String? division,
    int? zmId,
    int? smId,
    int? nsmId,
    int? stateId,
    int? teamId,
    int? employeeId,
    int? stockistId,
    String? search,
  }) async {
    final qp = buildSecondarySalesUploadStatusQuery(
      month: month,
      level: level,
      page: page,
      perPage: perPage,
      division: division,
      zmId: zmId,
      smId: smId,
      nsmId: nsmId,
      stateId: stateId,
      teamId: teamId,
      employeeId: employeeId,
      stockistId: stockistId,
      search: search,
    );

    final uri = Uri.parse(API_SECONDARY_SALES_UPLOAD_STATUS_URL)
        .replace(queryParameters: qp);
    final response = await _get(uri);
    _throwIfHttpError(
      response,
      fallback403:
          'You are not authorized to view this upload status report.',
      fallback: 'Unable to load upload status report. Please try again.',
    );
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const SecondarySalesUploadStatusException(
          'Unable to load upload status report. Please try again.',
        );
      }
      return SecondarySalesUploadStatusResponse.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on SecondarySalesUploadStatusException {
      rethrow;
    } catch (_) {
      throw const SecondarySalesUploadStatusException(
        'Unable to load upload status report. Please try again.',
      );
    }
  }

  Future<List<SecondarySalesUploadStatusFilterOption>> fetchFilterOptions(
    String filterKey, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse(secondarySalesUploadStatusFilterUrl(filterKey))
        .replace(queryParameters: (query == null || query.isEmpty) ? null : query);
    final response = await _get(uri);
    _throwIfHttpError(
      response,
      fallback403: 'You are not authorized to view these filters.',
      fallback: 'Unable to load filter options. Please try again.',
    );
    try {
      final decoded = jsonDecode(response.body);
      return SecondarySalesUploadStatusFilterOption.listFrom(decoded);
    } catch (e) {
      if (e is SecondarySalesUploadStatusException) rethrow;
      throw const SecondarySalesUploadStatusException(
        'Unable to load filter options. Please try again.',
      );
    }
  }

  Future<SecondarySalesUploadStatusStockistSummary> fetchStockistSummary({
    required int stockistId,
    required String month,
  }) async {
    if (stockistId <= 0) {
      throw const SecondarySalesUploadStatusException(
        'Select a valid stockist.',
      );
    }
    final uri = Uri.parse(
      secondarySalesUploadStatusStockistSummaryUrl(stockistId),
    ).replace(queryParameters: {'month': month});
    final response = await _get(uri);
    _throwIfHttpError(
      response,
      fallback403: 'You are not authorized to view this stockist summary.',
      fallback: 'Unable to load stockist summary. Please try again.',
    );
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const SecondarySalesUploadStatusException(
          'Unable to load stockist summary. Please try again.',
        );
      }
      return SecondarySalesUploadStatusStockistSummary.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on SecondarySalesUploadStatusException {
      rethrow;
    } catch (_) {
      throw const SecondarySalesUploadStatusException(
        'Unable to load stockist summary. Please try again.',
      );
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
      throw const SecondarySalesUploadStatusException(
        'Your session has expired. Please login again.',
        401,
      );
    }
    if (code == 403) {
      throw SecondarySalesUploadStatusException(
        _messageFromBody(response.body) ?? fallback403,
        403,
      );
    }
    if (code == 404) {
      throw SecondarySalesUploadStatusException(
        _messageFromBody(response.body) ?? 'Data not found.',
        404,
      );
    }
    if (code == 422) {
      throw SecondarySalesUploadStatusException(
        secondarySalesFormatLaravelValidationMessage(response.body) ??
            _messageFromBody(response.body) ??
            'Invalid filters. Please adjust and try again.',
        422,
      );
    }
    if (code == 429) {
      throw const SecondarySalesUploadStatusException(
        'Too many requests. Please wait a moment and try again.',
        429,
      );
    }
    throw SecondarySalesUploadStatusException(fallback, code);
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
