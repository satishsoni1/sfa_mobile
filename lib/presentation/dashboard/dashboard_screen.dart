import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zforce/presentation/chat/chat_screen.dart';

// --- SCREENS ---
import 'package:zforce/presentation/expense/ExpenseScreen.dart';
import 'package:zforce/presentation/expense/ExpenseSummaryScreen.dart';
import 'package:zforce/presentation/leave/leave_list_screen.dart';
import 'package:zforce/presentation/sample/SampleDistributionScreen.dart';
import 'package:zforce/presentation/support/support_screen.dart';
import 'package:zforce/presentation/login/change_password_screen.dart';
import '../doctor_list/doctor_list_screen.dart';
import '../doctor_list/add_doctor_screen.dart';
import '../reporting/ManagerJointWorkScreen.dart';
import '../reporting/TeamTerritoryScreen.dart';
import '../reporting/daily_report_screen.dart';
import '../reporting/nfw_report_screen.dart';
import '../tour_plan/tour_plan_screen.dart';

// --- PROVIDERS & SERVICES ---
import '../../providers/report_provider.dart';
import '../../providers/auth_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/user_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // --- STATE ---
  bool _isCheckedIn = false;
  DateTime? _checkInTime;
  String _statusText = "Loading...";
  bool _isLoadingAction = false;
  bool _isRefreshing = false;

  // Expense Data
  String _expClaimed = "0";
  String _expPending = "0";

  Timer? _timer;
  String _elapsedTime = "00:00";

  // --- COLORS ---
  final Color primaryColor = const Color(0xFF4A148C);
  final Color accentColor = const Color(0xFF7B1FA2);
  final Color bgColor = const Color(0xFFF3F4F6);

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

  Future<void> _fetchAttendance(ApiService api) async {
    try {
      final statusData = await api.getAttendanceStatus();
      if (!mounted) return;
      final status = statusData['status'];
      final data = statusData['data'];

      setState(() {
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

  Future<void> _fetchExpenseSummary(ApiService api) async {
    try {
      // Fetch for current month
      final data = await api.getMonthlyExpenses(DateTime.now());
      if (!mounted) return;

      final summary = data['summary'];
      setState(() {
        // Convert numbers to formatted strings (e.g. 5000 -> 5,000)
        final fmt = NumberFormat("#,##0");
        _expClaimed = fmt.format(summary['total_claimed'] ?? 0);
        _expPending = fmt.format(summary['total_pending'] ?? 0);
      });
    } catch (e) {
      // Handle silently or set to error state
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          );
        },
        backgroundColor: const Color(0xFF4A148C),
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
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
                    margin: const EdgeInsets.only(
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
    return Row(
      children: [
        _buildSummaryItem(
          "Visits",
          "$visitCount",
          Icons.people_outline,
          Colors.blue,
        ),
        const SizedBox(width: 12),
        _buildSummaryItem(
          "Online",
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

  Widget _buildExpenseSummaryCard() {
    final String currentMonth = DateFormat('MMMM').format(DateTime.now());

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExpenseSummaryScreen()),
        );
        _loadInitialData(); // Refresh on return
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3F51B5), Color(0xFF5C6BC0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Expense Summary ($currentMonth)",
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward,
                  color: Colors.white70,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "₹$_expClaimed",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Total Claimed",
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 40, color: Colors.white24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "₹$_expPending",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFFCC80),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Pending",
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExpenseScreen()),
                    );
                    _loadInitialData(); // Refresh on return
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add, color: Colors.indigo),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExpenseSummaryCard(),
        const SizedBox(height: 30),

        _buildSectionTitle("Field Operations"),
        _buildMenuGrid([
          _MenuAction(Icons.medical_services, "Dr. Call", Colors.purple, () {
            if (_isCheckedIn)
              _navigateTo(const DoctorListScreen());
            else
              _showSnack("Please Check In first!");
          }),
          _MenuAction(
            Icons.map,
            "Tour Plan",
            Colors.teal,
            () => _navigateTo(const TourPlanScreen()),
          ),
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
            Icons.business_center,
            "Sample Distribution",
            Colors.cyan,
            () => _navigateTo(const SampleDistributionScreen()),
          ),
        ]),
        const SizedBox(height: 24),

        _buildSectionTitle("HR & Management"),
        _buildMenuGrid([
          _MenuAction(
            Icons.receipt_long,
            "Expense",
            Colors.indigo,
            () => _navigateTo(const ExpenseSummaryScreen()),
          ),
          _MenuAction(
            Icons.calendar_month,
            "Leave",
            Colors.redAccent,
            () => _navigateTo(const LeaveListScreen()),
          ),
          _MenuAction(
            Icons.groups,
            "Team View",
            Colors.blue,
            () => _navigateTo(const TeamTerritoryScreen()),
          ),
          _MenuAction(
            Icons.approval,
            "Approvals",
            Colors.green,
            () => _navigateTo(const ManagerJointWorkScreen()),
          ),
        ]),
        const SizedBox(height: 24),

        _buildSectionTitle("Utilities"),
        _buildMenuGrid([
          _MenuAction(
            Icons.person_add_alt_1,
            "Add Doctor",
            Colors.deepPurple,
            () => _navigateTo(const AddDoctorScreen()),
          ),
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
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
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
        childAspectRatio: 0.8,
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
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
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
