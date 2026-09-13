import 'dart:convert';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/statement_detail_model.dart';
import 'package:zforce/features/pod/services/api_client.dart';

// ============================================================
// Statement Detail Service
// Wraps GET /api/pods/{id} and POST /api/pods/{id}/items/{item_id}/map-doctors
// Uses the existing ApiClient (handles auth token + 401 logout).
// ============================================================

class StatementDetailService {
  static final ApiClient _apiClient = ApiClient();

  // ---------------------------------------------------------
  // Fetch full statement detail for a given pod ID
  // ---------------------------------------------------------
  static Future<StatementDetail> fetchDetail(int podId) async {
    try {
      final uri = Uri.parse('${API_BASE_URL}pods/$podId');
      print('[StatementDetailService] Calling: $uri');
      final response = await _apiClient.get(uri);
      print('[StatementDetailService] Status: ${response.statusCode}');
      print('[StatementDetailService] Body: ${response.body.substring(0, response.body.length.clamp(0, 500))}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        if (data == null) {
          throw Exception('No data returned for pod $podId');
        }
        return StatementDetail.fromJson(data);
      } else {
        throw Exception('Failed to load statement (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('[StatementDetailService] Error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------
  // Map doctors to a specific item
  // POST /api/pods/{podId}/items/{itemId}/map-doctors
  // doctorQtyMap: { doctorId -> qty }
  // ---------------------------------------------------------
  static Future<Map<String, dynamic>> mapDoctors(
    int podId,
    int itemId,
    Map<int, double> doctorQtyMap,
  ) async {
    try {
      final uri =
          Uri.parse('${API_BASE_URL}pods/$podId/items/$itemId/map-doctors');

      final body = jsonEncode({
        'doctor_ids': doctorQtyMap.keys.toList(),
        'qty_per_doctor': doctorQtyMap.values.toList(),
      });

      final response = await _apiClient.post(uri, body: body);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message = errorBody?['message'] ?? 'Failed to map doctors';
        throw Exception(message);
      }
    } catch (e) {
      rethrow;
    }
  }
}
