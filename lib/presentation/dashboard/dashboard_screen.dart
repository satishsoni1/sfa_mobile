import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart'
    as html; // Safe cross-platform HTML handler

// --- SCREENS ---
import 'package:zforce/presentation/doctor_list/chemist_list_screen.dart';
import 'package:zforce/presentation/expense/ExpenseSummaryScreen.dart';
import 'package:zforce/presentation/expense/ExpenseManagerScreen.dart';
import 'package:zforce/presentation/doctor_brand/doctor_brand_screen.dart';
import 'package:zforce/presentation/leave/leave_list_screen.dart';
import 'package:zforce/presentation/master/data_upload_screen.dart';
import 'package:zforce/presentation/master/attendance_report_screen.dart';
import 'package:zforce/presentation/master/reports_dashboard_screen.dart';
import 'package:zforce/presentation/route_wise_plan/tour_plan_screen.dart';
import 'package:zforce/presentation/support/support_screen.dart';
import 'package:zforce/presentation/login/change_password_screen.dart';
import '../doctor_list/doctor_list_screen.dart';
import '../doctor_list/doctor_master_screen.dart';
import '../new_dr_master/new_dr_master_screen.dart';
import '../reporting/ManagerJointWorkScreen.dart';
import '../reporting/TeamTerritoryScreen.dart';
import 'external_links_screen.dart';
import '../reporting/daily_report_screen.dart';
import '../reporting/nfw_report_screen.dart';

// --- CLM MODULE ---
import '../clm/clm_home_screen.dart';
import '../../providers/clm_provider.dart';

// --- DATA BANK MODULE ---
import '../data_bank/data_bank_home_screen.dart';

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
  static const String CURRENT_APP_VERSION = "1.0.27";

  bool _isCheckedIn = false;
  DateTime? _checkInTime;
  String _statusText = "Loading...";
  bool _isLoadingAction = false;
  bool _isRefreshing = false;
  bool? _attendanceWebDcrAllowed;

  String _expClaimed = "0";
  String _expPending = "0";

  Timer? _timer;
  String _elapsedTime = "00:00";

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

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);

    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    final apiService = ApiService();

    try {
      await Future.wait([
        _checkAppVersion(apiService),
        reportProvider.fetchTodayData(),
        _fetchAttendance(apiService),
        _fetchExpenseSummary(apiService),
      ]);
    } catch (e) {
      if (mounted) setState(() => _statusText = "Offline");
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

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
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.system_update, color: Colors.blue, size: 28),
              SizedBox(width: 10),
              Text("Update Available", style: TextStyle(fontWeight: FontWeight.bold)),
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
                  if (kIsWeb) html.window.location.reload();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  "Refresh App Now",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
        if (webDcrAllowed != null) _attendanceWebDcrAllowed = webDcrAllowed;
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

  bool _flagEnabled(dynamic value) =>
      value == 1 || value == true || value?.toString() == '1';

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
      setState(() {
        _elapsedTime = "${duration.inHours}h ${duration.inMinutes.remainder(60)}m";
      });
    } else {
      setState(() => _elapsedTime = "--");
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
      await _loadInitialData();
    } catch (e) {
      if (mounted) _showSnack("Action failed: $e");
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  void _handleLogout() =>
      Provider.of<AuthProvider>(context, listen: false).logout();

  void _openTabJointWork() {
    final employeeCode =
        Provider.of<AuthProvider>(context, listen: false).user?.employeeCode
            .trim();

    if (employeeCode == null || employeeCode.isEmpty) {
      _showSnack("Employee code not available.");
      return;
    }
    Navigator.pushNamed(
      context,
      InternalWebViewScreen.routeName,
      arguments: InternalWebViewArgs(
        url: url,
        title: 'Tab Joint Work',
      ),
    );
  }

  void _openWebLinks() {
    final employeeCode =
        Provider.of<AuthProvider>(context, listen: false).user?.employeeCode
            .trim();

    if (employeeCode == null || employeeCode.isEmpty) {
      _showSnack("Employee code not available.");
      return;
    }
    _navigateTo(ExternalLinksScreen(employeeCode: employeeCode));
  }

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final screenWidth = MediaQuery.of(context).size.width;
    final headerHeight = screenWidth < 360 ? 300.0 : 320.0;
    const cardOverlap = 56.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      drawer: _buildDrawer(user),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: _loadInitialData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  _buildHeaderBackground(user, headerHeight),
                  Container(
                    margin: EdgeInsets.only(
                      top: headerHeight - cardOverlap,
                      left: 16,
                      right: 16,
                    ),
                    child: _buildAttendanceCard(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(),
                    const SizedBox(height: 20),
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

  // --- HEADER ---

  Widget _buildHeaderBackground(User? user, double height) {
    final today = DateFormat('EEE, d MMM yyyy').format(DateTime.now());
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Row(
                    children: [
                      if (_isRefreshing)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _loadInitialData,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Welcome text
              Text(
                "Welcome back,",
                style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
              ),
              Text(
                user?.firstName ?? "Employee",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              // Date chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  today,
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ATTENDANCE CARD ---

  Widget _buildAttendanceCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _isCheckedIn ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isCheckedIn ? Colors.green.shade200 : Colors.red.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle,
                    size: 8,
                    color: _isCheckedIn ? Colors.green : Colors.red),
                const SizedBox(width: 6),
                Text(
                  _statusText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _isCheckedIn ? Colors.green.shade700 : Colors.red.shade700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Time display
          Text(
            _isCheckedIn && _checkInTime != null
                ? DateFormat('h:mm a').format(_checkInTime!)
                : "--:--",
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.1,
            ),
          ),
          Text(
            _isCheckedIn ? "Checked In Time" : "Ready to Start?",
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          // Action button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoadingAction ? null : _handleMainAction,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isCheckedIn ? const Color(0xFFEF5350) : const Color(0xFF43A047),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isLoadingAction
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _isCheckedIn ? "CHECK OUT" : "CHECK IN",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STATS ROW ---

  Widget _buildStatsRow() {
    final visitCount = Provider.of<ReportProvider>(context).visitCount;
    return Row(
      children: [
        _buildStatCard("Visits", "$visitCount", Icons.people_outline_rounded, Colors.blue),
        const SizedBox(width: 10),
        _buildStatCard("On Duty", _elapsedTime, Icons.timer_outlined, Colors.orange),
        const SizedBox(width: 10),
        _buildStatCard("Exp.", "₹$_expClaimed", Icons.account_balance_wallet_outlined, Colors.green),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.grey.shade100, blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // --- QUICK ACTIONS ---

  Widget _buildQuickActions() {
    final user = Provider.of<AuthProvider>(context).user;
    final canUseWebDcr = _attendanceWebDcrAllowed ?? user?.isWebDcrAllowed ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Field Operations", Colors.teal),
        _buildMenuGrid([
          _MenuAction(
            Icons.map_outlined,
            "Route Tour Plan",
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
            _MenuAction(
              Icons.medical_services_outlined,
              "Dr. Call",
              Colors.purple,
              () {
                if (_isCheckedIn) {
                  _navigateTo(const DoctorListScreen());
                } else {
                  _showSnack("Please Check In first!");
                }
              },
            ),
          _MenuAction(
            Icons.account_balance_wallet_outlined,
            "Expense",
            Colors.deepOrange,
            () => _navigateTo(ExpenseSummaryScreen()),
          ),
          _MenuAction(
            Icons.storefront_outlined,
            "Daily POBS",
            Colors.green,
            () {
              if (_isCheckedIn) {
                _navigateTo(const ChemistListScreen());
              } else {
                _showSnack("Please Check In first!");
              }
            },
          ),
          if (canUseWebDcr)
            _MenuAction(
              Icons.assignment_turned_in_outlined,
              "Daily Report",
              Colors.orange,
              () => _navigateTo(const DailyReportScreen()),
            ),
          _MenuAction(
            Icons.business_center_outlined,
            "NFW Report",
            Colors.brown,
            () => _navigateTo(const NfwReportScreen()),
          ),
        ]),
        const SizedBox(height: 24),

        _buildSectionTitle("AI Intelligence"),
        _buildMenuGrid([
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
        ]),
        const SizedBox(height: 24),

        _buildSectionTitle("Manager Reporting"),
        _buildMenuGrid([
          _MenuAction(
            Icons.groups_rounded,
            "Team View",
            Colors.blue,
            () => _navigateTo(const TeamTerritoryScreen()),
          ),
          _MenuAction(
            Icons.bar_chart_rounded,
            "Reports",
            Colors.green,
            () => _navigateTo(const ReportsDashboardScreen()),
          ),
          _MenuAction(
            Icons.approval,
            "DCR Approvals (web)",
            Colors.green,
            () => _navigateTo(const ManagerJointWorkScreen()),
          ),
          _MenuAction(
            Icons.handshake_outlined,
            "DCR Approvals (Tab)",
            Colors.blue,
            _openTabJointWork,
          ),
            _MenuAction(
            Icons.receipt_long,
            "Team Expenses",
            Colors.deepOrange,
            () => _navigateTo(const ExpenseManagerScreen()),
          ),
          _MenuAction(
            Icons.link,
            "Other Links",
            Colors.indigo,
            _openWebLinks,
          ),
          _MenuAction(Icons.link, "Other Links", Colors.indigo, _openWebLinks),
        ]),
        const SizedBox(height: 24),

        _buildSectionTitle("Learning & Resources", const Color(0xFF6A1B9A)),
        _buildMenuGrid([
          _MenuAction(
            Icons.library_books_rounded,
            "Data Bank",
            const Color(0xFF6A1B9A),
            _openDataBank,
          ),
          _MenuAction(
            Icons.school_outlined,
            "Training\nMaterials",
            Colors.indigo,
            _openDataBank,
          ),
          _MenuAction(
            Icons.quiz_outlined,
            "Compliance\nDocs",
            Colors.teal,
            _openDataBank,
          ),
        ]),
        const SizedBox(height: 24),

        _buildSectionTitle("Utilities", Colors.deepPurple),
        _buildMenuGrid([
          _MenuAction(
            Icons.person_search_rounded,
            "MCL Updation",
            Colors.deepPurple,
            () => _navigateTo(const NewDrMasterScreen()),
          ),
          _MenuAction(
            Icons.folder_shared_outlined,
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
          _MenuAction(
            Icons.support_agent_outlined,
            "Support",
            Colors.cyan,
            () => _navigateTo(const SupportScreen()),
          ),
          _MenuAction(
            Icons.settings_rounded,
            "Settings",
            Colors.blueGrey,
            _showSettingsSheet,
          ),
        ]),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- SECTION TITLE ---

  Widget _buildSectionTitle(String title, Color accentBar) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: accentBar,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // --- RESPONSIVE MENU GRID ---

  Widget _buildMenuGrid(List<_MenuAction> actions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount = width < 300
            ? 3
            : width < 420
                ? 4
                : width < 600
                    ? 5
                    : 6;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.70,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) =>
              _buildMenuGridItem(actions[index], crossAxisCount),
        );
      },
    );
  }

  Widget _buildMenuGridItem(_MenuAction action, int crossAxisCount) {
    final double iconBoxSize = crossAxisCount <= 3 ? 62 : (crossAxisCount <= 4 ? 56 : 50);
    final double iconSize = crossAxisCount <= 3 ? 28 : (crossAxisCount <= 4 ? 24 : 22);
    final double fontSize = crossAxisCount <= 3 ? 11.0 : (crossAxisCount <= 4 ? 10.0 : 9.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: iconBoxSize,
                width: iconBoxSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      action.color.withValues(alpha: 0.18),
                      action.color.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(iconBoxSize * 0.28),
                  border: Border.all(color: action.color.withValues(alpha: 0.22), width: 1),
                ),
                child: Icon(action.icon, color: action.color, size: iconSize),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DRAWER ---

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
            onTap: () => _navigateTo(const ChangePasswordScreen(isForced: false)),
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

  // --- DATA BANK ---

  void _openDataBank() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DataBankHomeScreen()),
    );
  }

  // --- HELPERS ---

  void _navigateTo(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

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
        content: const Text("1. Tap Share/Menu.\n2. Select 'Add to Home Screen'."),
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
  const _MenuAction(this.icon, this.label, this.color, this.onTap);
}
