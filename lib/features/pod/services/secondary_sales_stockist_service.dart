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

const int kSecondarySalesStockistsPerPage = 50;

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
  return true;
}

/// GET /api/secondary-sales/stockists?page=&per_page=&search=
/// Never sends group_id, position_code, employee_id, or an alphabetic filter.
Uri authorizedStockistsUri({
  int page = 1,
  int perPage = kSecondarySalesStockistsPerPage,
  String search = '',
}) {
  final safePage = page < 1 ? 1 : page;
  final safePerPage =
      perPage < 1 ? kSecondarySalesStockistsPerPage : perPage;
  final params = <String, String>{
    'page': '$safePage',
    'per_page': '$safePerPage',
  };
  final trimmed = search.trim();
  if (trimmed.isNotEmpty) {
    params['search'] = trimmed;
  }
  return Uri.parse(API_SECONDARY_SALES_STOCKISTS_URL).replace(
    queryParameters: params,
  );
}

class AuthorizedStockistsPage {
  const AuthorizedStockistsPage({
    required this.stockists,
    this.currentPage = 1,
    this.lastPage = 1,
    this.nextPage,
    this.perPage = kSecondarySalesStockistsPerPage,
    this.total,
  });

  final List<SecondarySalesStockistInfo> stockists;
  final int currentPage;
  final int lastPage;
  final int? nextPage;
  final int perPage;
  final int? total;

  bool get hasMorePages {
    if (nextPage != null) return nextPage! > currentPage;
    return currentPage < lastPage;
  }
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

/// Fetches one authorized stockist page. Does not fall back to GET /api/stockists.
class SecondarySalesStockistService {
  SecondarySalesStockistService({
    ApiClient? client,
    Future<http.Response> Function(Uri uri)? getter,
  })  : _client = client ?? ApiClient(),
        _getter = getter;

  final ApiClient _client;
  final Future<http.Response> Function(Uri uri)? _getter;

  /// Last identity used to load stockists. Cleared on each successful page-1 fetch
  /// so a later login cannot keep the previous employee's list.
  String? _loadedForToken;

  String? get loadedForToken => _loadedForToken;

  void clear() {
    _loadedForToken = null;
  }

  Future<List<SecondarySalesStockistInfo>> fetchAuthorizedStockists({
    String? authToken,
    String search = '',
  }) async {
    final page = await fetchAuthorizedStockistsPage(
      page: 1,
      search: search,
      authToken: authToken,
    );
    return page.stockists;
  }

  Future<AuthorizedStockistsPage> fetchAuthorizedStockistsPage({
    int page = 1,
    int perPage = kSecondarySalesStockistsPerPage,
    String search = '',
    String? authToken,
  }) async {
    if (page <= 1) {
      _loadedForToken = null;
    }
    try {
      final uri = authorizedStockistsUri(
        page: page,
        perPage: perPage,
        search: search,
      );
      final getter = _getter;
      final response =
          getter != null ? await getter(uri) : await _client.get(uri);

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        final parsed = parseAuthorizedStockistsPage(response.body);
        if (page <= 1) {
          _loadedForToken = authToken;
        }
        return parsed;
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
  return parseAuthorizedStockistsPage(body).stockists;
}

AuthorizedStockistsPage parseAuthorizedStockistsPage(String body) {
  final decoded = jsonDecode(body);
  if (decoded is List) {
    return AuthorizedStockistsPage(stockists: _mapStockists(decoded));
  }
  if (decoded is! Map) {
    return const AuthorizedStockistsPage(stockists: []);
  }

  final map = Map<String, dynamic>.from(decoded);
  final data = map['data'];
  var stockists = const <SecondarySalesStockistInfo>[];
  Map<String, dynamic> pagination = map;

  if (data is List) {
    stockists = _mapStockists(data);
  } else if (data is Map) {
    final nested = Map<String, dynamic>.from(data);
    if (nested['stockists'] is List) {
      stockists = _mapStockists(nested['stockists'] as List);
    } else if (nested['data'] is List) {
      stockists = _mapStockists(nested['data'] as List);
      pagination = nested;
    }
  } else if (map['stockists'] is List) {
    stockists = _mapStockists(map['stockists'] as List);
  }

  if (map['pagination'] is Map) {
    pagination = Map<String, dynamic>.from(map['pagination'] as Map);
  }

  final meta = map['meta'] is Map
      ? Map<String, dynamic>.from(map['meta'] as Map)
      : const <String, dynamic>{};
  final currentPage = _positiveInt(
    pagination['current_page'] ??
        pagination['page'] ??
        meta['current_page'] ??
        map['current_page'],
    1,
  );
  final perPage = _positiveInt(
    pagination['per_page'] ?? meta['per_page'] ?? map['per_page'],
    kSecondarySalesStockistsPerPage,
  );
  final total = _nullablePositiveInt(
    pagination['total'] ??
        pagination['total_records'] ??
        meta['total'] ??
        map['total'],
  );
  final nextPage = _nullablePositiveInt(
        pagination['next_page'] ?? meta['next_page'] ?? map['next_page'],
      ) ??
      _pageFromUrl(
        pagination['next_page_url'] ??
            meta['next_page_url'] ??
            map['next_page_url'] ??
            _linkNext(pagination) ??
            _linkNext(map),
      );
  var lastPage = _nullablePositiveInt(
    pagination['last_page'] ??
        pagination['total_pages'] ??
        meta['last_page'] ??
        meta['total_pages'] ??
        map['last_page'] ??
        map['total_pages'],
  );
  if (lastPage == null) {
    if (total != null && perPage > 0) {
      lastPage = (total / perPage).ceil();
      if (lastPage < 1) lastPage = 1;
    } else {
      lastPage = currentPage;
    }
  }

  return AuthorizedStockistsPage(
    stockists: stockists,
    currentPage: currentPage,
    lastPage: lastPage,
    nextPage: nextPage,
    perPage: perPage,
    total: total,
  );
}

int _positiveInt(dynamic value, int fallback) {
  return _nullablePositiveInt(value) ?? fallback;
}

int? _nullablePositiveInt(dynamic value) {
  if (value is int && value > 0) return value;
  if (value is num && value > 0) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}

dynamic _linkNext(Map<String, dynamic> map) {
  final links = map['links'];
  if (links is Map) return links['next'];
  return null;
}

int? _pageFromUrl(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  return _nullablePositiveInt(uri.queryParameters['page']);
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

List<SecondarySalesStockistInfo> mergeAuthorizedStockists(
  List<SecondarySalesStockistInfo> existing,
  List<SecondarySalesStockistInfo> incoming,
) {
  final merged = List<SecondarySalesStockistInfo>.from(existing);
  final seen = <int>{
    for (final item in existing)
      if (item.id != null) item.id!,
  };
  for (final item in incoming) {
    final id = item.id;
    if (id == null || !seen.add(id)) continue;
    merged.add(item);
  }
  return merged;
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
