import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:zforce/data/models/visit_report.dart';
import '../models/leave_models.dart' show LeaveBalance;
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Android Emulator uses 10.0.2.2. For Real Device use your PC IP (e.g., 192.168.1.5)
  static const String baseUrl = 'https://zorvia.globalspace.in/api';
  Future<List<dynamic>> getVisitsByDate(String date) async {
    // API Endpoint: /api/visits?date=2026-02-04
    final url = Uri.parse('$baseUrl/app/visits?date=$date');
    final headers = await _getHeaders();

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      // Return the list inside 'data', or empty list if null
      return jsonResponse['data'] ?? [];
    } else {
      throw Exception('Failed to load visits: ${response.body}');
    }
  }

  // --- LOGIN ---
  Future<Map<String, dynamic>> login(String empId, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'), // Adjust endpoint if needed
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': empId, 'password': password}),
      );

      final responseData = jsonDecode(response.body);

      // Check logic based on your JSON structure
      if (response.statusCode == 200 && responseData['error'] == false) {
        // 1. Extract the 'data' object
        final data = responseData['data'];

        // 2. Return the needed parts
        return {
          'token': data['token'],
          'user': data['user'], // This is the raw Map
        };
      } else {
        throw Exception(responseData['message'] ?? 'Login Failed');
      }
    } catch (e) {
      throw Exception('Network Error: $e');
    }
  }

  // --- SAVE SESSION ---
  Future<void> saveSession(String token, User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString(
      'user_data',
      jsonEncode(user.toJson()),
    ); // Save User object as string
  }

  // --- GET SAVED USER ---
  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user_data');
    if (userString != null) {
      return User.fromJson(jsonDecode(userString));
    }
    return null;
  }

  // --- CHECK TOKEN ---
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // --- LOGOUT ---
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // --- AUTH HELPERS ---
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- 1. TOUR PLANS ---
  Future<void> addTourPlan(Map<String, dynamic> tpData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/app/tour-plans'),
      headers: await _getHeaders(),
      body: jsonEncode(tpData),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add TP: ${response.body}');
    }
  }

  // --- 2. LEAVES ---
  Future<void> addLeave(Map<String, dynamic> leaveData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/app/leaves'),
      headers: await _getHeaders(),
      body: jsonEncode(leaveData),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to request leave');
    }
  }

  // --- 3. DOCTORS ---
  Future<List<dynamic>> getDoctors() async {
    final response = await http.get(
      Uri.parse('$baseUrl/app/doctors'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body); // Returns list of doctors
    }
    return [];
  }

  // --- 4. VISITS (REPORTING) ---

  // Submit Single Visit
  Future<void> submitVisit(Map<String, dynamic> visitData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/app/visits'),
      headers: await _getHeaders(),
      body: jsonEncode(visitData),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to save visit');
    }
  }

  // Get Today's Visits (For Daily Summary Screen)
  Future<List<dynamic>> getTodayVisits() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/app/visits/today'),
        headers: await _getHeaders(),
      );

      print("Visits API Body: ${response.body}"); // DEBUG PRINT

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);

        // CASE 1: The API returns a List directly -> [...]
        if (body is List) {
          return body;
        }
        // CASE 2: The API returns a Map with a 'data' key -> {"data": [...]}
        // (This is the most common Laravel format)
        else if (body is Map<String, dynamic>) {
          if (body.containsKey('data') && body['data'] is List) {
            return body['data'];
          } else {
            // Sometimes API returns empty map or error, return empty list to prevent crash
            print("Warning: API returned a Map but 'data' was not a List.");
            return [];
          }
        }
      }
      return [];
    } catch (e) {
      print("Error fetching visits: $e");
      return []; // Return empty list on error to keep app running
    }
  }

  // Final Day Submit
  // Future<void> submitDayFinal() async {
  //   final response = await http.post(
  //     Uri.parse('$baseUrl/app/visits/submit-day'),
  //     headers: await _getHeaders(),
  //   );
  //   if (response.statusCode != 200) {
  //     throw Exception('Failed to submit day');
  //   }
  // }
  // Updated to accept an optional date string (YYYY-MM-DD)
  Future<void> submitDayFinal({String? date}) async {
    // Use your existing baseUrl variable mechanism
    // Ensure the endpoint path matches your Laravel route (e.g., /visits/submit-day)
    final url = Uri.parse('$baseUrl/app/visits/submit-day');
    final headers = await _getHeaders();

    // If date is provided, send it. Otherwise, send empty JSON (backend usually assumes 'today')
    final body = date != null ? json.encode({'date': date}) : json.encode({});

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception('Failed to submit day: ${response.body}');
    }
  }

  // --- DOCTORS ---
  Future<List<dynamic>> searchDoctors(String query) async {
    final uri = Uri.parse(
      '$baseUrl/app/doctors',
    ).replace(queryParameters: {'search': query});
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load doctors');
    }
  }

  Future<void> addDoctor(Map<String, dynamic> doctorData) async {
    // CHANGED TO DYNAMIC
    final response = await http.post(
      Uri.parse('$baseUrl/app/doctors'),
      headers: await _getHeaders(),
      body: jsonEncode(doctorData),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add doctor');
    }
  }

  // --- LEAVES ---
  Future<List<dynamic>> getMyLeaves() async {
    final response = await http.get(
      Uri.parse('$baseUrl/app/leaves'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch leaves');
    }
  }

  Future<List<dynamic>> getProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/app/products'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);

        // CASE 1: API returns a direct List -> [...]
        if (body is List) {
          return body;
        }
        // CASE 2: API returns a Map with a 'data' key -> {"data": [...]}
        // This is what is causing your current error
        else if (body is Map<String, dynamic>) {
          if (body.containsKey('data') && body['data'] is List) {
            return body['data'];
          }
        }
      }
      return [];
    } catch (e) {
      print("Error fetching products: $e");
      return [];
    }
  }

  Future<List<dynamic>> getJointWorkList() async {
    final response = await http.get(
      Uri.parse('$baseUrl/app/team/joint-work'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  // Future<void> applyLeave(Map<String, dynamic> leaveData) async {
  //   // leaveData should match:
  //   // {'start_date': '2026-02-01', 'end_date': '2026-02-02', 'leave_type': 'Sick', 'reason': 'Fever'}
  //   final response = await http.post(
  //     Uri.parse('$baseUrl/app/leaves'),
  //     headers: await _getHeaders(),
  //     body: jsonEncode(leaveData),
  //   );

  //   if (response.statusCode != 201) {
  //     throw Exception('Failed to submit leave request');
  //   }
  // }

  // Get current status on app load (to restore state)
  Future<Map<String, dynamic>> getAttendanceStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/app/attendance/status'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(
        response.body,
      ); // returns {status: "Working", data: {...}}
    }
    return {'status': 'Open'}; // Default fallback
  }

  Future<void> checkIn() async {
    final response = await http.post(
      Uri.parse('$baseUrl/app/attendance/check-in'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) throw Exception('Check-in Failed');
  }

  Future<void> toggleBreak() async {
    final response = await http.post(
      Uri.parse('$baseUrl/app/attendance/break'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) throw Exception('Break Toggle Failed');
  }

  Future<void> checkOut() async {
    final response = await http.post(
      Uri.parse('$baseUrl/app/attendance/check-out'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) throw Exception('Check-out Failed');
  }
  // --- REPORTING ---

  // Submit Single Visit
  Future<void> saveVisit(Map<String, dynamic> visitData) async {
    // visitData should match:
    // {
    //   "doctor_name": "Dr. Smith",
    //   "remarks": "Met",
    //   "worked_with": ["Amit (ASM)"],
    //   "products": [{"name": "Para", "pob": 10, "sample": 0}]
    // }

    final response = await http.post(
      Uri.parse('$baseUrl/app/visits'),
      headers: await _getHeaders(),
      body: jsonEncode(visitData),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to save visit: ${response.body}');
    }
  }

  Future<void> updateVisit(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/app/visits/$id'), // Endpoint: /api/app/visits/{id}
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception("Update failed");
  }

  // --- SPECIALITIES ---
  Future<List<String>> getSpecialities() async {
    // Replace with actual API call if you have one:
    // final response = await http.get(Uri.parse('$baseUrl/specialities'), headers: await _getHeaders());

    // For now, returning a simulated API delay with data
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      "Consulting Physician",
      "Orthopedicians",
      "ENT",
      "Chest Physician",
      "Paediatrician",
      "Gen. Practitioner",
      "Gynaecologist",
      "Cardiologist",
      "Diabetologist", 
      "Endocrinologist",
      "Gen. Surgeon",
      "INTSV/ ANESTH.",
      "PLASTIC SURGEON",
      "BURN SPL.",
      "DIAB. FOOT SUR",
      "HEMATOLOGISTS",
      "PROCTOLOGIST",
      "HEPATOLOGISTS",
      "PED ENDOCRINOLOGIST",
      "ONCO PHY/SUR",
      "NEPHROLOGIST",
      "RHEUMATOLOGIST",
      "NEUROLOGIST",
      "Dentists",
      "GASTRO PHY/SUR",
      "PAIN SPECIALIST",
      "SPINE SURGEON",
      "Others (BAMS / BHMS)"
    ];
  }

  Future<List<VisitReport>> getDoctorHistory(String doctorName) async {
    // Encode the doctor name to handle spaces properly
    final url = Uri.parse(
      '$baseUrl/app/visits/history?doctor_name=${Uri.encodeComponent(doctorName)}',
    );

    try {
      final response = await http.get(url, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Assuming API returns { "data": [ ...list of reports... ] }
        final List<dynamic> historyJson = data['data'];
        return historyJson.map((json) => VisitReport.fromJson(json)).toList();
      } else {
        throw Exception("Failed to load history");
      }
    } catch (e) {
      throw Exception("Network Error: $e");
    }
  }

  Future<List<LeaveBalance>> getLeaveBalances() async {
    final url = Uri.parse('$baseUrl/app/leaves/balances');

    final response = await http.get(
      url,
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Assuming API returns { "balances": [...] }
      final List<dynamic> list = data['balances'];
      return list.map((e) => LeaveBalance.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load balances");
    }
  }
  // --- LEAVE MODULE ---
  
  Future<List<dynamic>> getLeaves() async {
    final url = Uri.parse('$baseUrl/app/leaves');
    
    final response = await http.get(url, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']; // Returns list of leaves
    } else {
      throw Exception("Failed to fetch leaves");
    }
  }

  Future<void> applyLeave(String type, DateTime from, DateTime to, String reason) async {
    
    final url = Uri.parse('$baseUrl/app/leaves/apply');

    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({
        'leave_type': type,
        'from_date': from.toIso8601String().split('T')[0], // YYYY-MM-DD
        'to_date': to.toIso8601String().split('T')[0],
        'reason': reason,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to apply leave: ${response.body}");
    }
  }
  Future<void> submitLeaveRaw(Map<String, dynamic> payload) async {
   
    final url = Uri.parse('$baseUrl/app/leaves'); // Matches Route::post('/leaves', ...)

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(payload), // Encodes the nested 'leave' array correctly
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        // Parse error message from Laravel if available
        final resp = jsonDecode(response.body);
        throw Exception(resp['message'] ?? "Failed to submit leave request");
      }
    } catch (e) {
      throw Exception("Network Error: $e");
    }
  }

  // 2. Get Leave Details (for View Screen)
  Future<Map<String, dynamic>> getLeaveDetails(int id) async {
    
    final url = Uri.parse('$baseUrl/app/leaves/$id'); // Matches Route::get('/leaves/{id}', ...)

    final response = await http.get(
      url,
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      // Laravel returns { "leave": {...}, "details": [...] }
      return jsonDecode(response.body); 
    } else {
      throw Exception("Failed to load leave details");
    }
  }
  // --- CHANGE PASSWORD ---
  
  Future<void> changePassword(String newPassword) async {
    final url = Uri.parse('$baseUrl/app/change-password'); // Ensure this route exists in Laravel

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'new_password': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        final resp = jsonDecode(response.body);
        throw Exception(resp['message'] ?? "Failed to change password");
      }
    } catch (e) {
      throw Exception("Network Error: $e");
    }
  }
}
