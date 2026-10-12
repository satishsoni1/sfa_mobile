import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/models/secondary_sales_upload_on_behalf_models.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';

class SecondarySalesUploadOnBehalfException implements Exception {
  const SecondarySalesUploadOnBehalfException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  bool get isForbidden => statusCode == 403;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

void _ssTrace(String message) {
  // Use print so TRACE always appears in adb logcat (debugPrint may be stripped).
  // ignore: avoid_print
  print('[SS_ON_BEHALF_TRACE] $message');
  debugPrint('[SS_ON_BEHALF_TRACE] $message');
}

/// Client for Secondary Sales "upload on behalf" Laravel endpoints.
/// Authorization/hierarchy stay on the server.
///
/// Uses the same [ApiClient] / Sanctum bearer token as Stockist & upload APIs.
class SecondarySalesUploadOnBehalfService {
  SecondarySalesUploadOnBehalfService({
    ApiClient? client,
    Future<http.Response> Function(Uri uri)? getter,
  })  : _client = client ?? ApiClient(),
        _getter = getter;

  final ApiClient _client;
  final Future<http.Response> Function(Uri uri)? _getter;

  static int _requestCounter = 0;

  Future<http.Response> _get(Uri uri) {
    final getter = _getter;
    if (getter != null) return getter(uri);
    // Same authenticated client as stockists — plus Accept for Laravel JSON.
    return _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
      },
    );
  }

  Future<List<SecondarySalesUploadTeamMember>> fetchTeamMembers() async {
    final requestNo = ++_requestCounter;
    final uri = Uri.parse(API_SECONDARY_SALES_UPLOAD_TEAM_MEMBERS_URL);

    _ssTrace('request=$requestNo START');
    _ssTrace('service fetchTeamMembers entered');
    _ssTrace('baseUrl=$API_BASE_URL');
    _ssTrace('path=${uri.path}');
    _ssTrace('fullUrl=${uri.toString()}');
    _ssTrace('host=${uri.host}');
    _ssTrace('scheme=${uri.scheme}');
    _ssTrace('acceptHeader=application/json');
    _ssTrace('usingApiClient=${_getter == null}');

    try {
      _ssTrace('request-start');
      final response = await _get(uri);
      _ssTrace('response-runtime-type=${response.runtimeType}');
      _ssTrace('status=${response.statusCode}');
      _ssTrace(
        'content-type=${response.headers['content-type'] ?? response.headers['Content-Type'] ?? '(none)'}',
      );
      _ssTrace('body-length=${response.bodyBytes.length}');
      _ssTrace('body-preview=${_safeBodyPreview(response.body, max: 500)}');

      if (response.statusCode != 200 &&
          response.statusCode != 201 &&
          response.statusCode != 202) {
        _ssTrace(
          'NON-200 STOP status=${response.statusCode} '
          'body=${_safeBodyPreview(response.body, max: 500)}',
        );
      }

      final members = _parseTeamMembersResponse(response);
      _ssTrace('model-count=${members.length}');
      _ssTrace('request=$requestNo END success=true count=${members.length}');
      return members;
    } on SecondarySalesUploadOnBehalfException catch (e, st) {
      _ssTrace('EXCEPTION');
      _ssTrace('type=SecondarySalesUploadOnBehalfException');
      _ssTrace('message=${e.message}');
      _ssTrace('statusCode=${e.statusCode}');
      _ssTrace('stack=$st');
      _ssTrace('request=$requestNo END success=false');
      rethrow;
    } on UnauthorizedException catch (e, st) {
      _ssTrace('EXCEPTION');
      _ssTrace('type=UnauthorizedException');
      _ssTrace('message=$e');
      _ssTrace('stack=$st');
      _ssTrace('request=$requestNo END success=false');
      rethrow;
    } on SocketException catch (e, st) {
      _ssTrace('EXCEPTION');
      _ssTrace('type=SocketException');
      _ssTrace('message=$e');
      _ssTrace('stack=$st');
      _ssTrace('request=$requestNo END success=false');
      throw SecondarySalesUploadOnBehalfException(
        'SocketException: $e',
      );
    } on TimeoutException catch (e, st) {
      _ssTrace('EXCEPTION');
      _ssTrace('type=TimeoutException');
      _ssTrace('message=$e');
      _ssTrace('stack=$st');
      _ssTrace('request=$requestNo END success=false');
      throw SecondarySalesUploadOnBehalfException(
        'TimeoutException: $e',
      );
    } on FormatException catch (e, st) {
      _ssTrace('EXCEPTION');
      _ssTrace('type=FormatException');
      _ssTrace('message=$e');
      _ssTrace('stack=$st');
      _ssTrace('request=$requestNo END success=false');
      throw SecondarySalesUploadOnBehalfException(
        'FormatException: $e',
      );
    } on TypeError catch (e, st) {
      _ssTrace('EXCEPTION');
      _ssTrace('type=TypeError');
      _ssTrace('message=$e');
      _ssTrace('stack=$st');
      _ssTrace('request=$requestNo END success=false');
      throw SecondarySalesUploadOnBehalfException(
        'TypeError: $e',
      );
    } catch (e, st) {
      _ssTrace('EXCEPTION');
      _ssTrace('type=${e.runtimeType}');
      _ssTrace('message=$e');
      _ssTrace('stack=$st');
      _ssTrace('request=$requestNo END success=false');
      // Keep the real exception visible — do not hide behind generic text.
      throw SecondarySalesUploadOnBehalfException(
        '${e.runtimeType}: $e',
      );
    }
  }

  Future<List<SecondarySalesStockistInfo>> fetchStockistsForEmployee(
    int employeeId, {
    String search = '',
  }) async {
    if (employeeId <= 0) {
      throw const SecondarySalesUploadOnBehalfException(
        'Select a valid team member first.',
      );
    }
    final qp = <String, String>{};
    final q = search.trim();
    if (q.isNotEmpty) qp['search'] = q;

    final uri = Uri.parse(
      secondarySalesUploadTeamMemberStockistsUrl(employeeId),
    ).replace(queryParameters: qp.isEmpty ? null : qp);

    final response = await _get(uri);
    return _parseStockistsResponse(response);
  }

  List<SecondarySalesUploadTeamMember> _parseTeamMembersResponse(
    http.Response response,
  ) {
    _throwIfHttpError(
      response,
      fallback403:
          'You are not authorized to upload on behalf of team members.',
      fallback:
          'Unable to load team members. Please try again later.',
    );

    final body = response.body;
    if (body.trim().isEmpty) {
      _ssTrace('empty body — treating as []');
      _ssTrace('parsed-row-count=0');
      _ssTrace('model-count=0');
      return const [];
    }

    try {
      final decoded = jsonDecode(body);
      _ssTrace('decoded-runtime-type=${decoded.runtimeType}');
      _logJsonStructure(decoded);

      // Trace only — do not change extraction/parser logic here.
      final members = SecondarySalesUploadTeamMember.listFrom(decoded);
      _ssTrace('parsed-row-count=${members.length}');
      _ssTrace('model-count=${members.length}');
      return members;
    } on FormatException catch (e, st) {
      _ssTrace('EXCEPTION');
      _ssTrace('type=FormatException');
      _ssTrace('message=$e');
      _ssTrace('stack=$st');
      throw SecondarySalesUploadOnBehalfException(
        'FormatException: $e',
        response.statusCode,
      );
    } on TypeError catch (e, st) {
      _ssTrace('EXCEPTION');
      _ssTrace('type=TypeError');
      _ssTrace('message=$e');
      _ssTrace('stack=$st');
      throw SecondarySalesUploadOnBehalfException(
        'TypeError: $e',
        response.statusCode,
      );
    } catch (e, st) {
      _ssTrace('EXCEPTION');
      _ssTrace('type=${e.runtimeType}');
      _ssTrace('message=$e');
      _ssTrace('stack=$st');
      throw SecondarySalesUploadOnBehalfException(
        '${e.runtimeType}: $e',
        response.statusCode,
      );
    }
  }

  void _logJsonStructure(dynamic decoded) {
    if (decoded is! Map) {
      _ssTrace('top-level keys=(not a Map)');
      _ssTrace('data-type=(n/a)');
      return;
    }
    final map = Map<String, dynamic>.from(decoded);
    _ssTrace('top-level keys=${map.keys.toList()}');
    final data = map['data'];
    _ssTrace('data-type=${data?.runtimeType}');
    if (data is Map) {
      final nested = Map<String, dynamic>.from(data);
      _ssTrace('data-keys=${nested.keys.toList()}');
      final tm = nested['team_members'];
      _ssTrace('team_members-type=${tm?.runtimeType}');
      if (tm is List) {
        _ssTrace('team_members-count=${tm.length}');
      } else {
        _ssTrace('team_members-count=(not a List)');
      }
      final emp = nested['employees'];
      _ssTrace('data.employees-type=${emp?.runtimeType}');
      if (emp is List) {
        _ssTrace('data.employees-count=${emp.length}');
      }
    } else if (data is List) {
      _ssTrace('data-keys=(data is List)');
      _ssTrace('team_members-type=(n/a — data is List)');
      _ssTrace('team_members-count=(n/a)');
    }
    final topEmp = map['employees'];
    _ssTrace('top-employees-type=${topEmp?.runtimeType}');
    if (topEmp is List) {
      _ssTrace('top-employees-count=${topEmp.length}');
    }
  }

  List<SecondarySalesStockistInfo> _parseStockistsResponse(
    http.Response response,
  ) {
    _throwIfHttpError(
      response,
      fallback403:
          'You are not authorized to upload on behalf of this employee.',
      fallback:
          'Unable to load stockists for this employee. Please try again.',
    );
    try {
      return parseAuthorizedStockists(response.body);
    } catch (e) {
      if (e is SecondarySalesUploadOnBehalfException) rethrow;
      throw const SecondarySalesUploadOnBehalfException(
        'Unable to load stockists for this employee. Please try again.',
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

    _ssTrace(
      'HTTP error status=$code bodyPreview=${_safeBodyPreview(response.body)}',
    );

    final apiMessage = _messageFromBody(response.body);

    if (code == 401) {
      throw SecondarySalesUploadOnBehalfException(
        apiMessage ?? 'Your session has expired. Please login again.',
        401,
      );
    }
    if (code == 403) {
      throw SecondarySalesUploadOnBehalfException(
        apiMessage ?? fallback403,
        403,
      );
    }
    if (code == 404) {
      throw SecondarySalesUploadOnBehalfException(
        apiMessage ?? 'Team members endpoint was not found.',
        404,
      );
    }
    if (code == 422) {
      throw SecondarySalesUploadOnBehalfException(
        secondarySalesUploadUnprocessableMessage(response.body),
        422,
      );
    }
    if (code == 429) {
      throw const SecondarySalesUploadOnBehalfException(
        'Too many requests. Please wait a moment and try again.',
        429,
      );
    }
    if (code >= 500) {
      throw SecondarySalesUploadOnBehalfException(
        'Server error ($code): ${apiMessage ?? _safeBodyPreview(response.body, max: 200)}',
        code,
      );
    }
    throw SecondarySalesUploadOnBehalfException(
      '$fallback (HTTP $code)',
      code,
    );
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

  /// Truncated body for logs — never includes Authorization headers/tokens.
  String _safeBodyPreview(String body, {int max = 240}) {
    final trimmed = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max)}…';
  }
}
