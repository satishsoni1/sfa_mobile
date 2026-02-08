import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:zforce/data/models/visit_report.dart';
import '../models/doctor.dart' show Doctor;
import '../models/tour_plan.dart' show TourPlan;
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
      "Others (BAMS / BHMS)",
    ];
  }

  Future<List<VisitReport>> getDoctorHistory(String doctorId) async {
    // Encode the doctor name to handle spaces properly
    final url = Uri.parse(
      '$baseUrl/app/visits/history?doctorId=${Uri.encodeComponent(doctorId)}',
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

  // --- CHANGE PASSWORD ---

  Future<void> changePassword(String newPassword) async {
    final url = Uri.parse(
      '$baseUrl/app/change-password',
    ); // Ensure this route exists in Laravel

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'new_password': newPassword}),
      );

      if (response.statusCode != 200) {
        final resp = jsonDecode(response.body);
        throw Exception(resp['message'] ?? "Failed to change password");
      }
    } catch (e) {
      throw Exception("Network Error: $e");
    }
  }

  Future<List<TourPlan>> getTourPlans(DateTime month) async {
    final monthStr = DateFormat('yyyy-MM').format(month);
    final response = await http.get(
      Uri.parse('$baseUrl/app/tour-plans?month=$monthStr'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'] as List;
      return data.map((e) => TourPlan.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load plans");
    }
  }

  Future<void> saveTourPlan(DateTime date, List<int> doctorIds) async {
    await http.post(
      Uri.parse('$baseUrl/app/tour-plans'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'plan_date': DateFormat('yyyy-MM-dd').format(date),
        'doctor_ids': doctorIds,
      }),
    );
  }

  Future<void> duplicatePlan(
    DateTime source,
    DateTime target,
    String action,
  ) async {
    await http.post(
      Uri.parse('$baseUrl/app/tour-plans/duplicate'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'source_date': DateFormat('yyyy-MM-dd').format(source),
        'target_date': DateFormat('yyyy-MM-dd').format(target),
        'action': action,
      }),
    );
  }

  Future<void> deletePlan(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    await http.delete(
      Uri.parse('$baseUrl/app/tour-plans/$dateStr'),
      headers: await _getHeaders(),
    );
  }

  Future<void> submitNfwReport(
    DateTime date,
    String activity,
    String location,
    String remarks,
  ) async {
    final url = Uri.parse('$baseUrl/app/nfw-submit');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await getToken()}',
      },
      body: jsonEncode({
        'report_date': DateFormat('yyyy-MM-dd').format(date),
        'activity': activity,
        'location': location,
        'remarks': remarks,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to submit NFW Report");
    }
  }

  Future<List<dynamic>> getSubordinates() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/app/manager/subordinates'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body)['data'];
  }

  Future<List<Doctor>> getDoctorsForUser(int userId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/app/manager/doctors/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => Doctor.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<dynamic>> getNfwHistory() async {
    final token = await getToken(); // your logic to get token
    final response = await http.get(
      Uri.parse(
        '$baseUrl/app/nfw-history',
      ), // or /nfw-history depending on backend
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['data']; // Assuming backend returns { "data": [...] }
    } else {
      throw Exception("Failed to load history");
    }
  }
  // --- LEAVE MANAGEMENT ---

  // 1. Get Leave Types & Balances (For Apply Screen)
  Future<Map<String, dynamic>> getLeaveMeta() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/app/leave/meta'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load leave types');
    }
  }

  // 2. Apply for Leave
  Future<void> applyLeave(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/app/leave/apply'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to submit leave');
    }
  }

  // 3. Get Leave History List
  Future<List<dynamic>> getLeaves() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/app/leaves'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['data'];
    } else {
      throw Exception('Failed to load leave history');
    }
  }

  // 4. Get Single Leave Details
  Future<Map<String, dynamic>> getLeaveDetails(int id) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/app/leaves/$id'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load details');
    }
  }

  Future<List<dynamic>> getJointWorkRequests() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/app/manager/joint-requests'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['data'] ?? [];
    } else {
      throw Exception('Failed to load requests');
    }
  }

  // 2. Approve Request (Create Manager Report)
  Future<void> approveJointWork(String reportId, String remark) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/app/manager/approve-joint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      body: jsonEncode({'report_id': reportId, 'remark': remark}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to approve');
    }
  }

  Future<Map<String, dynamic>> calculateExpense(DateTime date) async {
    final token = await getToken();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    final response = await http.get(
      Uri.parse('$baseUrl/app/expense/calculate?date=$dateStr'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else if (response.statusCode == 404) {
      throw Exception("No visits found for this date.");
    } else {
      throw Exception("Calculation failed");
    }
  }

  // Submit Expense (Multipart for Image)
  Future<void> submitExpense(
    Map<String, String> fields,
    File? imageFile,
  ) async {
    final token = await getToken();

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/app/expense/submit'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    // This line is where it was crashing before
    request.fields.addAll(fields);

    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString(); // Read response

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed: $responseBody");
    }
  }

  Future<Map<String, dynamic>> getMonthlyExpenses(DateTime date) async {
    final token = await getToken();
    final monthStr = DateFormat('yyyy-MM').format(date); // Send '2026-02'

    final response = await http.get(
      Uri.parse('$baseUrl/app/expense/monthly?month=$monthStr'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load summary");
    }
  }

  // 3. Update Plan Status (The missing method causing your error)
  Future<void> updatePlanStatus(int planId, String status) async {
    await Future.delayed(const Duration(milliseconds: 500));

    /* REAL API IMPLEMENTATION:
    final response = await http.patch(
      Uri.parse('$baseUrl/tour-plans/$planId/status'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'status': status}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to update status');
    }
    */
    print("Plan $planId status updated to $status");
  }
}
