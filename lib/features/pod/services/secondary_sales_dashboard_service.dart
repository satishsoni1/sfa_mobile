import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/services/api_client.dart';

class SecondarySalesDashboardException implements Exception {
  final String message;
  final int? statusCode;
  const SecondarySalesDashboardException(this.message, [this.statusCode]);

  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

/// Himalaya Secondary Sales dashboard client.
/// Uses ONLY /api/secondary-sales/dashboard* — no Invoice POD fallbacks.
class SecondarySalesDashboardService {
  SecondarySalesDashboardService({ApiClient? client})
      : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<SecondarySalesDashboardData> fetchDashboard({
    required String month,
    String? kamId,
    String? employeeId,
    String? zoneId,
    String? stockistId,
    String? search,
  }) async {
    final qp = <String, String>{'month': month};
    if (kamId != null && kamId.isNotEmpty) qp['kam_id'] = kamId;
    if (employeeId != null && employeeId.isNotEmpty) {
      qp['employee_id'] = employeeId;
    }
    if (zoneId != null && zoneId.isNotEmpty) qp['zone_id'] = zoneId;
    if (stockistId != null && stockistId.isNotEmpty) {
      qp['stockist_id'] = stockistId;
    }
    if (search != null && search.trim().isNotEmpty) {
      qp['search'] = search.trim();
    }

    final response = await _request(
      Uri.parse(API_SECONDARY_SALES_DASHBOARD_URL).replace(
        queryParameters: qp,
      ),
    );
    final data = SecondarySalesDashboardData.fromJson(_decodeMap(response.body));
    assert(() {
      final sample = data.visibleStockists.take(5).toList();
      // ignore: avoid_print
      print(
        '[DASHBOARD STOCKISTS] month=$month count=${data.visibleStockists.length} '
        'perf=${data.stockistPerformance.length} '
        'breakdown=${data.breakdown.stockist.length} '
        'sample=${sample.map((s) => '${s.stockistName}:${s.stockistId}'
            ':stmts=${s.documents}:done=${s.completedStatements}:sales=${s.sales}').join(' | ')}',
      );
      return true;
    }());
    return data;
  }

  Future<SecondarySalesBreakdownPage> fetchBreakdown({
    required String month,
    required String breakdownType,
    String? kamId,
    String? employeeId,
    String? zoneId,
    String? stockistId,
    String search = '',
    int page = 1,
    int perPage = 20,
  }) async {
    final qp = <String, String>{
      'month': month,
      'breakdown_type': breakdownType,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (kamId != null && kamId.isNotEmpty) qp['kam_id'] = kamId;
    if (employeeId != null && employeeId.isNotEmpty) {
      qp['employee_id'] = employeeId;
    }
    if (zoneId != null && zoneId.isNotEmpty) qp['zone_id'] = zoneId;
    if (stockistId != null && stockistId.isNotEmpty) {
      qp['stockist_id'] = stockistId;
    }
    if (search.trim().isNotEmpty) qp['search'] = search.trim();

    final response = await _request(
      Uri.parse(API_SECONDARY_SALES_DASHBOARD_BREAKDOWN_URL).replace(
        queryParameters: qp,
      ),
    );
    final decoded = _decodeMap(response.body);
    final data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : decoded;
    final rows = SecondarySalesBreakdownRow.listFrom(
      data['items'] ?? data['data'] ?? data['rows'] ?? data,
    );
    final pagination = data['pagination'] is Map
        ? Map<String, dynamic>.from(data['pagination'] as Map)
        : data;
    final currentPage = _asInt(pagination['current_page'] ?? pagination['page']) ?? page;
    final lastPage = _asInt(pagination['last_page'] ?? pagination['total_pages']);
    final hasMore = pagination['next_page'] != null ||
        (lastPage != null && currentPage < lastPage);
    return SecondarySalesBreakdownPage(
      rows: rows,
      page: currentPage,
      hasMore: hasMore,
    );
  }

  Future<List<RecentSecondarySalesDocument>> fetchRecent({
    required String month,
    String? kamId,
    String? employeeId,
    String? zoneId,
    String? stockistId,
  }) async {
    final qp = <String, String>{'month': month};
    if (kamId != null && kamId.isNotEmpty) qp['kam_id'] = kamId;
    if (employeeId != null && employeeId.isNotEmpty) {
      qp['employee_id'] = employeeId;
    }
    if (zoneId != null && zoneId.isNotEmpty) qp['zone_id'] = zoneId;
    if (stockistId != null && stockistId.isNotEmpty) {
      qp['stockist_id'] = stockistId;
    }

    final response = await _request(
      Uri.parse(API_SECONDARY_SALES_DASHBOARD_RECENT_URL).replace(
        queryParameters: qp,
      ),
    );
    final decoded = _decodeMap(response.body);
    final data = decoded['data'];
    return RecentSecondarySalesDocument.listFrom(data);
  }

  Future<SecondarySalesStockistStatementsResponse> getStockistStatements({
    required int stockistId,
    required String month,
    int page = 1,
    int perPage = 20,
    String? search,
    int? kamId,
    String? zoneId,
  }) async {
    final qp = <String, String>{
      'month': month,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      qp['search'] = search.trim();
    }
    if (kamId != null) qp['kam_id'] = kamId.toString();
    if (zoneId != null && zoneId.isNotEmpty) qp['zone_id'] = zoneId;

    final response = await _request(
      Uri.parse(secondarySalesStockistStatementsUrl(stockistId)).replace(
        queryParameters: qp,
      ),
      errorMessage: 'Unable to load stockist statements',
    );
    assert(() {
      // ignore: avoid_print
      print(
        '[STATEMENTS HTTP] '
        'GET ${secondarySalesStockistStatementsUrl(stockistId)} '
        'params=$qp status=${response.statusCode}',
      );
      return true;
    }());
    final parsed = SecondarySalesStockistStatementsResponse.fromJson(
      _decodeMap(response.body),
    );
    assert(() {
      final sample = parsed.statements.take(3).toList();
      // ignore: avoid_print
      print(
        '[STATEMENTS PARSE] stockistId=$stockistId month=$month '
        'count=${parsed.statements.length} '
        'sample=${sample.map((s) => 'id=${s.id}/doc=${s.documentId}/batch=${s.batchId}'
            ' status=${s.status} validation=${s.hasValidationIssue}').join(' | ')}',
      );
      return true;
    }());
    return parsed;
  }

  Future<SecondarySalesKamStockistsResponse> fetchKamStockists({
    required int kamId,
    required String month,
  }) async {
    final response = await _request(
      Uri.parse(secondarySalesKamStockistsUrl(kamId)).replace(
        queryParameters: {'month': month},
      ),
      errorMessage: 'Unable to load stockist data',
    );
    return SecondarySalesKamStockistsResponse.fromJson(
      _decodeMap(response.body),
    );
  }

  Future<http.Response> _request(
    Uri uri, {
    String errorMessage = 'Unable to load Secondary Sales dashboard',
  }) async {
    try {
      final response = await _client.get(uri);
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        return response;
      }
      if (response.statusCode == 403) {
        throw SecondarySalesDashboardException(
          _messageFromBody(
                response.body,
                fallback: 'You are not authorized to view this data.',
              ) ??
              'You are not authorized to view this data.',
          403,
        );
      }
      if (response.statusCode == 404) {
        throw const SecondarySalesDashboardException(
          'This data is no longer available.',
          404,
        );
      }
      if (response.statusCode == 422) {
        throw SecondarySalesDashboardException(
          _messageFromBody(response.body, fallback: errorMessage) ??
              errorMessage,
          422,
        );
      }
      throw SecondarySalesDashboardException(
        _messageFromBody(response.body, fallback: errorMessage) ?? errorMessage,
        response.statusCode,
      );
    } on SecondarySalesDashboardException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      throw SecondarySalesDashboardException(errorMessage);
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const SecondarySalesDashboardException(
      'Unable to load Secondary Sales dashboard',
    );
  }

  String? _messageFromBody(String body, {String? fallback}) {
    if (body.trim().isEmpty) return fallback;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        final msg = decoded['message'].toString().trim();
        if (msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    return fallback;
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }
}
