import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gift_shipment_model.dart';
import '../services/api_service.dart';

class GiftApiService {
  final Dio _dio;

  GiftApiService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
  }

  /// Resolves the base URL from SharedPreferences or falls back to default.
  /// Normalizes whether the base URL includes '/api' or not.
  Future<String> _resolveBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    String? base = prefs.getString('base_url');
    if (base == null || base.trim().isEmpty) {
      base = 'https://va-akumentis.globalspace.in/api';
    }
    base = base.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  /// Resolves the logged-in employee ID by reusing ApiService().getUser()
  /// and inspecting SharedPreferences.
  Future<dynamic> _resolveEmployeeId() async {
    // 1. Try ApiService().getUser() (responsible code reuse from core auth)
    try {
      final user = await ApiService().getUser();
      if (user != null && user.employeeId > 0) {
        return user.employeeId;
      }
    } catch (_) {}

    // 2. Direct SharedPreferences check for 'employee_id'
    final prefs = await SharedPreferences.getInstance();
    final directStr = prefs.getString('employee_id');
    if (directStr != null && directStr.isNotEmpty) {
      final parsed = int.tryParse(directStr);
      return parsed ?? directStr;
    }

    final directInt = prefs.getInt('employee_id');
    if (directInt != null && directInt > 0) return directInt;

    // 3. Fallback: Parse 'user_data' JSON
    final userString = prefs.getString('user_data');
    if (userString != null && userString.isNotEmpty) {
      try {
        final decoded = jsonDecode(userString);
        if (decoded is Map) {
          final id = decoded['employee_id'] ?? decoded['id'] ?? decoded['user_id'];
          if (id != null) {
            final parsed = int.tryParse(id.toString());
            return parsed ?? id.toString();
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Helper to get authorization headers from SharedPreferences.
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final employeeId = await _resolveEmployeeId();

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (employeeId != null) {
      headers['X-Employee-Id'] = employeeId.toString();
    }

    return headers;
  }

  /// Builds the full endpoint URI respecting whether the base URL already has '/api'.
  String _buildUrl(String baseUrl, String path) {
    // path is e.g. '/api/gifts/shipments/pending'
    if (baseUrl.endsWith('/api') && path.startsWith('/api/')) {
      return '$baseUrl${path.substring(4)}';
    }
    return '$baseUrl$path';
  }

  /// Extract friendly error message from DioException
  String _extractErrorMessage(DioException e) {
    if (e.response != null && e.response?.data != null) {
      dynamic data = e.response?.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (data is Map) {
        if (data['message'] != null) {
          return data['message'].toString();
        } else if (data['error'] != null && data['error'] is! bool) {
          return data['error'].toString();
        }
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return "Connection timed out. Please check your internet connection.";
    }
    return e.message ?? "An unexpected network error occurred.";
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. GET /api/gifts/shipments/pending
  // ───────────────────────────────────────────────────────────────────────────
  Future<List<GiftShipmentModel>> getPendingShipments() async {
    try {
      final baseUrl = await _resolveBaseUrl();
      final headers = await _getHeaders();
      final employeeId = await _resolveEmployeeId();
      final url = _buildUrl(baseUrl, '/api/gifts/shipments/pending');

      final queryParams = <String, dynamic>{};
      if (employeeId != null) {
        queryParams['employee_id'] = employeeId.toString();
      }

      debugPrint('[GiftApiService] GET pending shipments with employee_id: $employeeId (URL: $url)');

      final response = await _dio.get(
        url,
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      dynamic rawData = response.data;
      if (rawData is String) {
        try {
          rawData = jsonDecode(rawData);
        } catch (_) {}
      }

      if (rawData is Map && (rawData['error'] == true || rawData['status'] == 500) && rawData['data'] == null) {
        throw Exception(rawData['message'] ?? 'Failed to load pending shipments');
      }

      List<dynamic> list = [];
      if (rawData is List) {
        list = rawData;
      } else if (rawData is Map && rawData['data'] is List) {
        list = rawData['data'];
      } else if (rawData is Map && rawData['shipments'] is List) {
        list = rawData['shipments'];
      }

      return list
          .map((item) => GiftShipmentModel.fromJson(Map<String, dynamic>.from(item is Map ? item : {})))
          .toList();
    } on DioException catch (e) {
      debugPrint('[GiftApiService] getPendingShipments error: $e');
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      debugPrint('[GiftApiService] getPendingShipments unexpected error: $e');
      throw Exception('Failed to load pending shipments: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. POST /api/gifts/shipments/accept
  // ───────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> submitAcceptance({
    required String shipmentId,
    required String acceptedOn,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final baseUrl = await _resolveBaseUrl();
      final headers = await _getHeaders();
      final employeeId = await _resolveEmployeeId();
      final url = _buildUrl(baseUrl, '/api/gifts/shipments/accept');

      final payload = <String, dynamic>{
        'shipment_id': shipmentId,
        'accepted_on': acceptedOn,
        'items': items,
      };
      if (employeeId != null) {
        payload['employee_id'] = employeeId;
      }

      debugPrint('[GiftApiService] POST: $url | Payload: $payload');
      final response = await _dio.post(
        url,
        data: payload,
        options: Options(headers: headers),
      );

      dynamic responseData = response.data;
      if (responseData is String) {
        try {
          responseData = jsonDecode(responseData);
        } catch (_) {}
      }

      if (responseData is Map<String, dynamic>) {
        return responseData;
      } else if (responseData is Map) {
        return Map<String, dynamic>.from(responseData);
      }
      return {'status': 'success', 'message': 'Shipment accepted successfully'};
    } on DioException catch (e) {
      debugPrint('[GiftApiService] submitAcceptance error: $e');
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      debugPrint('[GiftApiService] submitAcceptance unexpected error: $e');
      throw Exception('Failed to submit shipment acceptance: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. GET /api/gifts/inventory/current
  // ───────────────────────────────────────────────────────────────────────────
  Future<List<GiftInventoryItem>> getCurrentInventory() async {
    try {
      final baseUrl = await _resolveBaseUrl();
      final headers = await _getHeaders();
      final employeeId = await _resolveEmployeeId();
      final url = _buildUrl(baseUrl, '/api/gifts/inventory/current');

      final queryParams = <String, dynamic>{};
      if (employeeId != null) {
        queryParams['employee_id'] = employeeId.toString();
      }

      debugPrint('[GiftApiService] GET current inventory with employee_id: $employeeId (URL: $url)');

      final response = await _dio.get(
        url,
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      dynamic rawData = response.data;
      if (rawData is String) {
        try {
          rawData = jsonDecode(rawData);
        } catch (_) {}
      }

      if (rawData is Map && (rawData['error'] == true || rawData['status'] == 500) && rawData['data'] == null) {
        throw Exception(rawData['message'] ?? 'Failed to load current inventory');
      }

      List<dynamic> list = [];
      if (rawData is List) {
        list = rawData;
      } else if (rawData is Map && rawData['data'] is List) {
        list = rawData['data'];
      } else if (rawData is Map && rawData['inventory'] is List) {
        list = rawData['inventory'];
      }

      return list
          .map((item) => GiftInventoryItem.fromJson(Map<String, dynamic>.from(item is Map ? item : {})))
          .toList();
    } on DioException catch (e) {
      debugPrint('[GiftApiService] getCurrentInventory error: $e');
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      debugPrint('[GiftApiService] getCurrentInventory unexpected error: $e');
      throw Exception('Failed to load current inventory: $e');
    }
  }
}
