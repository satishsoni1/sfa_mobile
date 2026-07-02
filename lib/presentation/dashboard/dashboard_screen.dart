import 'dart:async';
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
  static const String CURRENT_APP_VERSION = "1.0.52";

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
      final webDcrAllowed = employee is Map<String, dynamic>
          ? _flagEnabled(employee['is_web_dcr_allowed'])
          : null;

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
  }

  void _openTabJointWork() async {
    final employeeCode =
        Provider.of<AuthProvider>(context, listen: false,
    ).user?.employeeCode.trim();

    if (employeeCode == null || employeeCode.isEmpty) {
      _showSnack("Employee code not available.");
      return;
    }

    final url = 'https://zorvia.globalspace.in/dcrapproval/$employeeCode';

    await Navigator.pushNamed(
      context,
      InternalWebViewScreen.routeName,
      arguments: InternalWebViewArgs(
        url: url,
         title: 'Tab Joint Work'),
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
        'https://zorvia.globalspace.in/api/approval-links?employee_code=${Uri.encodeComponent(employeeCode)}';

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
    if (zone.contains("1")) return "assets/images/3.png";
    if (zone.contains("2")) return "assets/images/4.png";
    return "assets/images/5.png";
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    const double headerHeight = 340;
    const double cardOverlap = 60;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      drawer: _buildDrawer(user),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: SingleChildScrollView(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVisitsOverview(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                  ],
                ),
              ),
            ],
          ),
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
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 80,
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      _getZoneLogo(user?.division),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text(
                        user?.division ?? "ZONE",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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
                        Icon(Icons.people_outline, color: Colors.blue, size: 22),
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
                              fontSize: 11, color: Colors.grey),
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
                            'DCR\nRequests',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          if (_isFetchingDcrSheet)
                            SizedBox(
                              width: 40,
                              height: 2,
                              child: LinearProgressIndicator(
                                backgroundColor: primaryColor.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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

  Widget _buildQuickActions() {
    final user = Provider.of<AuthProvider>(context).user;
    final canUseWebDcr =
        _attendanceWebDcrAllowed ?? user?.isWebDcrAllowed ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Field Operations"),
        _buildMenuGrid([
          // _MenuAction(
          //   Icons.map,
          //   "Tour Plan",
          //   Colors.teal,
          //   () => _navigateTo(const TourPlanScreen()),
          // ),
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
          if (canUseWebDcr)
            _MenuAction(Icons.medical_services, "Dr. Call", Colors.purple, () {
              if (_isCheckedIn) {
                _navigateTo(const DoctorListScreen());
              } else {
                _showSnack("Please Check In first!");
              }
            }),
          _MenuAction(Icons.medical_services, "Expense", Colors.purple, () {
            _navigateTo(ExpenseSummaryScreen());
          }),

          // --- NEW ACTION FOR CHEMIST CALL ---
          _MenuAction(Icons.storefront, "Daily POBS campaign", Colors.green, () {
            if (_isCheckedIn) {
              // Usually navigates to a ChemistListScreen first, but for now
              // we can mock passing a direct chemist or you can create the list screen next.
              // For demonstration purposes:
              _navigateTo(const ChemistListScreen());
            } else {
              _showSnack("Please Check In first!");
            }
          }),

          if (canUseWebDcr)
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
            "DCR Unlock\nRequest",
            Colors.redAccent,
            () => _navigateTo(const DcrUnlockRequestScreen()),
          ),
        ]),
        const SizedBox(height: 24),

        // _buildSectionTitle("AI Intelligence"),
        // _buildMenuGrid([
        //   _MenuAction(
        //     Icons.auto_awesome,
        //     "AI Insights Hub",
        //     const Color(0xFF4A148C),
        //     () => _navigateTo(const AiHubScreen()),
        //   ),
        //   _MenuAction(
        //     Icons.support_agent,
        //     "Sales Assistant",
        //     const Color(0xFF1565C0),
        //     () => _navigateTo(const AiSalesAssistantScreen()),
        //   ),
        //   _MenuAction(
        //     Icons.trending_up,
        //     "Product Perf.",
        //     const Color(0xFF2E7D32),
        //     () => _navigateTo(const AiProductPerformanceScreen()),
        //   ),
        //   _MenuAction(
        //     Icons.person_search,
        //     "Doctor Review",
        //     const Color(0xFF6A1B9A),
        //     () => _navigateTo(const AiDoctorReviewScreen()),
        //   ),
        // ]),
        // const SizedBox(height: 24),
        _buildSectionTitle("Manager Reporting"),
        _buildMenuGrid([
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
            "DCR Approvals \n(Tab + Web)",
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
        ]),
        const SizedBox(height: 24),

        _buildSectionTitle("Utilities"),
        _buildMenuGrid([
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
            "Support",
            Colors.cyan,
            () => _navigateTo(const SupportScreen()),
          ),
          _MenuAction(
            Icons.settings,
            "Settings",
            Colors.blueGrey,
            _showSettingsSheet,
          ),
        ]),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMenuGrid(List<_MenuAction> actions) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        // Slightly taller cards prevent bottom overflow for longer labels.
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return Column(
          children: [
            InkWell(
              onTap: action.onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: action.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(action.icon, color: action.color, size: 26),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  height: 1.15,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawer(User? user) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, accentColor]),
            ),
            accountName: Text(
              user?.firstName ?? "User",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              user?.division ?? "Employee",
              style: GoogleFonts.poppins(),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                (user?.firstName ?? "U")[0],
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.install_mobile),
            title: const Text("Install App"),
            onTap: _showInstallInstructions,
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text("Help & Support"),
            onTap: () => _navigateTo(const SupportScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text("Change Password"),
            onTap: () =>
                _navigateTo(const ChangePasswordScreen(isForced: false)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: _handleLogout,
          ),
        ],
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
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
                      'DCR Unlock Requests',
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
                        Icon(Icons.notifications_none,
                            size: 52, color: Colors.grey.shade300),
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
    final rawId   = _str('employee_id');
    final employeeName = rawName.trim().isNotEmpty ? rawName.trim() : (rawId.trim().isNotEmpty ? rawId.trim() : 'Unknown');

    final requestType = _str('request_type', 'TAB').toUpperCase();
    final isWeb = requestType == 'WEB';
    final typeLabel = isWeb ? 'Web DCR Unlock Request' : 'Tab DCR Unlock Request';
    final typeColor = isWeb ? Colors.orange.shade700 : Colors.blue.shade700;
    final typeBg    = isWeb ? Colors.orange.shade50  : Colors.blue.shade50;
    final typeIcon  = isWeb ? Icons.language_outlined : Icons.tablet_android_outlined;

    final reason      = _str('request_reason', '—');
    final requestedAt = formatDateTime(_str('requested_at').isEmpty ? null : _str('requested_at'));

    final rawFrom = _str('from_date');
    final rawTo   = _str('to_date');
    final fromDate = rawFrom.isNotEmpty ? formatDateTime(rawFrom) : null;
    final toDate   = rawTo.isNotEmpty   ? formatDateTime(rawTo)   : null;

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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
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
                        horizontal: 8, vertical: 4),
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
