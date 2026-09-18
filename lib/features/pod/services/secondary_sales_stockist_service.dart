import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/services/api_client.dart';

const String kSecondarySalesStockistUnauthorizedMessage =
    'You are not authorized to view stockists.';
const String kSecondarySalesStockistNotFoundMessage =
    'Stockist data is not available.';
const String kSecondarySalesStockistEmptyMessage =
    'No stockists are available for your account.';
const String kSecondarySalesUploadForbiddenMessage =
    'You are not authorized to upload a statement for this stockist.';
const String kSecondarySalesMonthMismatchMessage =
    'You can upload statements of the selected month only.';
const String kSecondarySalesMonthUndeterminedMessage =
    'Unable to determine the statement month. Please upload a valid stock statement.';

/// Stockist list URL for the active upload type.
/// Himalaya Secondary Sales uses the authorized endpoint only.
/// Invoice POD keeps GET /api/stockists.
String stockistListUrlForUploadType(String uploadType) {
  if (uploadType == kUploadTypeSecondarySales) {
    return API_SECONDARY_SALES_STOCKISTS_URL;
  }
  return API_STOCKISTS_URL;
}

bool usesServerSideStockistSearch(String uploadType) {
  return uploadType != kUploadTypeSecondarySales;
}

class SecondarySalesStockistException implements Exception {
  final String message;
  final int? statusCode;
  const SecondarySalesStockistException(this.message, [this.statusCode]);

  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

/// Fetches stockists authorized by Laravel for the logged-in user.
/// Does not fall back to GET /api/stockists.
class SecondarySalesStockistService {
  SecondarySalesStockistService({
    ApiClient? client,
    Future<http.Response> Function(Uri uri)? getter,
  })  : _client = client ?? ApiClient(),
        _getter = getter;

  final ApiClient _client;
  final Future<http.Response> Function(Uri uri)? _getter;

  /// Last identity used to load stockists. Cleared on each successful fetch
  /// so a later login cannot keep the previous employee's list.
  String? _loadedForToken;

  String? get loadedForToken => _loadedForToken;

  void clear() {
    _loadedForToken = null;
  }

  Future<List<SecondarySalesStockistInfo>> fetchAuthorizedStockists({
    String? authToken,
  }) async {
    _loadedForToken = null;
    try {
      final uri = Uri.parse(API_SECONDARY_SALES_STOCKISTS_URL);
      final getter = _getter;
      final response =
          getter != null ? await getter(uri) : await _client.get(uri);

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        final stockists = parseAuthorizedStockists(response.body);
        _loadedForToken = authToken;
        return stockists;
      }
      if (response.statusCode == 403) {
        throw const SecondarySalesStockistException(
          kSecondarySalesStockistUnauthorizedMessage,
          403,
        );
      }
      if (response.statusCode == 404) {
        throw const SecondarySalesStockistException(
          kSecondarySalesStockistNotFoundMessage,
          404,
        );
      }
      throw SecondarySalesStockistException(
        'Unable to load stockists. Please try again later.',
        response.statusCode,
      );
    } on SecondarySalesStockistException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } on SocketException {
      throw const SecondarySalesStockistException(
        'Unable to load stockists. Please check your connection and try again.',
      );
    } catch (e) {
      if (e is SecondarySalesStockistException || e is UnauthorizedException) {
        rethrow;
      }
      throw const SecondarySalesStockistException(
        'Unable to load stockists. Please check your connection and try again.',
      );
    }
  }
}

List<SecondarySalesStockistInfo> parseAuthorizedStockists(String body) {
  final decoded = jsonDecode(body);
  if (decoded is List) {
    return _mapStockists(decoded);
  }
  if (decoded is Map) {
    final data = decoded['data'];
    if (data is List) {
      return _mapStockists(data);
    }
    if (data is Map && data['stockists'] is List) {
      return _mapStockists(data['stockists'] as List);
    }
    if (decoded['stockists'] is List) {
      return _mapStockists(decoded['stockists'] as List);
    }
  }
  return const [];
}

List<SecondarySalesStockistInfo> _mapStockists(List<dynamic> raw) {
  final items = <SecondarySalesStockistInfo>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final info = SecondarySalesStockistInfo.fromJson(
      Map<String, dynamic>.from(entry),
    );
    if (info.id == null) continue;
    items.add(info);
  }
  return items;
}

List<SecondarySalesStockistInfo> filterAuthorizedStockists(
  List<SecondarySalesStockistInfo> stockists,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List<SecondarySalesStockistInfo>.from(stockists);
  return stockists.where((s) {
    final name = s.name.toLowerCase();
    final id = s.id?.toString() ?? '';
    return name.contains(q) || id.contains(q);
  }).toList();
}

Map<String, String> buildSecondarySalesUploadFields({
  required int stockistId,
  required DateTime selectedMonth,
  String companyName = 'Himalaya',
  String remarks = 'Mobile upload',
}) {
  final statementMonth =
      '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';
  return {
    'stockist_id': stockistId.toString(),
    'statement_month': statementMonth,
    'company_name': companyName,
    'remarks': remarks,
  };
}

bool secondarySalesShouldNavigateToStatus(int statusCode) {
  return statusCode == 200 || statusCode == 201 || statusCode == 202;
}

String secondarySalesUploadForbiddenMessage(String body) {
  final parsed = _messageFromBody(body);
  if (parsed != null && parsed.isNotEmpty) return parsed;
  return kSecondarySalesUploadForbiddenMessage;
}

String secondarySalesUploadUnprocessableMessage(String body) {
  final parsed = _messageFromBody(body);
  if (parsed != null && parsed.isNotEmpty) return parsed;
  return 'The upload was rejected. Please check the file and try again.';
}

/// Filename is never used to extract or reject statement month.
/// Laravel extracts the month from the uploaded document.
bool secondarySalesClientBlocksOnFilenameMonth(String fileName) => false;

String? _messageFromBody(String body) {
  if (body.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['message'] != null) {
      return decoded['message'].toString();
    }
  } catch (_) {}
  return null;
}
