import 'package:flutter/material.dart';
import 'package:zforce/data/models/chemist_report.dart';
import 'package:zforce/data/models/product.dart';
import '../data/services/api_service.dart';
import '../data/models/visit_report.dart'; // Ensure you have this model
import '../data/models/doctor.dart'; // Ensure you have this model
import '../data/models/tour_plan.dart'; // Ensure you have this model
import '../data/models/chemist.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../data/models/campaign_models.dart';
class ReportProvider with ChangeNotifier {
  // Service Injection
  final ApiService _apiService = ApiService();

  // --- STATE VARIABLES ---
  List<VisitReport> _dailyReports = [];
  List<Doctor> _doctors = [];
  List<Chemist> _chemists = [];
  List<Chemist> get chemists => _chemists;
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

  List<CampaignFieldDefinition> _activeCampaigns = [];
  Map<int, Map<String, dynamic>> _campaignFormValues = {};
  bool _isLoadingCampaigns = false;

  List<CampaignFieldDefinition> get activeCampaigns => _activeCampaigns;
  Map<int, Map<String, dynamic>> get campaignFormValues => _campaignFormValues;
  bool get isLoadingCampaigns => _isLoadingCampaigns;

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
      rethrow;
    }
  }

  Future<void> fetchChemists({int? userId}) async {
    try {
      final List<dynamic> chemistData = await _apiService.getChemists(
        userId: userId,
      );
      _chemists = chemistData.map((json) => Chemist.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      print("Error fetching chemists: $e");
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
      rethrow;
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
  Future<void> submitDayReports({
    DateTime? date,
    required int chemistCount,
    String? chemistRemark,
  }) async {
    try {
      String? dateStr;

      // If a specific date is passed, format it to YYYY-MM-DD
      if (date != null) {
        dateStr = date.toIso8601String().split('T')[0];
      }

      await _apiService.submitDayFinal(
        date: dateStr,
        chemistCount: chemistCount,
        chemistRemark: chemistRemark,
      );

      _isDaySubmitted = true;
      notifyListeners();
    } catch (e) {
      print("Submit Error: $e");
      rethrow;
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

  Future<void> fetchReportsByDate(
    DateTime date, {
    bool showBackendError = false,
  }) async {
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
      if (showBackendError) rethrow;
      _isDaySubmitted = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<ChemistReport> _chemistReports = [];
  List<ChemistReport> get chemistReports => _chemistReports;

  // Checks if chemist already reported today
  bool hasChemistVisitForSelectedDate(String chemistId) {
    return _chemistReports.any((r) => r.chemistId == chemistId);
  }

  // Fetch reports specifically for the current day
  Future<void> fetchTodayChemistData() async {
    await fetchChemistReportsByDate(DateTime.now());
  }

  // Fetch reports for any specific date
  Future<void> fetchChemistReportsByDate(DateTime date) async {
    try {
      String dateStr = date.toIso8601String().split('T')[0];
      final List<dynamic> data = await _apiService.getChemistVisitsByDate(
        dateStr,
      );

      _chemistReports = data
          .map((json) => ChemistReport.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      print("Error fetching chemist reports: $e");
      _chemistReports = [];
      notifyListeners();
    }
  }

  // ===============================================
  // 6. DYNAMIC CAMPAIGN MODULE
  // ===============================================

  Future<void> loadCampaignsForDoctor({
    required String doctorId,
    required DateTime visitDateTime,
  }) async {
    _isLoadingCampaigns = true;
    _activeCampaigns = [];
    _campaignFormValues = {};
    notifyListeners();

    if (doctorId.isEmpty) {
      _isLoadingCampaigns = false;
      notifyListeners();
      return;
    }

    try {
      final String planDate = DateFormat('yyyy-MM-dd').format(visitDateTime);

      // 1. Fetch monthly tour plan
      final monthlyData = await _apiService.getMonthlyAreaPlans(visitDateTime);
      final monthStatus = monthlyData['month_status']?.toString().toLowerCase();

      if (monthStatus == 'approved' && monthlyData['plans'] is Map) {
        final plans = monthlyData['plans'] as Map<String, dynamic>;
        final dayPlan = plans[planDate];

        if (dayPlan is Map && dayPlan['has_campaign'] == true) {
          final campaigns = dayPlan['campaigns'] as List? ?? [];
          final List<int> matchedCampaignIds = [];

          for (final c in campaigns) {
            if (c is! Map) continue;
            final doctors = c['doctors'] as List? ?? [];
            final isAssigned = doctors.any((d) =>
                d is Map && d['doctor_id']?.toString() == doctorId.toString());

            if (isAssigned) {
              final cId = int.tryParse(c['campaign_id']?.toString() ?? '') ?? 0;
              if (cId > 0 && !matchedCampaignIds.contains(cId)) {
                matchedCampaignIds.add(cId);
              }
            }
          }

          if (matchedCampaignIds.isNotEmpty) {
            // 2. Fetch all dynamic field schemas
            final allSchemas = await _apiService.getCampaignAllFields();
            for (final cId in matchedCampaignIds) {
              final schema = allSchemas.firstWhere(
                (s) => s.campaignId == cId,
                orElse: () {
                  final matchedRaw = campaigns.firstWhere(
                    (c) => int.tryParse(c['campaign_id']?.toString() ?? '') == cId,
                    orElse: () => {},
                  );
                  return CampaignFieldDefinition(
                    campaignId: cId,
                    campaignName: matchedRaw['campaign_name']?.toString() ?? 'Campaign $cId',
                    dynamicFields: const [],
                  );
                },
              );
              _activeCampaigns.add(schema);
              _campaignFormValues[cId] = {};
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading campaigns for doctor: $e");
    } finally {
      _isLoadingCampaigns = false;
      notifyListeners();
    }
  }

  void setCampaignFieldValue(int campaignId, String fieldName, dynamic value) {
    _campaignFormValues[campaignId] ??= {};
    _campaignFormValues[campaignId]![fieldName] = value;
    notifyListeners();
  }

  String? validateCampaignFields() {
    for (final campaign in _activeCampaigns) {
      final values = _campaignFormValues[campaign.campaignId] ?? {};
      for (final field in campaign.dynamicFields) {
        if (field.isRequired) {
          final val = values[field.fieldName];
          if (val == null || val.toString().trim().isEmpty) {
            return "Please fill '${field.fieldLabel}' in ${campaign.campaignName.isNotEmpty ? campaign.campaignName : 'Campaign'}";
          }
        }
      }
    }
    return null;
  }

  List<Map<String, dynamic>> buildCampaignDataPayload() {
    if (_activeCampaigns.isEmpty) return const [];

    return _activeCampaigns.map((c) => {
      "campaign_id": c.campaignId,
      "campaign_name": c.campaignName,
      "schema_version": c.schemaVersion ?? "",
      "fields": _campaignFormValues[c.campaignId] ?? {},
    }).toList();
  }

  void restoreCampaignData(dynamic savedData) {
    if (savedData == null) return;
    List<dynamic> list = [];
    if (savedData is List) {
      list = savedData;
    } else if (savedData is String && savedData.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(savedData);
        if (decoded is List) list = decoded;
      } catch (_) {}
    }

    for (final item in list) {
      if (item is Map) {
        final cId = int.tryParse(item['campaign_id']?.toString() ?? '') ?? 0;
        if (cId > 0 && item['fields'] is Map) {
          _campaignFormValues[cId] = Map<String, dynamic>.from(item['fields']);
        }
      }
    }
    notifyListeners();
  }

  void clearCampaignData() {
    _activeCampaigns = [];
    _campaignFormValues = {};
    _isLoadingCampaigns = false;
    notifyListeners();
  }

  // Save the report
  Future<void> addChemistReport(
    ChemistReport report, {
    DateTime? selectedDate,
  }) async {
    // if (hasChemistVisitForSelectedDate(report.chemistId)) {
    //   throw Exception("Report already exists for this chemist on this date.");
    // }

    try {
      Map<String, dynamic> data = {
        'chemist_id': report.chemistId,
        'chemist_name': report.chemistName,
        'doctors': report.doctors,
        'date': selectedDate != null
            ? selectedDate.toIso8601String()
            : report.visitTime.toIso8601String(),
        'remarks': report.remarks,
        'products': report.products
            .map(
              (p) => {
                'name': p.productName,
                'sale': p.saleQty,
                'free': p.freeQty,
                'pob': p.saleQty + p.freeQty,
                'value_pob': p.valuePob,
                'supplied_through': p.suppliedThrough,
              },
            )
            .toList(),
        'worked_with': report.workedWith,
      };
  
     // print(const JsonEncoder.withIndent('  ').convert(data));  
      await _apiService.saveChemistVisit(data);

      // Refresh the list automatically
      if (selectedDate != null) {
        await fetchChemistReportsByDate(selectedDate);
      } else {
        await fetchTodayChemistData();
      }
    } catch (e) {
      rethrow;
    }
  }
}
