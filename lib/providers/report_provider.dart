import 'package:flutter/material.dart';
import 'package:zforce/data/models/product.dart';
import '../data/services/api_service.dart';
import '../data/models/visit_report.dart'; // Ensure you have this model
import '../data/models/doctor.dart'; // Ensure you have this model
import '../data/models/tour_plan.dart'; // Ensure you have this model

class ReportProvider with ChangeNotifier {
  // Service Injection
  final ApiService _apiService = ApiService();

  // --- STATE VARIABLES ---
  List<VisitReport> _dailyReports = [];
  List<Doctor> _doctors = [];
  List<TourPlan> _tourPlans = [];
  bool _isDaySubmitted = false;
  bool _isLoading = false;

  // --- GETTERS ---
  List<VisitReport> get reports => _dailyReports;
  List<Doctor> get doctors => _doctors;
  List<TourPlan> get tourPlans => _tourPlans;
  bool get isDaySubmitted => _isDaySubmitted;
  bool get isLoading => _isLoading;
  int get visitCount => _dailyReports.length;

  // ===============================================
  // 1. INITIALIZATION & FETCHING
  // ===============================================

  /// Loads today's visits and checks if the day is already submitted
  Future<void> fetchTodayData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch Visits from API
      final List<dynamic> visitData = await _apiService.getTodayVisits();

      // 2. Convert to Model List
      _dailyReports = visitData
          .map((json) => VisitReport.fromJson(json))
          .toList();

      // 3. Check if any report marks the day as submitted
      // (Assuming the API returns an 'is_submitted' flag in the visit object)
      if (_dailyReports.isNotEmpty) {
        // If your API sets 'is_submitted' on individual visits or a separate status endpoint
        // You might check: _isDaySubmitted = _dailyReports.any((r) => r.isSubmitted);
        // For now, let's assume if we have data, we check the first one or a specific API flag
      }
    } catch (e) {
      print("Error fetching daily data: $e");
      // Optionally handle error state
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the doctor list (usually cached or fetched once)
  Future<void> fetchDoctors() async {
    //if (_doctors.isNotEmpty) return; // Don't refetch if we have data
    try {
      final List<dynamic> doctorData = await _apiService.getDoctors();
      _doctors = doctorData.map((json) => Doctor.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      print("Error fetching doctors: $e");
    }
  }

  // ===============================================
  // 2. REPORTING LOGIC (VISITS)
  // ===============================================
  // ===============================================
  // 2. REPORTING ACTIONS
  // ===============================================

  /// RENAMED: Checks if the doctor exists in the CURRENTLY LOADED list.
  /// Since '_dailyReports' is refreshed when you change the date,
  /// this logic automatically allows the same doctor on different dates.
  bool hasVisitForSelectedDate(String doctorName) {
    return _dailyReports.any((r) => r.doctorName == doctorName);
  }

  Future<void> addReport(VisitReport report, {DateTime? selectedDate}) async {
   // if (_isDaySubmitted) throw Exception("Day is locked.");

    // Check locally
    if (hasVisitForSelectedDate(report.doctorName)) {
      throw Exception("Report already exists for this date.");
    }

    try {
      // Create a map to send to API
      Map<String, dynamic> data = report.toJson();

      // Explicitly add the date if we are backdating
      if (selectedDate != null) {
        data['date'] = selectedDate.toIso8601String().split('T')[0];
      }

      await _apiService.saveVisit(data);

      // Refresh list to sync ID and details
      if (selectedDate != null) {
        await fetchReportsByDate(selectedDate);
      } else {
        await fetchTodayData();
      }
    } catch (e) {
      throw Exception("Failed to save report.");
    }
  }

  /// Update an existing Visit Report
  // Future<void> updateReport(VisitReport updatedReport) async {
  //   if (_isDaySubmitted) throw Exception("Day is locked. Cannot edit.");

  //   try {
  //     // 1. Send Update to API (Assuming you have an update endpoint)
  //     // await _apiService.updateVisit(updatedReport.id, updatedReport.toJson());

  //     // For now, re-saving or handling via specific API logic
  //     // Note: If ID is needed, ensure API supports PUT/PATCH

  //     // 2. Update Local State
  //     final index = _dailyReports.indexWhere((r) => r.id == updatedReport.id);
  //     if (index != -1) {
  //       _dailyReports[index] = updatedReport;
  //       notifyListeners();
  //     }
  //   } catch (e) {
  //     throw Exception("Failed to update report.");
  //   }
  // }

  /// Final Submit - Locks the day
  Future<void> submitDayReports({DateTime? date}) async {
    try {
      String? dateStr;

      // If a specific date is passed, format it to YYYY-MM-DD
      if (date != null) {
        dateStr = date.toIso8601String().split('T')[0];
      }

      // Pass the date string to the API service
      await _apiService.submitDayFinal(date: dateStr);

      _isDaySubmitted = true;
      notifyListeners();
    } catch (e) {
      print("Submit Error: $e");
      throw Exception("Failed to submit final day report.");
    }
  }

  // ===============================================
  // 3. DOCTOR MANAGEMENT
  // ===============================================

  Future<void> addDoctor(Doctor doctor) async {
    try {
      // 1. API Call
      await _apiService.addDoctor(
        doctor.toJson(),
      ); // Ensure Doctor model has toJson()

      // 2. Local Update
      _doctors.add(doctor);
      notifyListeners();
    } catch (e) {
      throw Exception("Failed to add doctor.");
    }
  }

  // ===============================================
  // 4. TOUR PLAN (TP)
  // ===============================================

  Future<void> addTourPlan(TourPlan tp) async {
    try {
      // 1. API Call
      await _apiService.addTourPlan(
        tp.toJson(),
      ); // Ensure TourPlan model has toJson()

      // 2. Local Update
      _tourPlans.add(tp);
      notifyListeners();
    } catch (e) {
      throw Exception("Failed to add Tour Plan.");
    }
  }

  // ===============================================
  // 5. HELPER / DEV TOOLS
  // ===============================================

  void resetDay() {
    _dailyReports.clear();
    _isDaySubmitted = false;
    notifyListeners();
  }

  List<Product> _masterProductList = [];

  List<Product> get masterProducts => _masterProductList;

  // FETCH ACTION
  Future<void> fetchProducts() async {
    if (_masterProductList.isNotEmpty)
      return; // Cache: Don't fetch if already loaded

    try {
      final List<dynamic> data = await _apiService.getProducts();
      _masterProductList = data.map((json) => Product.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      print("Error fetching products: $e");
    }
  }

  List<Map<String, dynamic>> _colleagues = [];
  List<Map<String, dynamic>> get colleagues => _colleagues;

  Future<void> fetchJointWorkList() async {
    // Don't fetch if already loaded (unless you want refresh logic)
    if (_colleagues.isNotEmpty) return;

    try {
      final response = await _apiService
          .getJointWorkList(); // We will create this in ApiService

      // Expected format: [{'name': 'Amit', 'role': 'ASM', 'id': 101}, ...]
      _colleagues = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print("Error fetching team: $e");
    }
  }

  Future<void> updateReport(VisitReport report) async {
    //if (_isDaySubmitted) throw Exception("Day is locked.");

    try {
      // 1. API Call (We need to pass the ID)
      // Ensure your VisitReport model has the correct ID from the API
      await _apiService.updateVisit(report.id!, report.toJson());

      // 2. Local Update
      // Find the index of the report with this ID and replace it
      final index = _dailyReports.indexWhere((r) => r.id == report.id);
      if (index != -1) {
        _dailyReports[index] = report;
        notifyListeners();
      }
    } catch (e) {
      throw Exception("Failed to update report.");
    }
  }

  List<String> _specialities = [];
  List<String> get specialities => _specialities;

  Future<void> fetchSpecialities() async {
    if (_specialities.isNotEmpty) return; // Cache check
    try {
      _specialities = await _apiService.getSpecialities();
      notifyListeners();
    } catch (e) {
      print("Error fetching specs: $e");
    }
  }

  Future<void> fetchReportsByDate(DateTime date) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Format Date to YYYY-MM-DD string for the API
      // Example: 2026-02-04
      String dateStr = date.toIso8601String().split('T')[0];

      // 2. Call the API Service
      // Ensure your ApiService has the 'getVisitsByDate' method defined!
      final List<dynamic> visitData = await _apiService.getVisitsByDate(
        dateStr,
      );

      // 3. Map JSON response to VisitReport models
      _dailyReports = visitData
          .map((json) => VisitReport.fromJson(json))
          .toList();

      // 4. Update "Submitted" Status
      // We check if the reports fetched for this specific date are marked as submitted.
      _isDaySubmitted = false;
      if (_dailyReports.isNotEmpty) {
        // If the first report is submitted, we assume the whole day is locked.
        _isDaySubmitted = _dailyReports.first.isSubmitted;
      }
    } catch (e) {
      print("Error fetching reports for $date: $e");
      // On error (or 404), assume empty list and not submitted
      _dailyReports = [];
      _isDaySubmitted = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
