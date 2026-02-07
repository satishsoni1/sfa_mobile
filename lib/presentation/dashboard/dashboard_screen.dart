import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// Import your screens
import 'package:zforce/presentation/leave/apply_leave_screen.dart';
import 'package:zforce/presentation/leave/leave_list_screen.dart';
import 'package:zforce/presentation/support/support_screen.dart';
// Make sure this path matches where you saved the ChangePasswordScreen
import 'package:zforce/presentation/login/change_password_screen.dart';

import '../doctor_list/doctor_list_screen.dart';
import '../doctor_list/add_doctor_screen.dart';
import '../reporting/ManagerJointWorkScreen.dart';
import '../reporting/TeamTerritoryScreen.dart';
import '../reporting/daily_report_screen.dart';
import '../reporting/nfw_report_screen.dart';
import '../tour_plan/tour_plan_screen.dart';

// Providers & Services
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
  // --- STATE VARIABLES ---
  bool _isCheckedIn = false;
  DateTime? _checkInTime;
  String _statusText = "Loading...";
  bool _isLoadingAction = false;

  // Colors
  final Color primaryColor = const Color(0xFF4A148C);
  final Color accentColor = const Color(0xFF7C43BD);
  final Color bgColor = const Color(0xFFF3F4F6);

  // Global Key for Scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    final apiService = ApiService();

    reportProvider.fetchTodayData();

    try {
      final statusData = await apiService.getAttendanceStatus();
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
      });
    } catch (e) {
      if (mounted) setState(() => _statusText = "Offline");
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Action failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  void _handleLogout() {
    Provider.of<AuthProvider>(context, listen: false).logout();
  }

  // --- SHOW SETTINGS SHEET (New) ---
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Settings",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Change Password Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset, color: Colors.blue),
              ),
              title: Text(
                "Change Password",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.pop(ctx); // Close sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(isForced: false),
                  ),
                );
              },
            ),

            // Add other settings here later (e.g., Notifications, Language)
          ],
        ),
      ),
    );
  }

  // --- SHOW INSTALL INSTRUCTIONS ---
  void _showInstallInstructions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Install App"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("To install this app on your device:"),
            SizedBox(height: 10),
            Text("1. Tap the Share button (iOS) or Menu dots (Android)."),
            SizedBox(height: 4),
            Text("2. Select 'Add to Home Screen'."),
            SizedBox(height: 4),
            Text("3. Tap 'Add' to confirm."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Got it",
              style: TextStyle(color: Color(0xFF4A148C)),
            ),
          ),
        ],
      ),
    );
  }

  String _getZoneLogo(String? division) {
    final zone = division?.toLowerCase() ?? "";
    if (zone.contains("1")) return "assets/images/3.png";
    if (zone.contains("2")) return "assets/images/4.png";
    return "assets/images/5.png";
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    // Layout Calculations
    const double headerHeight = 380;
    const double cardTopPos = 220;
    const double totalStackHeight = 460;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,

      // --- DRAWER ---
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: primaryColor),
              accountName: Text(user?.firstName ?? "User"),
              accountEmail: Text(user?.division ?? "Employee"),
              currentAccountPicture: CircleAvatar(
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
            ),
            ListTile(
              leading: const Icon(Icons.install_mobile),
              title: const Text("Install App"),
              onTap: () {
                Navigator.pop(context);
                _showInstallInstructions();
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text("Help & Support"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupportScreen()),
                );
              },
            ),
            // --- NEW DRAWER ITEM: Change Password ---
            ListTile(
              leading: const Icon(Icons.vpn_key_outlined),
              title: const Text("Change Password"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(isForced: false),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // ================= HEADER & ATTENDANCE CARD =================
            SizedBox(
              height: totalStackHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildHeaderBackground(user, headerHeight),
                  Positioned(
                    top: cardTopPos,
                    left: 20,
                    right: 20,
                    child: _buildAttendanceCard(),
                  ),
                ],
              ),
            ),

            // ================= BODY CONTENT =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildVisitsOverview(),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---
  Widget _buildHeaderBackground(User? user, double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, accentColor],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Welcome back,",
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          user?.firstName ?? "Employee",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    backgroundImage: NetworkImage(
                      "https://ui-avatars.com/api/?name=${user?.firstName ?? 'User'}&background=random&color=fff",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                width: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  _getZoneLogo(user?.division),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isCheckedIn ? Colors.green.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fiber_manual_record,
                  size: 12,
                  color: _isCheckedIn ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _statusText.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _isCheckedIn
                        ? Colors.green.shade800
                        : Colors.grey.shade700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isCheckedIn && _checkInTime != null
                ? DateFormat('h:mm a').format(_checkInTime!)
                : "--:--",
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            _isCheckedIn ? "Checked In Time" : "Start your day",
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
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitsOverview() {
    final reportProvider = Provider.of<ReportProvider>(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Visits",
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${reportProvider.visitCount}",
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.people_alt_outlined,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        InkWell(
          onTap: _loadInitialData,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 90,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purple.shade100),
            ),
            child: const Icon(Icons.refresh, color: Color(0xFF4A148C)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Actions",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          childAspectRatio: 0.75,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          children: [
            // --- ROW 1: DAILY CORE TASKS ---
            _buildActionItem(
              Icons.medical_services,
              "Dr. Call",
              Colors.purple,
              () {
                if (_isCheckedIn) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DoctorListScreen()),
                  );
                } else {
                  _showSnack("Check In first!");
                }
              },
            ),
            _buildActionItem(Icons.map, "Tour Plan", Colors.teal, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TourPlanScreen()),
              );
            }),
            _buildActionItem(Icons.assignment, "Report", Colors.orange, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DailyReportScreen()),
              );
            }),
            _buildActionItem(
              Icons.business_center,
              "NFW Report",
              Colors.brown,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NfwReportScreen()),
                );
              },
            ),

            // --- ROW 2: HR / ADMIN ---
            _buildActionItem(Icons.calendar_month, "Leave", Colors.red, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaveListScreen()),
              );
            }),
            _buildActionItem(
              Icons.receipt_long,
              "Expense",
              Colors.indigo,
              () {},
            ),

            // --- ROW 3: MANAGERIAL ---
            _buildActionItem(Icons.approval, "Approvals", Colors.teal, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManagerJointWorkScreen(),
                ),
              );
            }),
            _buildActionItem(Icons.groups, "Team Report", Colors.indigo, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeamTerritoryScreen()),
              );
            }),

            // --- ROW 4: MASTER DATA ---
            _buildActionItem(Icons.person_add_alt_1, "Add Dr", Colors.blue, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddDoctorScreen()),
              );
            }),

            // --- ROW 5: UTILITIES ---
            _buildActionItem(Icons.support_agent, "Support", Colors.cyan, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportScreen()),
              );
            }),
            // --- SETTINGS (Now opens Bottom Sheet with Change Password) ---
            _buildActionItem(Icons.settings, "Settings", Colors.grey, () {
              _showSettingsSheet();
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}
