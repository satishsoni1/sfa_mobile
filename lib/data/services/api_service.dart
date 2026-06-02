import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
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

  Future<Map<String, dynamic>> loginadmin(String empId, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/loginadmin'), // Adjust endpoint if needed
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
  // Update this method to return 'TourPlan' instead of 'void'
  Future<TourPlan> addTourPlan(Map<String, dynamic> tpData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/app/tour-plans'),
      headers: await _getHeaders(),
      body: jsonEncode(tpData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      // Parse the response to get the ID back from the server
      final data = jsonDecode(response.body);
      // Assuming your API returns the created plan in a 'data' key or directly
      return TourPlan.fromJson(data['data'] ?? data);
    } else {
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
  Future<void> submitDayFinal({String? date, required int chemistCount}) async {
    // Use your existing baseUrl variable mechanism
    // Ensure the endpoint path matches your Laravel route (e.g., /visits/submit-day)
    final url = Uri.parse('$baseUrl/app/visits/submit-day');
    final headers = await _getHeaders();
    final Map<String, dynamic> requestData = {'chemist_count': chemistCount};
    if (date != null) {
      requestData['date'] = date;
    }
    final body = json.encode(requestData);
    // If date is provided, send it. Otherwise, send empty JSON (backend usually assumes 'today')
    // final body = date != null ? json.encode({'date': date}) : json.encode({});

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

  Future<void> updateDoctor(Map<String, dynamic> doctorData) async {
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

  Future<List<dynamic>> getExternalLinks({String? employeeCode}) async {
    // Send employee code to /links so backend can prepare the final URLs.
    final uri = employeeCode == null || employeeCode.isEmpty
        ? Uri.parse('$baseUrl/links')
        : Uri.parse('$baseUrl/links').replace(
            queryParameters: {'employee_code': employeeCode},
          );
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load links');
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

  Future<List<TourPlan>> getTourPlans(DateTime month, {int? userId}) async {
    final monthStr = DateFormat('yyyy-MM').format(month);

    // Construct URL with month
    String url = '$baseUrl/app/tour-plans?month=$monthStr';

    // Append user_id if provided (Manager viewing Subordinate)
    if (userId != null) {
      url += '&user_id=$userId';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'] as List;
      return data.map((e) => TourPlan.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load plans");
    }
  }

  Future<void> saveTourPlan(
    DateTime date,
    List<int> doctorIds, {
    int? userId,
  }) async {
    // 1. Prepare base data
    final Map<String, dynamic> bodyData = {
      'plan_date': DateFormat('yyyy-MM-dd').format(date),
      'doctor_ids': doctorIds,
    };

    // 2. Add userId if planning for a subordinate
    if (userId != null) {
      bodyData['user_id'] = userId;
    }

    // 3. Send Request
    final response = await http.post(
      Uri.parse('$baseUrl/app/tour-plans'),
      headers: await _getHeaders(),
      body: jsonEncode(bodyData),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to save tour plan: ${response.body}');
    }
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

  Uri getMclDoctorCsvExportUri(String employeeCode) {
    return Uri.parse('$baseUrl/export-mcl-dr-list')
        .replace(queryParameters: {'employee_code': employeeCode});
  }

  Future<List<Map<String, String>>> getSubordinatesUpload() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/app/manager/subordinates'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      // Decode the response
      final decoded = jsonDecode(response.body);
      final List<dynamic> data = decoded['data'] ?? [];

      // Map the dynamic list to a strongly typed List<Map<String, String>>
      return List<Map<String, String>>.from(
        data.map(
          (item) => {
            'id': item['id'].toString(),
            'name': item['name'].toString(),
          },
        ),
      );
    } else {
      throw Exception('Failed to load subordinates');
    }
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
// Fetch calculation
Future<Map<String, dynamic>> calculateExpense(String dateStr) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/app/expense/calculate?date=$dateStr'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw "No DCR found for this date.";
      } else {
        throw "Server Error: ${response.statusCode}";
      }
    } catch (e) {
      // Re-throw the error to be caught by the UI
      rethrow;
    }
  }

  // Submit Expense with Image
  // Submit Expense with Image (WEB SAFE)
  Future<void> submitExpense(
    Map<String, String> payload,
    List<PlatformFile> attachments, { // CHANGED: from List<File> to List<PlatformFile>
    List<Map<String, dynamic>> otherItems = const [],
  }) async {
    final token = await getToken();
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/app/expense/submit'));
    
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
    
    request.fields.addAll(payload);
    
    // CHANGED: Use fromBytes for Web compatibility
    for (final file in attachments) {
      if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'attachments[]', 
            file.bytes!, 
            filename: file.name
          ),
        );
      }
    }
    
    // Itemized other expenses (Toll, Courier, Parking, Food Bill, etc.)
    for (var i = 0; i < otherItems.length; i++) {
      final item = otherItems[i];
      request.fields['other_items[$i][type]'] = item['type']?.toString() ?? 'Other';
      request.fields['other_items[$i][amount]'] = item['amount']?.toString() ?? '0';
      
      // CHANGED: Ensure the UI passes a PlatformFile here instead of dart:io File
      final bill = item['bill'] as PlatformFile?; 
      if (bill != null && bill.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'other_bills[$i]', 
            bill.bytes!, 
            filename: bill.name
          ),
        );
      }
    }
    
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw Exception(json.decode(response.body)['message'] ?? 'Failed to submit expense');
    }
  }

  Future<Map<String, dynamic>> getSubordinateMonthlyExpenses(int userId, int month, int year) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/app/expense/subordinate-summary?user_id=$userId&month=$month&year=$year'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load subordinate expenses');
  }

  Future<List<Map<String, dynamic>>> getSubordinateDailyExpenses(int userId, int month, int year) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/app/expense/subordinate-daily?user_id=$userId&month=$month&year=$year'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return List<Map<String, dynamic>>.from(body['data'] ?? []);
    }
    throw Exception('Failed to load subordinate daily expenses');
  }
  Future<void> approveSubordinateExpense(int userId, int month, int year) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/app/expense/approve-month'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json', 'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'month': month, 'year': year}),
    );
    if (response.statusCode != 200) throw Exception(json.decode(response.body)['message'] ?? 'Failed to approve');
  }

  Future<void> rejectSubordinateExpense(int userId, int month, int year, String reason) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/app/expense/reject-month'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json', 'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'month': month, 'year': year, 'reason': reason}),
    );
    if (response.statusCode != 200) throw Exception(json.decode(response.body)['message'] ?? 'Failed to reject');
  }

  Future<List<Map<String, dynamic>>> getBrands({int? userId}) async {
    final token = await getToken();
    final uri = userId != null
        ? Uri.parse('$baseUrl/app/brands?user_id=$userId')
        : Uri.parse('$baseUrl/app/brands');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body)['data'] ?? []);
    }
    throw Exception('Failed to load brands');
  }

  Future<Map<String, dynamic>> getBrandDoctors(int brandId, {int? userId}) async {
    final token = await getToken();
    final uri = userId != null
        ? Uri.parse('$baseUrl/app/brands/$brandId/doctors?user_id=$userId')
        : Uri.parse('$baseUrl/app/brands/$brandId/doctors');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load brand doctors');
  }

  Future<void> addDoctorsToBrand(int brandId, List<int> doctorIds) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/app/brands/$brandId/doctors'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json', 'Content-Type': 'application/json'},
      body: jsonEncode({'doctor_ids': doctorIds}),
    );
    if (response.statusCode != 200) throw Exception(json.decode(response.body)['message'] ?? 'Failed to add doctors');
  }

  Future<void> removeDoctorFromBrand(int brandId, int doctorId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/app/brands/$brandId/doctors/$doctorId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode != 200) throw Exception(json.decode(response.body)['message'] ?? 'Failed to remove doctor');
  }

  Future<void> submitBrandsForApproval() async {
    final token = await getToken();
    final user = await getUser();
    final response = await http.post(
      Uri.parse('$baseUrl/app/brands/submit'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      // Backend receives the logged-in user's id explicitly, matching the brand list fetch.
      body: jsonEncode({'user_id': user?.employeeId}),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Failed to submit brands for approval');
    }
  }

  Future<void> approveBrandList(int userId) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/app/brands/$userId/approve'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Failed to approve brand list');
    }
  }

  Future<void> rejectBrandList(int userId, String reason) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/app/brands/$userId/reject'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Failed to reject brand list');
    }
  }

  Future<List<Map<String, dynamic>>> getMyDoctorList() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/app/doctors/my-list'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body)['data'] ?? []);
    }
    throw Exception('Failed to load doctor list');
  }

// Submit all expenses for the month
  Future<void> submitMonthlyExpense(int month, int year) async {
         final token = await getToken();

    final response = await http.post(
      Uri.parse('$baseUrl/app/expense/submit-month'),
      headers: {
        'Authorization': 'Bearer $token', 
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'month': month,
        'year': year,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(json.decode(response.body)['message'] ?? 'Failed to submit monthly expense');
    }
  }
  Future<Map<String, dynamic>> getMonthlySummary(int month, int year) async {
    var token = await getToken();
  final response = await http.get(
    Uri.parse('$baseUrl/app/expense/monthly-summary?month=$month&year=$year'),
    headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
  );
  if (response.statusCode == 200) return json.decode(response.body);
  throw Exception("Failed to load summary");
}

Future<void> submitFullMonth(int month, int year) async {
    var token = await getToken();
  final response = await http.post(
    Uri.parse('$baseUrl/app/expense/submit-month'),
    headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    body: {'month': month.toString(), 'year': year.toString()},
  );
  if (response.statusCode != 200) throw Exception("Final submission failed");
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

  // ─── Routes ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRoutes() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/app/routes'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body is List ? body : (body['data'] ?? []);
        return List<Map<String, dynamic>>.from(list);
      }
    } catch (_) {}
    return [];
  }

  // ─── Expense Rates (all DA rates by designation) ─────────────────────────────

  Future<Map<String, dynamic>> getAllExpenseRates() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/app/expense/all-rates'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> getCalendarStatus(int month, int year) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/app/expense/calendar-status?month=$month&year=$year'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }
    } catch (_) {}
    return {};
  }

  Future<List<Map<String, dynamic>>> getGstBills(int month, int year, {int? employeeId}) async {
    try {
      final token = await getToken();
      var url = '$baseUrl/app/expense/gst-bills?month=$month&year=$year';
      if (employeeId != null) url += '&employee_id=$employeeId';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return List<Map<String, dynamic>>.from(body['data'] ?? body);
      }
    } catch (_) {}
    return [];
  }

  // ─── Expense TA Routes (expense_rates_ta) ───────────────────────────────────

  Future<Map<String, dynamic>> getTransitFromLocation(String date) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/app/expense/transit-from?date=${Uri.encodeComponent(date)}'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }
    } catch (_) {}
    return {'from_town': '', 'is_hq': true};
  }

  /// Returns {routes: List<Map>, hq_location: String?}
  /// hq_location is from expense_rates_ta.from_town_code or
  /// gst_employee_profile.head_qtr when no TA routes exist.
  Future<Map<String, dynamic>> getTaRoutes() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/app/expense/ta-routes'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final list = body['data'] ?? body;
        return {
          'routes': List<Map<String, dynamic>>.from(
              list is List ? list : []),
          'hq_location': body['hq_location']?.toString(),
        };
      }
    } catch (_) {}
    return {'routes': <Map<String, dynamic>>[], 'hq_location': null};
  }

  // ─── NFW DA Rate (expense_rates by designation) ──────────────────────────────

  Future<Map<String, dynamic>> getNfwDaRate({String type = 'Meeting'}) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/app/expense/nfw-rate?type=${Uri.encodeComponent(type)}'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception(
        json.decode(response.body)['message'] ?? 'Failed to load NFW rate');
  }

  /// POST /app/expense/recalculate-location
  /// Sends explicit from_town + to_town so the server can compute
  /// TA (FIXED / train-slab / km×3.5) and DA (by station_type) for that route.
  /// Returns {da_type, da_amount, total_km, road_km, ta_amount, ta_mode, station_type, from_town, to_town}
  Future<Map<String, dynamic>> recalculateOnLastLocation(
      String date, String fromTown, String toTown,
      {String? nfwType, String? taDirection}) async {
    final token = await getToken();
    final body = <String, dynamic>{
      'date'      : date,
      'from_town' : fromTown,
      'to_town'   : toTown,
    };
    if (nfwType != null && nfwType.isNotEmpty) {
      body['nfw_type'] = nfwType.toLowerCase();
    }
    if (taDirection != null && taDirection.isNotEmpty) {
      body['ta_direction'] = taDirection;
    }
    final response = await http.post(
      Uri.parse('$baseUrl/app/expense/recalculate-location'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception(
        json.decode(response.body)['message'] ?? 'Recalculation failed');
  }

  /// POST /app/expense/recalculate-location
  /// Multi-stop variant: sends all waypoints so the server processes each
  /// segment (A→B, B→C, …) separately and returns aggregated total_km + ta_amount.
  Future<Map<String, dynamic>> recalculateWithWaypoints(
      String date, List<String> waypoints,
      {String? taDirection}) async {
    final token = await getToken();
    final body = <String, dynamic>{
      'date'      : date,
      'from_town' : waypoints.first,
      'to_town'   : waypoints.last,
      'waypoints' : waypoints,
    };
    if (taDirection != null && taDirection.isNotEmpty) {
      body['ta_direction'] = taDirection;
    }
    final response = await http.post(
      Uri.parse('$baseUrl/app/expense/recalculate-location'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception(
        json.decode(response.body)['message'] ?? 'Recalculation failed');
  }

  // ─── Locations Master ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLocations() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/app/locations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body is List ? body : (body['data'] ?? []);
        return List<Map<String, dynamic>>.from(list);
      }
    } catch (_) {}
    return [];
  }

  // ─── New Doctor Master ──────────────────────────────────────────────────────

  Future<List<dynamic>> getNewDoctorMaster({int? userId}) async {
    final token = await getToken();
    final uri = userId != null
        ? Uri.parse('$baseUrl/app/new-doctor-master?user_id=$userId')
        : Uri.parse('$baseUrl/app/new-doctor-master');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body is List ? body : (body['data'] ?? []);
    }
    return [];
  }

  Future<void> addNewDoctor(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/app/new-doctor-master'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Failed to add doctor');
    }
  }

  Future<void> updateNewDoctor(int id, Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/app/new-doctor-master/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Failed to update doctor');
    }
  }

  // ─── Doctor Speciality Targets ───────────────────────────────────────────────

  /// Returns {speciality: {required: int, three_visit_quota: int}}
  Future<Map<String, dynamic>> getDoctorSpecialityTargets() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/app/new-doctor-master/speciality-targets'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, List<String>>> getNewDoctorMasterOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/app/new-doctor-master/options'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body is Map && body['data'] is Map ? body['data'] : body;
        List<String> readList(String key) {
          final raw = data[key];
          if (raw is List) {
            return raw
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
          return <String>[];
        }

        return {
          'specialty_qualifications': readList('specialty_qualifications'),
          'practice_types': readList('practice_types'),
        };
      }
    } catch (e) {
      debugPrint('Error fetching new doctor options: $e');
    }
    return {
      'specialty_qualifications': <String>[],
      'practice_types': <String>[],
    };
  }

  Future<List<String>> getPracticeTypesBySpeciality(String speciality) async {
    try {
      final encoded = Uri.encodeComponent(speciality);
      final response = await http.get(
        Uri.parse('$baseUrl/app/new-doctor-master/practice-types?speciality=$encoded'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final raw = body['data'] ?? body;
        if (raw is List) {
          return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching practice types: $e');
    }
    return [];
  }

  Future<void> updateDoctorVisitCategory(int id, String category) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/app/new-doctor-master/$id/category'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'visit_category': category}),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Failed to update category');
    }
  }

  Future<void> submitDoctorListForApproval() async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/app/new-doctor-master/submit-approval'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Failed to submit for approval');
    }
  }

  Future<void> approveNewDoctorList(int userId) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/app/new-doctor-master/$userId/approve'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Failed to approve list');
    }
  }

  Future<void> rejectNewDoctorList(int userId, String reason) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/app/new-doctor-master/$userId/reject'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Failed to reject list');
    }
  }

  // 3. Update Plan Status (The missing method causing your error)
  Future<void> updatePlanStatus(
    int planId,
    String status, {
    String? remark,
  }) async {
    // 1. Get the current Auth Token
    final token = await getToken();

    final url = Uri.parse('$baseUrl/app/tour-plans/$planId/status');

    // 2. Prepare the Request Body
    final Map<String, dynamic> body = {'status': status};

    // If a remark is provided (e.g., for Rejection), add it to the body
    if (remark != null && remark.isNotEmpty) {
      body['manager_remark'] = remark;
    }

    try {
      final response = await http.patch(
        // or http.post depending on your backend routes
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // standard auth header
        },
        body: json.encode(body),
      );

      // 3. Handle the Response
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Success: Plan $planId updated to $status");
      } else {
        // Parse error message from backend if available
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update plan status');
      }
    } catch (e) {
      debugPrint("API Error: $e");
      throw Exception('Network error: Could not update status');
    }
  }

  Future<List<Doctor>> getDoctorsWithPlanStatus(
    int userId,
    DateTime date,
  ) async {
    final dateStr = date.toIso8601String().split('T').first;

    final response = await http.get(
      Uri.parse('$baseUrl/app/subordinate-doctors-plan/$userId?date=$dateStr'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).map((x) => Doctor.fromJson(x)).toList();
    } else {
      throw Exception('Failed to load doctor plan status');
    }
  }

  Future<void> bulkActionPlan({
    required int planId,
    required String action,
    List<String>? dates,
    String? remark,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/app/tour-plan/bulk-action'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'plan_id': planId,
        'action': action,
        'dates':
            dates, // List of date strings like ['2023-10-12', '2023-10-13']
        'remark': remark,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to perform bulk action: ${response.body}');
    }
  }

  Future<void> sendPasswordResetOtp(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? "Failed to send OTP");
    }
  }

  Future<void> verifyPasswordResetOtp(String email, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? "Invalid OTP");
    }
  }

  Future<void> resetPasswordWithOtp(
    String email,
    String otp,
    String newPassword,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password/reset'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp, 'password': newPassword}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? "Failed to reset password");
    }
  }

  Future<Map<String, dynamic>> getDailyCallReport(
    DateTime date, {
    int? userId,
  }) async {
    try {
      // Format date to YYYY-MM-DD
      final dateString = date.toIso8601String().split('T').first;

      // Build URL with query parameters
      String url = '$baseUrl/app/reports/daily-call?date=$dateString';
      if (userId != null) {
        url += '&user_id=$userId';
      }

      // Fetch from Laravel backend
      final response = await http.get(
        Uri.parse(url),
        headers:
            await _getHeaders(), // Assuming you have a method attaching the Bearer Token
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse['success'] == true) {
          // Return the 'data' object which contains 'summary' and 'details'
          return jsonResponse['data'];
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to load report');
        }
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // Fetch Doctors for Master List (Supports Subordinate Filtering)
  Future<List<dynamic>> getDoctorsMaster({int? userId}) async {
    try {
      String url = '$baseUrl/app/doctors/master';

      // Append the userId to the query string if a subordinate is selected
      if (userId != null) {
        url += '?user_id=$userId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse['data'];
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to load doctors');
        }
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  Future<Map<String, dynamic>> getCallReport({
    required DateTime startDate,
    required DateTime endDate,
    int? userId,
  }) async {
    try {
      // 1. Format dates to string (e.g., "2024-02-20")
      final DateFormat formatter = DateFormat('yyyy-MM-dd');
      final String startStr = formatter.format(startDate);
      final String endStr = formatter.format(endDate);

      // 2. Prepare Query Parameters
      final Map<String, String> queryParams = {
        'start_date': startStr,
        'end_date': endStr,
      };

      // If a subordinate is selected, pass their ID.
      // If null, the backend should assume it's the logged-in user (Myself).
      if (userId != null) {
        queryParams['user_id'] = userId.toString();
      }

      // 3. Construct the full URI
      final uri = Uri.parse(
        '$baseUrl/app/reports/execution',
      ).replace(queryParameters: queryParams);

      // 4. Make the HTTP GET request
      final response = await http.get(uri, headers: await _getHeaders());

      // 5. Handle the Response
      if (response.statusCode == 200) {
        // Successfully fetched data
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        // Backend returned an error
        throw Exception(
          'Failed to load report: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      // Catch network errors or parsing errors
      throw Exception('Network or parsing error occurred: $e');
    }
  }

  Future<Map<String, dynamic>> uploadMasterData({
    PlatformFile? doctorFile, // Changed from File to PlatformFile
    PlatformFile? chemistFile, // Changed from File to PlatformFile
    required String assignedTo,
  }) async {
    final uri = Uri.parse('$baseUrl/app/upload-master-data');
    final request = http.MultipartRequest('POST', uri);

    final headers = await _getHeaders();
    request.headers.addAll(headers);

    request.fields['assigned_to'] = assignedTo;

    // Attach Doctor File using BYTES
    if (doctorFile != null && doctorFile.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'doctor_file',
          doctorFile.bytes!,
          filename: doctorFile.name,
        ),
      );
    }

    // Attach Chemist File using BYTES
    if (chemistFile != null && chemistFile.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'chemist_file',
          chemistFile.bytes!,
          filename: chemistFile.name,
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception("Upload failed: ${response.body}");
    }
  }

  Future<Map<String, dynamic>> getUploadedMasterData(
    String assignedToId,
  ) async {
    // Pass the assignedToId as a query parameter
    final url = Uri.parse('$baseUrl/app/master-data?assigned_to=$assignedToId');
    final headers = await _getHeaders();

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load master data');
    }
  }

  // 1. Fetch Team Members for Dropdown (Reportee List)
  Future<List<Map<String, String>>> fetchTeamMembers() async {
    final token = await getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/app/manager/team',
        ), // Adjust if your backend route is different
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as List;
        return data
            .map(
              (e) => {
                // Prefer employee_code for report filters; fallback to id.
                'id': (e['employee_code'] ?? e['emp_code'] ?? e['id'])
                    .toString(),
                'name': e['name'].toString(),
                'employee_code':
                    (e['employee_code'] ?? e['emp_code'] ?? e['id']).toString(),
                'designation': (e['designation'] ?? '').toString(),
                'head_qtr': (e['head_qtr'] ?? e['hq'] ?? '').toString(),
                'hq': (e['hq'] ?? e['head_qtr'] ?? '').toString(),
                'division': (e['division'] ?? '').toString(),
                'zone': (e['zone'] ?? '').toString(),
                'state': (e['state'] ?? '').toString(),
              },
            )
            .toList();
      }
    } catch (e) {
      debugPrint("Error fetching team: $e");
    }
    return [];
  }
/*
  // 2. Fetch Specific Report Data (Call Avg, TP Deviation, Summary, etc.)
  Future<List<dynamic>> fetchHierarchyReport(
  String reportType, {
  String? empCode,
  String? date,  // 👇 NEW: Added date param
  String? month, // 👇 NEW: Added month param
  String? year,  // 👇 NEW: Added year param
}) async {
  final token = await getToken();
  if (token == null) return [];

  // Map the Enum type to the API string type (e.g., ReportType.callAvg -> 'callAvg')
  String apiType = reportType.split('.').last;

  // 1. Construct Base URL
  String baseUrlString = '$baseUrl/app/manager/reports/$apiType';

  // 2. Build Query Parameters Map dynamically
  Map<String, String> queryParams = {};

  if (empCode != null && empCode != 'All Team') {
    queryParams['employee_code'] = empCode;
  }
  if (date != null && date.isNotEmpty) {
    queryParams['date'] = date;
  }
  if (month != null && month.isNotEmpty) {
    queryParams['month'] = month;
  }
  if (year != null && year.isNotEmpty) {
    queryParams['year'] = year;
  }

  // 3. Generate the final safely-encoded URI
  Uri uri = Uri.parse(baseUrlString);
  if (queryParams.isNotEmpty) {
    // This safely handles the '?' and '&' characters for you automatically
    uri = uri.replace(queryParameters: queryParams); 
  }

  try {
    final response = await http.get(
      uri, // 👇 Pass the nicely formatted URI here
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      print("API Error: ${response.statusCode} - ${response.body}");
    }
  } catch (e) {
    print("Error fetching report data: $e");
  }
  return [];
}*/

  // 2. Fetch Specific Report Data (Call Avg, TP Deviation, Summary, pobSummary ,etc.)
  Future<List<dynamic>> fetchHierarchyReport(
    String reportType, {
    String? empCode,
    required String startDate,
    required String endDate,
  }) async {
    final token = await getToken();
    if (token == null) return [];

    final String apiType = reportType.split('.').last;
    final String baseUrlString = '$baseUrl/app/manager/reports-new/$apiType';

    final Map<String, String> queryParams = {};
    if (empCode != null && empCode != 'All Team') {
      queryParams['employee_code'] = empCode;
    }

    queryParams['start_date'] = startDate;
    queryParams['end_date'] = endDate;

    Uri uri = Uri.parse(baseUrlString);
    if (queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    try {
      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['doctor_details'] is List) {
            return decoded['doctor_details'] as List<dynamic>;
          }
          if (decoded['data'] is Map<String, dynamic> &&
              decoded['data']['doctor_details'] is List) {
            return decoded['data']['doctor_details'] as List<dynamic>;
          }
        }
        return _safeExtractList(decoded);
      } else {
        debugPrint("API Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Error fetching report data: $e");
    }
    return [];
  }

  Future<List<dynamic>> fetchVisitSummaryDetail({
    required String employeeCode,
    required String startDate,
    required String endDate,
    required String visitType,
  }) async {
    final token = await getToken();
    if (token == null) return [];

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/app/employee/visit'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'employee_code': employeeCode,
          'start_date': startDate,
          'end_date': endDate,
          'visit_type': visitType,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['doctor_details'] is List) {
            return decoded['doctor_details'] as List<dynamic>;
          }
          if (decoded['data'] is Map<String, dynamic> &&
              decoded['data']['doctor_details'] is List) {
            return decoded['data']['doctor_details'] as List<dynamic>;
          }
        }
        return _safeExtractList(decoded);
      } else {
        print("API Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error fetching doctor selection detail: $e");
    }
    return [];
  }

  List<dynamic> _safeExtractList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded['data'];
      if (data is List) return data;
      if (data is Map<String, dynamic>) {
        if (data['records'] is List) return data['records'] as List<dynamic>;
        if (data['items'] is List) return data['items'] as List<dynamic>;
      }
      if (decoded['records'] is List) return decoded['records'] as List<dynamic>;
      if (decoded['items'] is List) return decoded['items'] as List<dynamic>;
    }
    return [];
  }
  Future<String?> getServerAppVersion() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/app/version'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['version']; // e.g. "1.0.1"
      }
    } catch (e) {
      // Fails silently if offline
      return null;
    }
    return null;
  }

  // Future<List<Map<String, dynamic>>> fetchUserAreas() async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/areas'),
  //       headers: await _getHeaders(),
  //     );
  //     if (response.statusCode == 200) {
  //       final resData = json.decode(response.body);
  //       return List<Map<String, dynamic>>.from(resData['data']);
  //     }
  //   } catch (e) {
  //     debugPrint("Error fetching areas: $e");
  //   }
  //   return [];
  // }

  Future<Map<String, dynamic>?> createArea(
    String areaName,
    String territoryType,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/areas'),
        headers: await _getHeaders(),
        body: json.encode({
          'area_name': areaName,
          'territory_type': territoryType, // SENDING NEW FIELD
        }),
      );
      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        return resData['data'];
      }
    } catch (e) {
      debugPrint("Error creating area: $e");
    }
    return null;
  }

  // GET monthly claims (Internet, Mobile, Hotel, etc.)
  Future<List<dynamic>> getMonthlyClaims(int month, int year) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/app/expense/monthly-claims?month=$month&year=$year'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] ?? [];
    }
    return [];
  }

  // GET Mobile & Internet rates from expense_rates by designation
  Future<Map<String, dynamic>> getMonthlyClaimRates() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/app/expense/claim-rates'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    return {'mobile': 0.0, 'internet': 0.0};
  }

  // DELETE a monthly claim (only allowed before the month is submitted)
  Future<void> deleteMonthlyClaim(int claimId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/app/expense/monthly-claim/$claimId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception(
          json.decode(response.body)['message'] ?? 'Failed to delete claim');
    }
  }

  // DELETE a single daily expense (only allowed before the month is submitted)
  Future<void> deleteExpense(int expenseId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/app/expense/$expenseId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception(
          json.decode(response.body)['message'] ?? 'Failed to delete expense');
    }
  }

  // POST add a monthly claim — amount auto-fetched server-side for Mobile/Internet
  // POST add a monthly claim (WEB SAFE)
  Future<void> addMonthlyClaim({
    required int month,
    required int year,
    required String claimType,
    double? amount,
    PlatformFile? bill, // CHANGED: from File to PlatformFile
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/app/expense/monthly-claim'),
    );
    
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
    
    request.fields['month'] = month.toString();
    request.fields['year'] = year.toString();
    request.fields['claim_type'] = claimType;
    
    if (amount != null) {
      request.fields['amount'] = amount.toString();
    }

    // CHANGED: Use fromBytes for Web compatibility
    if (bill != null && bill.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'bill', 
          bill.bytes!, 
          filename: bill.name
        )
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          json.decode(response.body)['message'] ?? 'Failed to add claim');
    }
  }

  Future<bool> saveAreaTourPlan(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tour-plan/save'),
        headers: await _getHeaders(),
        body: json.encode(payload),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error saving plan: $e");
      return false;
    }
  }


  Future<bool> bulkActionAreaPlan({
    required String action, // 'Approved' or 'Rejected'
    required List<String> dates,
    String? remark,
    required int targetUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tour-plan/bulk-action'),
        headers: await _getHeaders(),
        body: json.encode({
          'action': action,
          'dates': dates,
          'remark': remark,
          'user_id': targetUserId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error in bulk action: $e");
      return false;
    }
  }

  Future<List<dynamic>> getChemists({int? userId}) async {
    try {
      String url = '$baseUrl/app/chemists';
      if (userId != null) {
        url += '?user_id=$userId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        return resData['data'];
      }
    } catch (e) {
      debugPrint("Error fetching chemists: $e");
    }
    return [];
  }

  Future<bool> addChemist(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/app/chemists/add',
        ), // Adjust endpoint to match Laravel
        headers: await _getHeaders(),
        body: json.encode(payload),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("Error adding chemist: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getDoctorBrandSummary({int? userId}) async {
    try {
      final token = await getToken();
      final uri = userId != null
          ? Uri.parse('$baseUrl/app/brands/doctor-summary?user_id=$userId')
          : Uri.parse('$baseUrl/app/brands/doctor-summary');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final raw = body['data'] ?? body;
        if (raw is List) return List<Map<String, dynamic>>.from(raw);
      }
    } catch (e) {
      debugPrint('Error fetching doctor brand summary: $e');
    }
    return [];
  }

  Future<bool> updateChemist(Map<String, dynamic> payload) async {
    try {
      final String chemistId = payload['id'];
      final response = await http.post(
        Uri.parse(
          '$baseUrl/app/chemists/update/$chemistId',
        ), // Adjust endpoint to match Laravel
        headers: await _getHeaders(),
        body: json.encode(payload),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error updating chemist: $e");
      return false;
    }
  }

  Future<bool> saveChemistVisit(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/app/chemist-reports/save'),
        headers: await _getHeaders(),
        body: json.encode(payload),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error saving chemist report: $e");
      return false;
    }
  }

  Future<List<dynamic>> getChemistVisitsByDate(String date) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/app/chemist-reports/date?date=$date'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['data'];
      }
    } catch (e) {
      debugPrint("Error fetching chemist reports: $e");
    }
    return [];
  }

  Future<List<dynamic>> getChemistHistory(String chemistId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/app/chemists/$chemistId/history'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        return resData['data'] ?? [];
      }
    } catch (e) {
      debugPrint("Error fetching chemist history: $e");
    }
    return [];
  }
  // Add this to your ApiService class
  Future<bool> saveDoctorSelection({
    required int? subordinateId, // Null if saving for self
    required Map<int, String> selections,
  }) async {
    try {
      // Convert the Map<int, String> to a list of objects for the API
      final List<Map<String, dynamic>> selectionPayload = selections.entries.map((e) => {
        'doctor_id': e.key,
        'category': e.value, // 'CORE_3', 'FRD_2', 'KBL'
      }).toList();

      // UNCOMMENT AND UPDATE WITH YOUR ACTUAL HTTP CALL
      final response = await http.post(
        Uri.parse('$baseUrl/app/save-doctor-selection'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'subordinate_id': subordinateId, // Backend should use Auth user if this is null
          'selections': selectionPayload,
        }),
      );

      if (response.statusCode == 200) return true;
      return false;
      
      // Mocking success for now
      // await Future.delayed(const Duration(seconds: 1));
      // return true;
    } catch (e) {
      debugPrint("Error saving selections: $e");
      return false;
    }
  }
  Future<bool> approveDoctorSelection({required int subordinateId}) async {
    
    final url = Uri.parse('$baseUrl/app/approve-doctor-selection');

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'subordinate_id': subordinateId}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint("Failed to approve: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("API Error (approveDoctorSelection): $e");
      return false;
    }
  }
 // 1. FETCH MONTHLY PLANS & OVERALL MONTH STATUS
  Future<Map<String, dynamic>> getMonthlyAreaPlans(
    DateTime month, {
    int? userId,
  }) async { 
    try {
      String monthStr = DateFormat('yyyy-MM').format(month);
      // Adjusted to ensure /app/ prefix is used
      String url = '$baseUrl/tour-plan/monthly?month=$monthStr';
      if (userId != null) {
        url += '&user_id=$userId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        // Expecting backend to return { "data": { "month_status": "Pending", "plans": {...} } }
        return Map<String, dynamic>.from(resData['data']);
      }
    } catch (e) {
      debugPrint("Error fetching monthly plans: $e");
    }
    return {};
  }

  // 2. USER SUBMITS ENTIRE MONTH
  Future<bool> submitMonthPlan(DateTime month) async {
    try {
      String monthStr = DateFormat('yyyy-MM').format(month);
      final response = await http.post(
        Uri.parse('$baseUrl/tour-plan/submit-month'),
        headers: await _getHeaders(),
        body: json.encode({'month': monthStr}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error submitting month: $e");
      return false;
    }
  }

  // 3. MANAGER REVIEWS ENTIRE MONTH (Replacing your mock at the bottom)
  Future<bool> reviewMonthPlan({
    required DateTime month, 
    required String action, // 'Approved' or 'Rejected'
    required String remark, 
    required int targetUserId
  }) async { 
    try {
      String monthStr = DateFormat('yyyy-MM').format(month);
      final response = await http.post(
        Uri.parse('$baseUrl/tour-plan/review-month'),
        headers: await _getHeaders(),
        body: json.encode({
          'month': monthStr,
          'action': action,
          'remark': remark,
          'user_id': targetUserId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error reviewing month plan: $e");
      return false;
    }
  }
  Future<List<Map<String, dynamic>>> fetchUserAreas({int? userId}) async {
    try {
      String url = '$baseUrl/areas';
      if (userId != null) {
        url += '?user_id=$userId'; // Pass subordinate ID to Laravel
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        return List<Map<String, dynamic>>.from(resData['data']);
      }
    } catch (e) {
      debugPrint("Error fetching areas: $e");
    }
    return [];
  }
}
