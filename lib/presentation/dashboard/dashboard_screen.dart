import '../tp_deviation/tp_deviation_history_screen.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart'
    as html; // Safe cross-platform HTML handler

// --- SCREENS ---
import 'package:zforce/presentation/chat/chat_screen.dart';
import 'package:zforce/presentation/doctor_list/chemist_list_screen.dart';
import 'package:zforce/presentation/doctor_list/doctor_selection_screen.dart';
import 'package:zforce/presentation/expense/ExpenseScreen.dart';
import 'package:zforce/presentation/expense/ExpenseSummaryScreen.dart';
import 'package:zforce/presentation/expense/ExpenseManagerScreen.dart';
import 'package:zforce/presentation/doctor_brand/doctor_brand_screen.dart';
import 'package:zforce/presentation/leave/leave_list_screen.dart';
import 'package:zforce/presentation/master/data_upload_screen.dart';
import 'package:zforce/presentation/master/attendance_report_screen.dart';
import 'package:zforce/presentation/master/reports_dashboard_screen.dart';
import 'package:zforce/presentation/route_wise_plan/tour_plan_screen.dart';
import 'package:zforce/presentation/sample/SampleDistributionScreen.dart';
import 'package:zforce/presentation/support/support_screen.dart';
import 'package:zforce/presentation/login/change_password_screen.dart';
import 'package:zforce/presentation/login/login_screen.dart';
import 'package:zforce/presentation/login/login_screen.dart';
import '../campaign/campaign_list_screen.dart';
import '../doctor_list/doctor_list_screen.dart';
import '../doctor_list/add_doctor_screen.dart';
import '../doctor_list/doctor_master_screen.dart';
import '../new_dr_master/new_dr_master_screen.dart';
import '../reporting/ManagerJointWorkScreen.dart';
import '../reporting/TeamTerritoryScreen.dart';
import 'external_links_screen.dart';
import '../reporting/daily_report_screen.dart';
import '../reporting/nfw_report_screen.dart';
import '../dcr/dcr_unlock_request_screen.dart';
import '../tour_plan/tour_plan_screen.dart';

// NEW IMPORT FOR CHEMIST REPORTING
import '../reporting/chemist_reporting_screen.dart';
// (Make sure to adjust the import path above to wherever you saved the new file)

// --- CLM MODULE ---
import '../clm/clm_home_screen.dart';
import '../../providers/clm_provider.dart';

// --- AI HUB MODULE ---
import '../ai_hub/ai_hub_screen.dart';
import '../ai_hub/ai_sales_assistant_screen.dart';
import '../ai_hub/ai_product_performance_screen.dart';
import '../ai_hub/ai_doctor_review_screen.dart';

// --- PROVIDERS & SERVICES ---
import '../../providers/report_provider.dart';
import '../../providers/auth_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/user_model.dart';
import '../webview/internal_webview_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // --- APP VERSION (Update this manually before every new build) ---
  static const String CURRENT_APP_VERSION = "1.0.73";

  // --- STATE ---
  bool _isCheckedIn = false;
  DateTime? _checkInTime;
  String _statusText = "Loading...";
  bool _isLoadingAction = false;
  bool _isRefreshing = false;
  bool? _attendanceWebDcrAllowed;

  // Expense Data
  String _expClaimed = "0";
  String _expPending = "0";

  // DCR Requests (notification inbox)
  List<Map<String, dynamic>> _dcrRequests = [];
  bool _isFetchingDcrSheet = false;
  // Execution Report (Mini Card)
  Map<String, dynamic> _executionData = {};
  bool _isFetchingExecution = false;
  DateTimeRange _executionDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)),
    end: DateTime.now(),
  );
  Timer? _timer;
  String _elapsedTime = "00:00";

  // --- COLORS ---
  final Color primaryColor = const Color(0xFF4A148C);
  final Color accentColor = const Color(0xFF7B1FA2);
  final Color bgColor = const Color(0xFFF4F6F9);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) => _updateElapsed(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- LOGIC ---

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);

    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    final apiService = ApiService();

    try {
      // 1. Parallel Data Fetching
      await Future.wait([
        _checkAppVersion(apiService),
        reportProvider.fetchTodayData(),
        _fetchAttendance(apiService),
        _fetchExpenseSummary(apiService),
        _fetchDcrRequests(apiService),
        _fetchExecutionReport(apiService),
      ]);
    } catch (e) {
      if (mounted) setState(() => _statusText = "Offline");
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // --- VERSION CONTROL LOGIC ---
  Future<void> _checkAppVersion(ApiService api) async {
    if (!kIsWeb) return;

    try {
      final serverVersion = await api.getServerAppVersion();

      if (serverVersion != null && serverVersion != CURRENT_APP_VERSION) {
        if (mounted) _showUpdatePopup();
      }
    } catch (e) {
      debugPrint("Version check failed: $e");
    }
  }

  Future<void> _fetchExecutionReport(ApiService api) async {
    if (!mounted) return;
    setState(() => _isFetchingExecution = true);
    try {
      final res = await api.getCallReport(
        startDate: _executionDateRange.start,
        endDate: _executionDateRange.end,
        userId: null,
      );
      if (mounted) {
        setState(() {
          _executionData = res['data'] ?? {};
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch execution report: $e");
    } finally {
      if (mounted) {
        setState(() => _isFetchingExecution = false);
      }
    }
  }

  Future<void> _selectExecutionDate() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _executionDateRange,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,
              maxHeight: 500,
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(colorScheme: ColorScheme.light(primary: primaryColor)),
              child: child!,
            ),
          ),
        );
      },
    );
    if (picked != null && picked != _executionDateRange) {
      setState(() {
        _executionDateRange = picked;
      });
      _fetchExecutionReport(ApiService());
    }
  }

  // --- ACTIONS ---
  void _showUpdatePopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.system_update, color: Colors.blue, size: 28),
              const SizedBox(width: 10),
              const Text(
                "Update Available",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            "A new version of the system has been released. Please refresh the app to clear your cache and apply the latest features.",
            style: TextStyle(color: Colors.black87, height: 1.5),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (kIsWeb) {
                    html.window.location.reload();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  "Refresh App Now",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchAttendance(ApiService api) async {
    try {
      final statusData = await api.getAttendanceStatus();
      if (!mounted) return;
      final status = statusData['status'];
      final data = statusData['data'];
      final employee = statusData['employee'];
      final webDcrAllowed = data is Map<String, dynamic> && data.containsKey('is_web_dcr_allowed')
          ? _flagEnabled(data['is_web_dcr_allowed'])
          : (employee is Map<String, dynamic>
              ? _flagEnabled(employee['is_web_dcr_allowed'])
              : null);

      setState(() {
        if (webDcrAllowed != null) {
          _attendanceWebDcrAllowed = webDcrAllowed;
        }
        if (status == 'Working' || status == 'On Break') {
          _isCheckedIn = true;
          _checkInTime = data != null && data['check_in_time'] != null
              ? DateTime.tryParse(data['check_in_time'].toString())
              : DateTime.now();
          _statusText = "On Duty";
        } else if (status == 'Checked Out') {
          _isCheckedIn = false;
          _checkInTime = null;
          _statusText = "Day Ended";
        } else {
          _isCheckedIn = false;
          _checkInTime = null;
          _statusText = "Not Started";
        }
        _updateElapsed();
      });
    } catch (e) {
      // Handle silently
    }
  }

  bool _flagEnabled(dynamic value) {
    return value == 1 || value == true || value?.toString() == '1';
  }

  Future<void> _fetchDcrRequests(ApiService api) async {
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) return;
      final requests = await api.fetchDcrRequests(employeeId: user.employeeId);
      if (!mounted) return;
      setState(() => _dcrRequests = requests);
    } catch (_) {
      // Silently ignore — notification badge simply stays at 0
    }
  }

  Future<void> _fetchExpenseSummary(ApiService api) async {
    try {
      final data = await api.getMonthlyExpenses(DateTime.now());
      if (!mounted) return;

      final summary = data['summary'];
      setState(() {
        final fmt = NumberFormat("#,##0");
        _expClaimed = fmt.format(summary['total_claimed'] ?? 0);
        _expPending = fmt.format(summary['total_pending'] ?? 0);
      });
    } catch (e) {
      // Handle silently
    }
  }

  void _updateElapsed() {
    if (_isCheckedIn && _checkInTime != null) {
      final duration = DateTime.now().difference(_checkInTime!);
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      setState(() {
        _elapsedTime = "${hours}h ${minutes}m";
      });
    } else {
      setState(() => _elapsedTime = "00:00");
    }
  }

  Future<void> _handleMainAction() async {
    if (_isLoadingAction) return;
    setState(() => _isLoadingAction = true);
    final apiService = ApiService();
    try {
      if (!_isCheckedIn) {
        await apiService.checkIn();
      } else {
        await apiService.checkOut();
      }
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadInitialData(); // Reload all data
    } catch (e) {
      if (mounted) _showSnack("Action failed: $e");
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  void _handleLogout() {
    Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _openTabJointWork() async {
    final employeeCode = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).user?.employeeCode.trim();

    if (employeeCode == null || employeeCode.isEmpty) {
      _showSnack("Employee code not available.");
      return;
    }

    final url = 'https://vodoclm-pro.globalspace.in/dcrapproval/$employeeCode';

    await Navigator.pushNamed(
      context,
      InternalWebViewScreen.routeName,
      arguments: InternalWebViewArgs(url: url, title: 'Joint Work'),
    );
    
    if (mounted) _fetchDcrRequests(ApiService());
  }

  void _openActionCenter() async {
    final employeeCode = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).user?.employeeCode.trim();

    if (employeeCode == null || employeeCode.isEmpty) {
      _showSnack("Employee code not available.");
      return;
    }

    final url =
        'https://vodoclm-pro.globalspace.in/api/approval-links?employee_code=${Uri.encodeComponent(employeeCode)}';

    await Navigator.pushNamed(
      context,
      InternalWebViewScreen.routeName,
      arguments: InternalWebViewArgs(url: url, title: 'Action Center'),
    );

    if (mounted) _fetchDcrRequests(ApiService());
  }

  void _openWebLinks() {
    final employeeCode = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).user?.employeeCode.trim();

    if (employeeCode == null || employeeCode.isEmpty) {
      _showSnack("Employee code not available.");
      return;
    }

    _navigateTo(ExternalLinksScreen(employeeCode: employeeCode));
  }

  String _getZoneLogo(String? division) {
    final zone = division?.toLowerCase() ?? "";
    if (zone.contains("1")) return "assets/images/vodo_clm_new_logo.png";
    if (zone.contains("2")) return "assets/images/vodo_clm_new_logo.png";
    return "assets/images/vodo_clm_new_logo.png";
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    const double headerHeight = 240;
    const double cardOverlap = 60;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      drawer: _buildDrawer(user),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 800;
            if (isDesktop) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    _buildHeaderBackground(user, headerHeight),
                    Container(
                      margin: EdgeInsets.only(
                        top: headerHeight - cardOverlap,
                        left: 32,
                        right: 32,
                      ),
                      child: Column(
                        children: [
                          _buildQuickActions(
                            true,
                            col1Top: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildAttendanceCard(),
                                const SizedBox(height: 24),
                                _buildVisitsOverview(),
                                const SizedBox(height: 24),
                              ],
                            ),
                            col2Top: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildExecutionReportCard(),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            // Mobile Layout
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // HEADER
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      _buildHeaderBackground(user, headerHeight),
                      Container(
                        margin: EdgeInsets.only(
                          top: headerHeight - cardOverlap,
                          left: 20,
                          right: 20,
                        ),
                        child: _buildAttendanceCard(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // BODY
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildVisitsOverview(),
                        const SizedBox(height: 24),
                        _buildExecutionReportCard(),
                        const SizedBox(height: 24),
                        _buildQuickActions(false), // pass false for mobile
                      ],
                    ),
                  ),
                  _buildFooter(),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- WIDGETS ---
  Widget _buildHeaderBackground(User? user, double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, const Color(0xFF6A1B9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  InkWell(
                    onTap: _loadInitialData,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Welcome back,",
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
              ),
              Text(
                user?.firstName ?? "Employee",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isCheckedIn
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: _isCheckedIn ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _statusText.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isCheckedIn
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _isCheckedIn && _checkInTime != null
                ? DateFormat('h:mm a').format(_checkInTime!)
                : "--:--",
            style: GoogleFonts.poppins(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            _isCheckedIn ? "Checked In Time" : "Ready to Start?",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoadingAction ? null : _handleMainAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCheckedIn
                    ? const Color(0xFFEF5350)
                    : const Color(0xFF66BB6A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoadingAction
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isCheckedIn ? "CHECK OUT" : "CHECK IN",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCircle(double value, String label, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 60,
              width: 60,
              child: CircularProgressIndicator(
                value: value / 100,
                backgroundColor: color.withOpacity(0.1),
                color: color,
                strokeWidth: 6,
              ),
            ),
            Text(
              "${value.toInt()}%",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleStat(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          "© 2026 VodoCLM.\nPowered by GlobalSpace Technologies Ltd",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildExecutionReportCard() {
    final summary = _executionData['summary'] ?? {};
    final int plannedVisited = summary['planned_visited'] ?? 0;
    final int unplannedVisited = summary['unplanned_visited'] ?? 0;
    final int frdMet = summary['frd_met'] ?? 0;
    final int kblMet = summary['kbl_met'] ?? 0;
    final int planned = summary['total_planned'] ?? 0;
    final int totalVisited = summary['total_visited'] ?? 0;
    final double productivity = (summary['productivity'] ?? 0).toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "Execution Report",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _selectExecutionDate,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: primaryColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _executionDateRange.start.day ==
                                  _executionDateRange.end.day &&
                              _executionDateRange.start.month ==
                                  _executionDateRange.end.month
                          ? DateFormat(
                              'dd MMM',
                            ).format(_executionDateRange.start).toUpperCase()
                          : _executionDateRange.start.month ==
                                _executionDateRange.end.month
                          ? "${DateFormat('dd').format(_executionDateRange.start)}-${DateFormat('dd MMM').format(_executionDateRange.end)}"
                                .toUpperCase()
                          : "${DateFormat('dd MMM').format(_executionDateRange.start)}-${DateFormat('dd MMM').format(_executionDateRange.end)}"
                                .toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isFetchingExecution)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // PIE CHART
                    Expanded(
                      flex: 5,
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: InteractivePieChart(
                          values: [
                            plannedVisited.toDouble(),
                            unplannedVisited.toDouble(),
                            frdMet.toDouble(),
                            kblMet.toDouble(),
                          ],
                          labels: ["Planned", "Unplanned", "FRD Met", "KBL Met"],
                          colors: [
                            Colors.teal,
                            Colors.orange,
                            Colors.indigo,
                            Colors.purple,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // LEGEND & BADGES (Right side)
                    Expanded(
                      flex: 5,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildExecBadge("KBL Met", kblMet, Colors.purple),
                          const SizedBox(height: 8),
                          _buildExecBadge("FRD Met", frdMet, Colors.indigo),
                          const SizedBox(height: 8),
                          _buildExecBadge("Planned", plannedVisited, Colors.teal),
                          const SizedBox(height: 8),
                          _buildExecBadge("Unplanned", unplannedVisited, Colors.orange),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCircle(productivity, "Productivity", Colors.green),
                    Container(height: 50, width: 1, color: Colors.grey.shade200),
                    _buildSimpleStat(
                      "$totalVisited / $planned",
                      "Executed / Planned",
                      Icons.checklist,
                      Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildExecBadge(String title, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildVisitsOverview() {
    final visitCount = Provider.of<ReportProvider>(context).visitCount;
    final notifCount = _dcrRequests.length;
    return Row(
      children: [
        // ── Visits + Notification card (split 50/50 inside one card) ─────────
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // ── Left half: Visit count ─────────────────────────────────
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          color: Colors.blue,
                          size: 22,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$visitCount',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Visits',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Divider ────────────────────────────────────────────────
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Colors.grey.shade200,
                    indent: 8,
                    endIndent: 8,
                  ),
                  // ── Right half: Notification bell ──────────────────────────
                  Expanded(
                    child: GestureDetector(
                      onTap: _showDcrRequestsSheet,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Bell with red count badge on top-right
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                color: primaryColor,
                                size: 26,
                              ),
                              if (notifCount > 0)
                                Positioned(
                                  top: -6,
                                  right: -8,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      '$notifCount',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Notifications',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_isFetchingDcrSheet)
                            SizedBox(
                              width: 40,
                              height: 2,
                              child: LinearProgressIndicator(
                                backgroundColor: primaryColor.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  primaryColor,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // ── Online card ──────────────────────────────────────────────────────
        _buildSummaryItem(
          'Online',
          _elapsedTime,
          Icons.timer_outlined,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ── DCR Requests bottom sheet ─────────────────────────────────────────────
  Future<void> _showDcrRequestsSheet() async {
    if (_isFetchingDcrSheet) return;
    setState(() => _isFetchingDcrSheet = true);
    // Fetch fresh data every time the bell is tapped
    await _fetchDcrRequests(ApiService());
    if (!mounted) return;
    setState(() => _isFetchingDcrSheet = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DcrRequestsSheet(
        requests: _dcrRequests,
        primaryColor: primaryColor,
        onActionTap: () {
          Navigator.pop(context);
          _openActionCenter();
        },
      ),
    );
  }

  Widget _buildQuickActions(bool isDesktop, {Widget? col1Top, Widget? col2Top}) {
    final user = Provider.of<AuthProvider>(context).user;
    final canUseWebDcr =
        _attendanceWebDcrAllowed ?? user?.isWebDcrAllowed ?? false;
    final fieldOps = [
      _MenuAction(
        Icons.map,
        "Route wise Tour Plan",
        Colors.teal,
        () => _navigateTo(const RouteTourPlanScreen()),
      ),
         // _MenuAction(
          //   Icons.slideshow_outlined,
          //   "VODOCLM",
          //   const Color(0xFF4A148C),
          //   () => Navigator.push(
          //     context,
          //     MaterialPageRoute(
          //       builder: (_) => ChangeNotifierProvider(
          //         create: (_) => ClmProvider(),
          //         child: const ClmHomeScreen(),
          //       ),
          //     ),
          //   ),
          // ),
        _MenuAction(Icons.medical_services, "Dr. Call", Colors.purple, () {
          if (_isCheckedIn) {
            _navigateTo(const DoctorListScreen());
          } else {
            _showSnack("Please Check In first!");
          }
        }),
      _MenuAction(
        Icons.medical_services,
        "Expense",
        Colors.purple,
        () => _navigateTo(ExpenseSummaryScreen()),
      ),
      _MenuAction(Icons.storefront, "Daily POBS campaign", Colors.green, () {
        if (_isCheckedIn) {
          _navigateTo(const ChemistListScreen());
        } else {
          _showSnack("Please Check In first!");
        }
      }),
        _MenuAction(
          Icons.assignment_turned_in,
          "Daily Report",
          Colors.orange,
          () => _navigateTo(const DailyReportScreen()),
        ),
      _MenuAction(
        Icons.business_center,
        "NFW Report",
        Colors.brown,
        () => _navigateTo(const NfwReportScreen()),
      ),
      _MenuAction(
        Icons.lock_open,
        "Requests",
        Colors.redAccent,
        () => _navigateTo(const DcrUnlockRequestScreen()),
      ),
      _MenuAction(
        Icons.edit_road,
        "TP Deviation Request",
        Colors.amber.shade700,
        () => _navigateTo(const TpDeviationHistoryScreen()),
      ),
    ];
    final aiIntel = [
      _MenuAction(
        Icons.auto_awesome,
        "AI Insights Hub",
        const Color(0xFF4A148C),
        () => _navigateTo(const AiHubScreen()),
      ),
      _MenuAction(
        Icons.support_agent,
        "Sales Assistant",
        const Color(0xFF1565C0),
        () => _navigateTo(const AiSalesAssistantScreen()),
      ),
      _MenuAction(
        Icons.trending_up,
        "Product Perf.",
        const Color(0xFF2E7D32),
        () => _navigateTo(const AiProductPerformanceScreen()),
      ),
      _MenuAction(
        Icons.person_search,
        "Doctor Review",
        const Color(0xFF6A1B9A),
        () => _navigateTo(const AiDoctorReviewScreen()),
      ),
    ];
    final managerOps = [
      _MenuAction(
        Icons.groups,
        "Team View",
        Colors.blue,
        () => _navigateTo(const TeamTerritoryScreen()),
      ),
      _MenuAction(
        Icons.bar_chart,
        "Reports",
        Colors.green,
        () => _navigateTo(const ReportsDashboardScreen()),
      ),
     // _MenuAction(
      //   Icons.approval,
      //   "DCR Approvals (web)",
      //   Colors.green,
      //   () => _navigateTo(const ManagerJointWorkScreen()),
      // ),
      _MenuAction(
        Icons.handshake_outlined,
        "DCR Approvals",
        Colors.blue,
        _openTabJointWork,
      ),
      _MenuAction(
        Icons.checklist,
        "Action Center",
        Colors.orange,
        _openActionCenter,
      ),
      _MenuAction(
        Icons.receipt_long,
        "Team Expenses",
        Colors.teal,
        () => _navigateTo(const ExpenseManagerScreen()),
      ),
      _MenuAction(
        Icons.event_available_outlined,
        "Attendance",
        Colors.deepOrange,
        () => _navigateTo(const AttendanceReportScreen()),
      ),
      _MenuAction(Icons.link, "Other Links", Colors.indigo, _openWebLinks),
    ];
    final utilities = [
      _MenuAction(
        Icons.person_search,
        "MCL Updation",
        Colors.deepPurple,
        () => _navigateTo(const NewDrMasterScreen()),
      ),
      _MenuAction(
        Icons.folder_shared,
        "Dr. Master",
        Colors.deepPurple,
        () => _navigateTo(const DoctorMasterScreen()),
      ),
      _MenuAction(
        Icons.medication_outlined,
        "Brand Pathfinder",
        Colors.pink,
        () => _navigateTo(const DoctorBrandScreen()),
      ),
        // _MenuAction(
          //   Icons.business_center,
          //   "Data Upload",
          //   Colors.cyan,
          //   () => _navigateTo(const DataUploadScreen(isManager: true)),
          // ),
          // _MenuAction(
          //   Icons.business_center,
          //   "Doctor Selection",
          //   Colors.cyan,
          //   () => _navigateTo(DoctorSelectionScreen(isManager: true,division: user?.division ?? "",)),
          // ),
          // _MenuAction(
          //   Icons.person_add_alt_1,
          //   "Add Doctor",
          //   Colors.pinkAccent,
          //   () => _navigateTo(const AddDoctorScreen()),
          // ),
      _MenuAction(
        Icons.support_agent,
        "Help & Support",
        Colors.cyan,
        () => _navigateTo(const SupportScreen()),
      ),
      _MenuAction(
        Icons.settings,
        "Settings",
        Colors.blueGrey,
        _showSettingsSheet,
      ),
    ];
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (col1Top != null) col1Top,
                _buildMenuCategoryCard("Field Operations", fieldOps),
                const SizedBox(height: 24),
                _buildMenuCategoryCard("Manager Reporting", managerOps),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (col2Top != null) col2Top,
                _buildMenuCategoryCard("AI Intelligence", aiIntel),
                const SizedBox(height: 24),
                _buildMenuCategoryCard("Utilities", utilities),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMenuCategoryCard("Field Operations", fieldOps),
        const SizedBox(height: 16),
        _buildMenuCategoryCard("Manager Reporting", managerOps),
        const SizedBox(height: 16),
        _buildMenuCategoryCard("AI Intelligence", aiIntel),
        const SizedBox(height: 16),
        _buildMenuCategoryCard("Utilities", utilities),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildMenuCategoryCard(String title, List<_MenuAction> actions) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisExtent:
                    120, // Forces rigid height and avoids aspect ratio stretch on large screens
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return Column(
                  children: [
                    InkWell(
                      onTap: action.onTap,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: action.color.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: action.color.withOpacity(0.1),
                          ),
                        ),
                        child: Icon(action.icon, color: action.color, size: 28),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      action.label,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        height: 1.2,
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
  }

  Widget _buildDrawer(User? user) {
    return Drawer(
      backgroundColor: bgColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, accentColor]),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Text(
                          (user?.firstName ?? "U")[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.firstName ?? "User",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${user?.employeeCode ?? '-'} - ${(user?.division ?? '-').toUpperCase()}",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.designation ?? '-',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDrawerItem(
            icon: Icons.install_mobile,
            title: "Install App",
            onTap: _showInstallInstructions,
          ),
          _buildDrawerItem(
            icon: Icons.support_agent,
            title: "Help & Support",
            onTap: () => _navigateTo(const SupportScreen()),
          ),
          _buildDrawerItem(
            icon: Icons.lock_reset,
            title: "Change Password",
            onTap: () =>
                _navigateTo(const ChangePasswordScreen(isForced: false)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Divider(),
          ),
          _buildDrawerItem(
            icon: Icons.logout,
            title: "Logout",
            color: Colors.red.shade700,
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.black87,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Icon(
            icon,
            color: color == Colors.black87 ? primaryColor : color,
            size: 22,
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            size: 18,
            color: Colors.grey,
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  void _navigateTo(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _fetchDcrRequests(ApiService());
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text("Change Password"),
            onTap: () {
              Navigator.pop(ctx);
              _navigateTo(const ChangePasswordScreen(isForced: false));
            },
          ),
        ],
      ),
    );
  }

  void _showInstallInstructions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Install App"),
        content: const Text(
          "1. Tap Share/Menu.\n2. Select 'Add to Home Screen'.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}

class _MenuAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _MenuAction(this.icon, this.label, this.color, this.onTap);
}

// ─────────────────────────────────────────────────────────────────────────────
// DCR Requests Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _DcrRequestsSheet extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Color primaryColor;
  final VoidCallback onActionTap;
  const _DcrRequestsSheet({
    required this.requests,
    required this.primaryColor,
    required this.onActionTap,
  });
  String _formatDateTime(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso);
      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F6F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A148C).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${requests.length} pending ${requests.length == 1 ? 'request' : 'requests'}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          // ── List ──────────────────────────────────────────────────────────
          Flexible(
            child: requests.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 52,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No pending requests',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    shrinkWrap: true,
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      return _DcrRequestCard(
                        request: req,
                        primaryColor: primaryColor,
                        formatDateTime: _formatDateTime,
                        onTap: onActionTap,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single DCR Request Card
// ─────────────────────────────────────────────────────────────────────────────
class _DcrRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final Color primaryColor;
  final String Function(String?) formatDateTime;
  final VoidCallback onTap;
  const _DcrRequestCard({
    required this.request,
    required this.primaryColor,
    required this.formatDateTime,
    required this.onTap,
  });

  /// Safe string getter — never crashes on dart2js even if value is JS undefined
  String _str(String key, [String fallback = '']) {
    final v = request[key];
    if (v == null) return fallback;
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final rawName = _str('first_name');
    final rawId = _str('employee_id');
    final employeeName = rawName.trim().isNotEmpty
        ? rawName.trim()
        : (rawId.trim().isNotEmpty ? rawId.trim() : 'Unknown');
    final requestType = _str('request_type', 'TAB').toUpperCase();
    String typeLabel;
    Color typeColor;
    Color typeBg;
    IconData typeIcon;
    
    if (requestType == 'TP_DEVIATION') {
      typeLabel = 'TP DEVIATION APPROVAL REQUEST';
      typeColor = Colors.teal.shade700;
      typeBg = Colors.teal.shade50;
      typeIcon = Icons.alt_route;
    } else if (requestType == 'WEB') {
      typeLabel = 'Web DCR Unlock Request';
      typeColor = Colors.orange.shade700;
      typeBg = Colors.orange.shade50;
      typeIcon = Icons.language_outlined;
    } else {
      typeLabel = 'Tab DCR Unlock Request';
      typeColor = Colors.blue.shade700;
      typeBg = Colors.blue.shade50;
      typeIcon = Icons.tablet_android_outlined;
    }
    final reason = _str('request_reason', '—');
    final requestedAt = formatDateTime(
      _str('requested_at').isEmpty ? null : _str('requested_at'),
    );
    final rawFrom = _str('from_date');
    final rawTo = _str('to_date');
    final fromDate = rawFrom.isNotEmpty ? formatDateTime(rawFrom) : null;
    final toDate = rawTo.isNotEmpty ? formatDateTime(rawTo) : null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.04),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: primaryColor.withOpacity(0.12),
                    child: Text(
                      employeeName.isNotEmpty
                          ? employeeName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      employeeName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: typeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeIcon, size: 12, color: typeColor),
                        const SizedBox(width: 4),
                        Text(
                          requestType,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Chevron arrow ──────────────────────────────────────────
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                    size: 22,
                  ),
                ],
              ),
            ),
            // ── Card Body ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeLabel,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    Icons.comment_outlined,
                    'Requested Reason',
                    reason,
                    Colors.grey.shade700,
                  ),
                  if (fromDate != null) ...[
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.calendar_today_outlined,
                      'From Date',
                      fromDate,
                      Colors.grey.shade700,
                    ),
                  ],
                  if (toDate != null) ...[
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.event_outlined,
                      'To Date',
                      toDate,
                      Colors.grey.shade700,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.access_time_outlined,
                    'Requested At',
                    requestedAt,
                    Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

class InteractivePieChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;
  const InteractivePieChart({
    super.key,
    required this.values,
    required this.labels,
    required this.colors,
  });
  @override
  State<InteractivePieChart> createState() => _InteractivePieChartState();
}

class _InteractivePieChartState extends State<InteractivePieChart> {
  int _hoveredIndex = -1;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (details) =>
              _handleInteraction(details.localPosition, constraints.biggest),
          onPanEnd: (_) => setState(() => _hoveredIndex = -1),
          child: MouseRegion(
            onHover: (event) =>
                _handleInteraction(event.localPosition, constraints.biggest),
            onExit: (_) => setState(() => _hoveredIndex = -1),
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: PieChartPainter(
                values: widget.values,
                colors: widget.colors,
                labels: widget.labels,
                hoveredIndex: _hoveredIndex,
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleInteraction(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    // Check if within donut area
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > size.width / 2 || distance < size.width / 3.5) {
      if (_hoveredIndex != -1) setState(() => _hoveredIndex = -1);
      return;
    }
    // Calculate angle (-pi to pi) and shift it so 0 is top (-pi/2)
    double angle = math.atan2(dy, dx);
    angle += math.pi / 2; // Shift so top is 0
    if (angle < 0) angle += 2 * math.pi;
    double total = widget.values.fold(0, (sum, item) => sum + item);
    if (total == 0) return;
    double startAngle = 0;
    for (int i = 0; i < widget.values.length; i++) {
      if (widget.values[i] == 0) continue;
      final sweepAngle = (widget.values[i] / total) * 2 * math.pi;
      if (angle >= startAngle && angle <= startAngle + sweepAngle) {
        if (_hoveredIndex != i) setState(() => _hoveredIndex = i);
        return;
      }
      startAngle += sweepAngle;
    }
  }
}

class PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final List<String> labels;
  final int hoveredIndex;
  PieChartPainter({
    required this.values,
    required this.colors,
    required this.labels,
    required this.hoveredIndex,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final innerRadius = size.width / 3.5;
    double total = values.fold(0, (sum, item) => sum + item);
    if (total == 0) {
      // Draw empty circle if all values are 0
      final paint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);
      _drawCenterText(
        canvas,
        center,
        innerRadius,
        "No Data",
        "0",
        Colors.grey.shade700,
      );
      return;
    }
    double startAngle = -math.pi / 2; // Start from top (-90 degrees)
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    String? centerLabel;
    String? centerValue;
    Color? centerColor;
    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweepAngle = (values[i] / total) * 2 * math.pi;
      final isHovered = hoveredIndex == i;
      if (isHovered) {
        centerLabel = labels[i];
        centerValue = values[i].toInt().toString();
        centerColor = colors[i];
      }
      // If hovered, expand the radius slightly
      final currentRect = isHovered
          ? Rect.fromCenter(
              center: center,
              width: size.width + 10,
              height: size.height + 10,
            )
          : rect;
      final paint = Paint()
        ..color = isHovered ? colors[i] : colors[i].withOpacity(0.9)
        ..style = PaintingStyle.fill;
      canvas.drawArc(currentRect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }
    // Draw a white circle in the middle to make it a donut chart
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, centerPaint);
    if (centerLabel != null && centerValue != null && centerColor != null) {
      _drawCenterText(
        canvas,
        center,
        innerRadius,
        centerLabel,
        centerValue,
        centerColor,
      );
    } else {
      _drawCenterText(
        canvas,
        center,
        innerRadius,
        "Total",
        total.toInt().toString(),
        Colors.black87,
      );
    }
  }

  void _drawCenterText(
    Canvas canvas,
    Offset center,
    double innerRadius,
    String label,
    String value,
    Color color,
  ) {
    // Value Text (big number)
    final valueSpan = TextSpan(
      text: value,
      style: GoogleFonts.poppins(
        color: color,
        fontSize: innerRadius * 0.6,
        fontWeight: FontWeight.bold,
      ),
    );
    final valuePainter = TextPainter(
      text: valueSpan,
      textDirection: ui.TextDirection.ltr,
    );
    valuePainter.layout();
    // Label Text (small name)
    final labelSpan = TextSpan(
      text: label,
      style: GoogleFonts.poppins(
        color: Colors.grey.shade600,
        fontSize: innerRadius * 0.25,
        fontWeight: FontWeight.w500,
      ),
    );
    final labelPainter = TextPainter(
      text: labelSpan,
      textDirection: ui.TextDirection.ltr,
    );
    labelPainter.layout();
    // Draw value
    valuePainter.paint(
      canvas,
      Offset(
        center.dx - (valuePainter.width / 2),
        center.dy - (valuePainter.height / 2) - (labelPainter.height / 2) + 4,
      ),
    );
    // Draw label
    labelPainter.paint(
      canvas,
      Offset(
        center.dx - (labelPainter.width / 2),
        center.dy + (valuePainter.height / 2) - (labelPainter.height / 2) + 4,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.values != values;
  }
}
