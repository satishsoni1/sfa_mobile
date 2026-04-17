import 'dart:io';
import 'dart:convert'; // For utf8.encode
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zforce/core/constants/app_colors.dart';
import 'package:zforce/data/services/api_service.dart';
import 'reports_dashboard_screen.dart'; // For ReportType enum
import 'package:universal_html/html.dart' as html; // 👇 NEW: Safe web HTML access

class HierarchyReportViewScreen extends StatefulWidget {
  final String reportTitle;
  final ReportType reportType;

  const HierarchyReportViewScreen({
    Key? key,
    required this.reportTitle,
    required this.reportType,
  }) : super(key: key);

  @override
  _HierarchyReportViewScreenState createState() =>
      _HierarchyReportViewScreenState();
}

class _HierarchyReportViewScreenState extends State<HierarchyReportViewScreen> {
  final ApiService _apiService = ApiService();

  // State Variables
  String _selectedEmployeeId = 'All Team';
  List<Map<String, String>> _teamMembers = [
    {'id': 'All Team', 'name': 'All Team'},
  ];

  List<dynamic> _reportData = [];
  bool _isLoading = true;
  bool _isError = false;

  DateTime _selectedDate = DateTime.now();
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Fetch Team + Initial Report Data
  Future<void> _initializeData() async {
    try {
      final team = await _apiService.fetchTeamMembers();
      setState(() {
        _teamMembers.addAll(team);
      });
      await _fetchReportData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
      });
      print("Error initializing report: $e");
    }
  }

  // Fetch Data based on Dropdown Selection
  // Fetch Data based on Dropdown Selection & Date
  Future<void> _fetchReportData() async {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    try {
      // Format dates for backend expectations (Adjust formats as needed)
      final String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final String formattedMonth = _selectedMonth.month.toString().padLeft(2, '0');
      final String formattedYear = _selectedMonth.year.toString();

      final data = await _apiService.fetchHierarchyReport(
        widget.reportType.toString(),
        empCode: _selectedEmployeeId,
        // 👇 Pass date or month/year based on ReportType
        date: widget.reportType != ReportType.callAvg ? formattedDate : null,
        month: widget.reportType == ReportType.callAvg ? formattedMonth : null,
        year: widget.reportType == ReportType.callAvg ? formattedYear : null,
      );

      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
      });
      print("Error fetching report data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F9),
      appBar: AppBar(
        title: Text(
          widget.reportTitle,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              if (_reportData.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("No data to export.")),
                );
                return;
              }
              _exportToCsv(); // 👇 Call the export logic
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHierarchyFilter(),
          Expanded(child: _buildReportContent()),
        ],
      ),
    );
  }

  // --- TOP FILTER (DYNAMIC) ---
  // --- TOP FILTER (DYNAMIC) ---
  Widget _buildHierarchyFilter() {
    final bool isMonthlyReport = widget.reportType == ReportType.callAvg;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        children: [
          // 1. Employee Dropdown
          Row(
            children: [
              const Icon(Icons.people_alt_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedEmployeeId,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    items: _teamMembers.map((emp) => DropdownMenuItem(
                          value: emp['id'],
                          child: Text(
                            emp['name']!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedEmployeeId = val);
                        _fetchReportData();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          // 2. Date / Month Picker
          InkWell(
            onTap: () => isMonthlyReport ? _pickMonthYear() : _pickDate(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isMonthlyReport ? Icons.calendar_month : Icons.calendar_today,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isMonthlyReport
                        ? DateFormat('MMMM yyyy').format(_selectedMonth)
                        : DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit_calendar, size: 18, color: Colors.grey),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- DATE PICKER HELPERS ---
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)), // Allow future for Tour Plans
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(primaryColor: AppColors.primary),
        child: child!,
      ),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchReportData();
    }
  }

  Future<void> _pickMonthYear() async {
    // Flutter doesn't have a native "Month only" picker without packages.
    // Opening a standard date picker in "Year" mode is the native workaround.
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year, // Starts in Year/Month view
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(primaryColor: AppColors.primary),
        child: child!,
      ),
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() => _selectedMonth = picked);
      _fetchReportData();
    }
  }

String _formatTourPlanDoctorName(dynamic doctorName) {
    String name = (doctorName ?? '').toString().trim();
    if (name.isEmpty || name == '-') return '';

    name = name.replaceAll(RegExp(r'\s+'), ' ');
    name = name.replaceFirst(
      RegExp(r'^(?:(?:dr|doctor)\.?\s*)+', caseSensitive: false),
      '',
    );
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    final parts = name
        .split(' ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length.isEven && parts.isNotEmpty) {
      final half = parts.length ~/ 2;
      bool sameHalves = true;
      for (int i = 0; i < half; i++) {
        if (parts[i].toLowerCase() != parts[i + half].toLowerCase()) {
          sameHalves = false;
          break;
        }
      }
      if (sameHalves) {
        name = parts.sublist(0, half).join(' ');
      } else {
        name = parts.join(' ');
      }
    } else {
      name = parts.join(' ');
    }

    final String titleCased = name
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ')
        .trim();

    if (titleCased.isEmpty) return '';
    return 'Dr. $titleCased';
  }
  
  // --- EXPORT TO CSV LOGIC (CROSS-PLATFORM) ---
  Future<void> _exportToCsv() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Generating file...")),
      );

      if (_reportData.isEmpty) return;

      // 1. Get Headers from the first map item
      List<String> headers = _reportData.first.keys.toList();
      
      // 2. Build CSV String
      String csv = "${headers.join(',')}\n";
      
      for (var row in _reportData) {
        List<String> rowValues = [];
        for (var key in headers) {
          if(key != 'details' && key != 'daily_details') {
            String val = row[key]?.toString() ?? "";
            val = val.replaceAll('"', '""'); // Escape quotes for CSV safety
            rowValues.add('"$val"'); 
          }
        }
        csv += "${rowValues.join(',')}\n";
      }

      final String fileName = "${widget.reportTitle.replaceAll(' ', '_')}_Export.csv";

      // 3. Platform-Specific Export Logic
      if (kIsWeb) {
        // --- WEB: Trigger a direct browser file download ---
        final bytes = utf8.encode(csv);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        
        // Create an invisible HTML anchor link and "click" it
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
          
        html.Url.revokeObjectUrl(url); // Cleanup memory
        
      } else {
        // --- MOBILE: Write to temp directory and open native share sheet ---
        final directory = await getTemporaryDirectory();
        final path = "${directory.path}/$fileName";
        final File file = File(path);
        await file.writeAsString(csv);

        await Share.shareXFiles([XFile(path)], text: 'Exported ${widget.reportTitle}');
      }
      
    } catch (e) {
      print("Export error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to export data.")),
      );
    }
  }

  // --- REPORT BODY ---
  Widget _buildReportContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_isError) {
      return const Center(
        child: Text("Error loading report data. Please try again."),
      );
    }

    if (_reportData.isEmpty) {
      return const Center(
        child: Text(
          "No records found for the selected filter.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    switch (widget.reportType) {
      case ReportType.callAvg:
        return _buildCallAvgList();
      case ReportType.summary:
        return _buildSummaryList();
      case ReportType.missedCall: // NEW: Handle Missed Call
        return _buildMissedCallList();
      case ReportType.tourPlan:
        return _buildTourPlanList();
      case ReportType.tpDeviation:
        return _buildDeviationList();
      case ReportType.jointWork:
        return _buildJointWorkList();
      default:
        return const Center(child: Text("Report view coming soon."));
    }
  }

  // ---------------------------------------------------------------------------
  // 1. CALL AVERAGE REPORT UI (Fixed Variable Usage)
  // ---------------------------------------------------------------------------
  Widget _buildCallAvgList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reportData.length,
      itemBuilder: (ctx, i) {
        final row = _reportData[i];

        // 1. Extract fields safely
        final String name = row['name']?.toString() ?? 'N/A';
        final String empCode = row['emp_code']?.toString() ?? '-';
        final String designation = row['designation']?.toString() ?? '-';
        final String hq = row['hq']?.toString() ?? '-';
        final String reportingHead = row['reporting_head']?.toString() ?? '-';

        // --- CHECK BOTH OLD AND NEW KEYS ---
        final String avg =
            row['call_avg']?.toString() ?? row['avg']?.toString() ?? '0.0';
        final String totalCalls =
            row['total_drs_met']?.toString() ??
            row['total_calls']?.toString() ??
            '0';
        final String fDays =
            row['no_of_days_worked']?.toString() ??
            row['fdays']?.toString() ??
            '0';

        final String leaves = row['leave']?.toString() ?? '0';
        final String deviations = row['deviation']?.toString() ?? '0';

        final bool hasDetails =
            row.containsKey('details') && (row['details'] as List).isNotEmpty;

        return InkWell(
          onTap: () {
            if (hasDetails) {
              _showCallAvgDetailsSheet(context, row);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Detailed visit logs will appear here once the backend API is updated.",
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          child: Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER: NAME & CALL AVG ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            if (empCode != '-')
                              Text(
                                "Emp Code: $empCode",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Avg: $avg", // FIXED: Now uses the 'avg' variable
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // --- EMPLOYEE DETAILS ---
                  Text(
                    "Designation: $designation",
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                  Text(
                    "HQ: $hq",
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                  Text(
                    "Reporting To: $reportingHead",
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),

                  const Divider(height: 24, thickness: 1),

                  // --- METRICS GRID ---
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      // FIXED: These now use the properly extracted variables
                      _dataPoint(
                        "Total Drs Met",
                        totalCalls,
                        color: AppColors.primary,
                      ),
                      _dataPoint("Days Worked", fDays, color: Colors.green),
                      _dataPoint("Leaves", leaves, color: Colors.orange),
                      _dataPoint("Deviations", deviations, color: Colors.red),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      hasDetails
                          ? "Tap to view visit details"
                          : "Update API for Day-wise details",
                      style: TextStyle(
                        fontSize: 11,
                        color: hasDetails ? Colors.grey : Colors.redAccent,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- BOTTOM SHEET FOR CALL AVG DETAILS (WITH PRODUCTS) ---
  void _showCallAvgDetailsSheet(BuildContext context, dynamic rowData) {
    final List details = rowData['details'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // --- SHEET HEADER ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Daily Call Details",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            rowData['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // --- LIST OF DETAILED VISITS ---
              Expanded(
                child: details.isEmpty
                    ? const Center(child: Text("No detailed records found."))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: details.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 32, thickness: 1.5),
                        itemBuilder: (ctx, index) {
                          final item = details[index];
                          final bool isOtherActivity =
                              item['other_activity'] != '-';
                          final List products = item['products'] ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date and Time Row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item['date'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (!isOtherActivity &&
                                      item['visiting_time'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item['visiting_time'],
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Display Activity OR Doctor Details
                              if (isOtherActivity) ...[
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Activity: ${item['other_activity']}",
                                    style: TextStyle(
                                      color: Colors.purple.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  "Dr. ${item['doctor_name']} (${item['qualification']})",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Code/MCL: ${item['doctor_code']}",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],

                              // Products Detailing
                              if (products.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  "Products Detailed:",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: products.map((prod) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            prod['product_name'] ?? 'Unknown',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildProdTag(
                                                "POB",
                                                prod['pob_qty']?.toString() ??
                                                    '0',
                                              ),
                                              const SizedBox(width: 6),
                                              _buildProdTag(
                                                "SMP",
                                                prod['sample_qty']
                                                        ?.toString() ??
                                                    '0',
                                              ),
                                              const SizedBox(width: 6),
                                              _buildProdTag(
                                                "RX",
                                                prod['rx_qty']?.toString() ??
                                                    '0',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],

                              // Remarks
                              if (item['remarks'] != null &&
                                  item['remarks'] != '-') ...[
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '"${item['remarks']}"',
                                        style: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper widget to format the POB/SMP/RX numbers nicely
  Widget _buildProdTag(String label, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: "$label: ",
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: Colors.green.shade800,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reportData.length,
      itemBuilder: (ctx, i) {
        final row = _reportData[i];

        return InkWell(
          onTap: () => _showDailyDetailsSheet(context, row),
          child: Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TOP HEADER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          row['name']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          "Code: ${row['emp_code'] ?? 'N/A'}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // --- GEOGRAPHY INFO ---
                  Text(
                    "${row['designation'] ?? 'N/A'}  •  HQ: ${row['hq'] ?? 'N/A'}",
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "Zone: ${row['zone'] ?? 'N/A'}  |  State: ${row['state'] ?? 'N/A'}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),

                  const Divider(height: 24, thickness: 1),

                  // --- METRICS GRID ---
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      _dataPoint(
                        "Total Calls",
                        row['total_calls']?.toString() ?? '0',
                        color: AppColors.primary,
                      ),
                      _dataPoint(
                        "Field Days",
                        row['no_of_days_call']?.toString() ?? '0',
                        color: Colors.green,
                      ),
                      _dataPoint(
                        "Leaves",
                        row['leaves']?.toString() ?? '0',
                        color: Colors.orange,
                      ),
                      _dataPoint(
                        "Meetings",
                        row['meetings']?.toString() ?? '0',
                        color: Colors.purple,
                      ),
                      _dataPoint(
                        "Conferences",
                        row['conferences']?.toString() ?? '0',
                        color: Colors.blue,
                      ),
                      _dataPoint(
                        "Deviations",
                        row['deviations']?.toString() ?? '0',
                        color: Colors.red,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      "Tap to view day-wise details",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- NEW: BOTTOM SHEET FOR DAILY DETAILS ---
  void _showDailyDetailsSheet(BuildContext context, dynamic rowData) {
    final List dailyDetails = rowData['daily_details'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height:
              MediaQuery.of(context).size.height * 0.7, // Takes 70% of screen
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Sheet Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Day-Wise Details",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          rowData['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // List of Daily Records
              Expanded(
                child: dailyDetails.isEmpty
                    ? const Center(child: Text("No daily activities recorded."))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: dailyDetails.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (ctx, index) {
                          final day = dailyDetails[index];
                          bool isFieldWork = day['activity']
                              .toString()
                              .contains('Field Work');

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isFieldWork
                                    ? Colors.green.shade50
                                    : Colors.purple.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFieldWork
                                    ? Icons.medical_services_outlined
                                    : Icons.event_note,
                                color: isFieldWork
                                    ? Colors.green
                                    : Colors.purple,
                              ),
                            ),
                            title: Text(
                              day['date'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              day['activity'] ?? '',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            trailing: isFieldWork
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        day['calls']?.toString() ?? '0',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        "Calls",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 5. MISSED CALL REPORT UI
  // ---------------------------------------------------------------------------
  Widget _buildMissedCallList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reportData.length,
      itemBuilder: (ctx, i) {
        final row = _reportData[i];

        final String name = row['name']?.toString() ?? 'N/A';
        final String empCode = row['emp_code']?.toString() ?? '-';
        final String designation = row['designation']?.toString() ?? '-';
        final String hq = row['hq']?.toString() ?? '-';
        final String totalMissed = row['total_missed']?.toString() ?? '0';

        final bool hasDetails =
            row.containsKey('details') && (row['details'] as List).isNotEmpty;

        return InkWell(
          onTap: () {
            if (hasDetails) {
              _showMissedCallDetailsSheet(context, row);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("No missed calls for this employee."),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          },
          child: Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              "Emp Code: $empCode",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            totalMissed,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.alertRed,
                            ),
                          ),
                          const Text(
                            "Missed",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Designation: $designation",
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                  Text(
                    "HQ: $hq",
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),

                  const Divider(height: 24, thickness: 1),
                  Center(
                    child: Text(
                      hasDetails
                          ? "Tap to view missed doctors"
                          : "0 Missed Calls",
                      style: TextStyle(
                        fontSize: 11,
                        color: hasDetails ? Colors.grey : Colors.green,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- BOTTOM SHEET FOR MISSED CALL DETAILS ---
  void _showMissedCallDetailsSheet(BuildContext context, dynamic rowData) {
    final List details = rowData['details'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // HEADER
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.alertRed.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Missed Call Log",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.alertRed,
                            ),
                          ),
                          Text(
                            rowData['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // LIST OF DOCTORS
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: details.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (ctx, index) {
                    final item = details[index];

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Column
                        SizedBox(
                          width: 80,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['date']?.toString().split(' ')[0] ??
                                    '', // "14"
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.alertRed,
                                ),
                              ),
                              Text(
                                (item['date']?.toString().substring(3) ?? '')
                                    .toUpperCase(), // "OCT 2023"
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Details Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Dr. ${item['doctor_name']}",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Code: ${item['pharmaclient_code']}",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                "Qual: ${item['qualification']}  |  Spec: ${item['specialty']}",
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item['area'] ?? 'N/A',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- HELPER FOR DATA POINTS ---
  Widget _dataPoint(
    String label,
    String value, {
    Color color = Colors.black87,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // ===========================================================================
  // 6. TOUR PLAN (TP) REPORT UI
  // ===========================================================================
  Widget _buildTourPlanList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reportData.length,
      itemBuilder: (ctx, i) {
        final row = _reportData[i];
        final String name = row['name']?.toString() ?? 'N/A';
        final String empCode = row['emp_code']?.toString() ?? '-';
        final String hq = row['hq']?.toString() ?? '-';
        final String totalPlanned = row['total_planned']?.toString() ?? '0';
        final bool hasDetails =
            row.containsKey('details') && (row['details'] as List).isNotEmpty;

        return InkWell(
          onTap: () => hasDetails ? _showTpDetailsSheet(context, row) : null,
          child: Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            "Code: $empCode | HQ: $hq",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      _dataPoint(
                        "Planned",
                        totalPlanned,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const Divider(),
                  Center(
                    child: Text(
                      hasDetails ? "Tap for TP Details" : "No Plans",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTpDetailsSheet(BuildContext context, dynamic rowData) {
    final List details = rowData['details'] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.primary.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tour Plan Log\n${rowData['name']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: details.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, index) {
                  final item = details[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['date'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_formatTourPlanDoctorName(item['doctor_name']).isNotEmpty)
                        Text(
                          _formatTourPlanDoctorName(item['doctor_name']),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      if (item['activity'] != '-')
                        Text(
                          "Activity: ${item['activity']}",
                          style: const TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Text(
                        "Area/Loc: ${item['location']}",
                        style: const TextStyle(color: Colors.black87),
                      ),
                      if (item['remarks'] != '-')
                        Text(
                          "Rem: ${item['remarks']}",
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 7. TP DEVIATION UI
  // ===========================================================================
  Widget _buildDeviationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reportData.length,
      itemBuilder: (ctx, i) {
        final row = _reportData[i];
        final bool hasDetails =
            row.containsKey('details') && (row['details'] as List).isNotEmpty;

        return InkWell(
          onTap: () =>
              hasDetails ? _showDeviationDetailsSheet(context, row) : null,
          child: Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Colors.red, width: 4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['name'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "HQ: ${row['hq']}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  _dataPoint(
                    "Deviations",
                    row['total_deviations']?.toString() ?? '0',
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeviationDetailsSheet(BuildContext context, dynamic rowData) {
    final List details = rowData['details'] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Deviations\n${rowData['name']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: details.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, index) {
                  final item = details[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item['date'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            "Status: D",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.cancel, color: Colors.red, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Planned: ${item['tp_location']}",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Actual: ${item['actual_location']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 8. JOINT WORK UI
  // ===========================================================================
  Widget _buildJointWorkList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reportData.length,
      itemBuilder: (ctx, i) {
        final row = _reportData[i];
        final bool hasDetails =
            row.containsKey('details') && (row['details'] as List).isNotEmpty;

        return InkWell(
          onTap: () =>
              hasDetails ? _showJointWorkDetailsSheet(context, row) : null,
          child: Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['name'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "HQ: ${row['hq']}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  _dataPoint(
                    "Joint Visits",
                    row['total_joint_visits']?.toString() ?? '0',
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showJointWorkDetailsSheet(BuildContext context, dynamic rowData) {
    final List details = rowData['details'] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Joint Work\n${rowData['name']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: details.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, index) {
                  final item = details[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(
                        Icons.handshake,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item['date'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "With: ${item['worked_with']}",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (item['remarks'] != '-')
                          Text(
                            '"${item['remarks']}"',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
