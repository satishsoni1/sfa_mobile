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
    String? zoneId,
  }) async {
    final qp = <String, String>{'month': month};
    if (kamId != null && kamId.isNotEmpty) qp['kam_id'] = kamId;
    if (zoneId != null && zoneId.isNotEmpty) qp['zone_id'] = zoneId;

    final response = await _request(
      Uri.parse(API_SECONDARY_SALES_DASHBOARD_URL).replace(
        queryParameters: qp,
      ),
    );
    return SecondarySalesDashboardData.fromJson(_decodeMap(response.body));
  }

  Future<SecondarySalesBreakdownPage> fetchBreakdown({
    required String month,
    required String breakdownType,
    String? kamId,
    String? zoneId,
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
    if (zoneId != null && zoneId.isNotEmpty) qp['zone_id'] = zoneId;
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
    String? zoneId,
  }) async {
    final qp = <String, String>{'month': month};
    if (kamId != null && kamId.isNotEmpty) qp['kam_id'] = kamId;
    if (zoneId != null && zoneId.isNotEmpty) qp['zone_id'] = zoneId;

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
    return SecondarySalesStockistStatementsResponse.fromJson(
      _decodeMap(response.body),
    );
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
        throw const SecondarySalesDashboardException(
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
        throw SecondarySalesDashboardException(errorMessage, 422);
      }
      throw SecondarySalesDashboardException(errorMessage, response.statusCode);
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

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }
}
