import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/report_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/tour_plan.dart';
import '../../data/models/doctor.dart';
import 'create_tour_plan_screen.dart';

class TourPlanScreen extends StatefulWidget {
  const TourPlanScreen({super.key});

  @override
  State<TourPlanScreen> createState() => _TourPlanScreenState();
}

class _TourPlanScreenState extends State<TourPlanScreen> {
  // --- State ---
  DateTime _selectedDate = DateTime.now();
  List<TourPlan> _monthlyPlans = [];
  List<dynamic> _subordinates = [];
  dynamic _selectedSubordinate; // Null = Myself

  // --- Manager Selection Mode ---
  bool _isSelectionMode = false;
  Set<DateTime> _selectedDates = {}; // Dates selected for Approve/Reject

  bool _isLoading = false;
  final ApiService _api = ApiService();

  // --- Theme Colors ---
  final Color _primaryColor = const Color(0xFF2E3192); // Deep Blue
  final Color _accentColor = const Color(0xFF1BFFFF); // Cyan Accent
  final Color _bgColor = const Color(0xFFF4F6F9);
  final Color _pendingColor = const Color(0xFFFFA726);
  final Color _approvedColor = const Color(0xFF66BB6A);
  final Color _rejectedColor = const Color(0xFFEF5350);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Hierarchy (Team Members)
      final subs = await _api.getSubordinates();

      // 2. Fetch Plans
      await _fetchPlans();

      // 3. Fetch Master Doctor List (for stats)
      if (mounted) {
        await Provider.of<ReportProvider>(
          context,
          listen: false,
        ).fetchDoctors();
      }

      if (mounted) setState(() => _subordinates = subs);
    } catch (e) {
      debugPrint("Error loading data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPlans() async {
    setState(() => _isLoading = true);
    try {
      int? targetUserId = _selectedSubordinate?['id'];
      final plans = await _api.getTourPlans(
        _selectedDate,
        userId: targetUserId,
      );
      if (mounted) setState(() => _monthlyPlans = plans);
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSubordinateChanged(dynamic sub) {
    setState(() {
      _selectedSubordinate = sub;
      _monthlyPlans = [];
      _isSelectionMode = false;
      _selectedDates.clear();
    });
    _fetchPlans();
  }

  TourPlan? get _currentPlan {
    try {
      return _monthlyPlans.firstWhere(
        (p) => DateUtils.isSameDay(p.date, _selectedDate),
      );
    } catch (e) {
      return null;
    }
  }

  // --- Logic Helpers ---

  bool get _isReadOnly {
    // 1. Viewing Subordinate -> Read Only (unless in Manager Selection Mode)
    if (_selectedSubordinate != null) return true;

    final plan = _currentPlan;
    if (plan == null) return false;

    // 2. Self View: Locked if Approved or Pending
    final status = (plan.status ?? '').toLowerCase();
    if (status == 'approved' || status == 'pending') return true;

    // Rejected or Draft -> Editable
    return false;
  }

  // --- Manager Bulk Actions ---

  void _toggleSelectionMode(DateTime date) {
    // Only Managers viewing a subordinate can select
    if (_selectedSubordinate == null) return;

    setState(() {
      _isSelectionMode = true;
      if (_selectedDates.any((d) => DateUtils.isSameDay(d, date))) {
        _selectedDates.removeWhere((d) => DateUtils.isSameDay(d, date));
        if (_selectedDates.isEmpty) _isSelectionMode = false;
      } else {
        _selectedDates.add(date);
      }
    });
  }

  void _selectAll() {
    setState(() {
      // If all distinct plan dates are already selected, deselect all.
      // Otherwise, select all available plan dates.
      final allPlanDates = _monthlyPlans.map((p) => p.date).toSet();

      if (_selectedDates.length == allPlanDates.length &&
          allPlanDates.isNotEmpty) {
        _selectedDates.clear();
        _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
        _selectedDates = allPlanDates;
      }
    });
  }

  Future<void> _performBulkAction(String action) async {
    if (_monthlyPlans.isEmpty) return;

    // Logic: We need at least one valid plan ID to target the Master Record.
    // Usually, one month has one Master ID. We take the first valid one.
    int planId = _monthlyPlans
        .firstWhere(
          (p) => p.id != 0,
          orElse: () => TourPlan(id: 0, date: DateTime.now(), doctorIds: []),
        )
        .id;

    if (planId == 0) {
      _showSnack("No valid plan found to approve/reject.", Colors.orange);
      return;
    }

    String? remark;

    // If Rejecting, require a remark
    if (action == 'Rejected') {
      remark = await showDialog<String>(
        context: context,
        builder: (ctx) {
          String r = "";
          return AlertDialog(
            title: const Text("Reject Plan"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Rejecting ${_selectedDates.length} days."),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => r = v,
                  decoration: const InputDecoration(
                    labelText: "Reason (Required)",
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, r),
                child: const Text(
                  "Reject",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );

      if (remark == null || remark.isEmpty) return;
    }

    setState(() => _isLoading = true);

    try {
      // Convert selected dates to string list YYYY-MM-DD
      List<String> dateStrings = _selectedDates
          .map((d) => d.toIso8601String().split('T')[0])
          .toList();

      await _api.bulkActionPlan(
        planId: planId,
        action: action,
        dates: dateStrings,
        remark: remark,
      );

      _showSnack(
        "Plan $action Successfully",
        action == 'Approved' ? Colors.green : Colors.red,
      );

      // Reset Mode
      setState(() {
        _isSelectionMode = false;
        _selectedDates.clear();
      });
      _fetchPlans();
    } catch (e) {
      _showSnack("Error: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- User Submission ---

  Future<void> _submitForApproval() async {
    if (_currentPlan == null) return;

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Submission"),
        content: const Text(
          "Once submitted, the plan will be locked for approval.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Submit"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      int planId = _currentPlan!.id;

      // New Plan Logic (ID is 0)
      if (planId == 0) {
        final planData = _currentPlan!.toJson();
        planData['status'] = 'Pending';
        await _api.addTourPlan(planData);
        if (mounted) _showSnack("Plan created and submitted!", Colors.green);
      } else {
        // Existing Plan Logic
        await _api.updatePlanStatus(planId, 'Pending');
        if (mounted) _showSnack("Plan submitted successfully!", Colors.green);
      }

      await _fetchPlans();
    } catch (e) {
      if (mounted) _showSnack("Failed: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- UI Building Blocks ---

  @override
  Widget build(BuildContext context) {
    final allDoctors = Provider.of<ReportProvider>(context).doctors;
    final plan = _currentPlan;
    bool isManagerView = _selectedSubordinate != null;

    return Scaffold(
      backgroundColor: _bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(allDoctors),
        ],
        body: Column(
          children: [
            // MANAGER TOOLBAR
            if (isManagerView)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Manager Actions",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    TextButton.icon(
                      icon: Icon(
                        _isSelectionMode && _selectedDates.isNotEmpty
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                      ),
                      label: const Text("Select All Days"),
                      onPressed: _selectAll,
                    ),
                  ],
                ),
              ),

            // DATE STRIP
            _buildDateStrip(),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: _primaryColor),
                    )
                  : _buildMainContent(plan),
            ),
          ],
        ),
      ),

      // FLOATING ACTION BUTTON (User Mode)
      floatingActionButton: (!isManagerView && !_isSelectionMode)
          ? _buildFAB(plan)
          : null,

      // BOTTOM ACTION BAR (Manager Mode)
      bottomNavigationBar: _isSelectionMode ? _buildManagerActionBar() : null,
    );
  }

  Widget _buildManagerActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close, color: Colors.red),
                label: const Text(
                  "REJECT",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _performBulkAction('Rejected'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text(
                  "APPROVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _performBulkAction('Approved'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(List<Doctor> allDoctors) {
    // Calc Stats
    Set<int> uniquePlannedIds = {};
    int frdCount = 0;
    int kblCount = 0;
    int otherCount = 0;

    for (var p in _monthlyPlans) {
      uniquePlannedIds.addAll(p.doctorIds);
    }

    // Categorize
    for (var docId in uniquePlannedIds) {
      try {
        final doc = allDoctors.firstWhere((d) => d.id == docId);
        if (doc.isFrd == true)
          frdCount++;
        else if (doc.isKbl == true)
          kblCount++;
        else
          otherCount++;
      } catch (_) {
        otherCount++;
      }
    }

    double coverage = allDoctors.isEmpty
        ? 0
        : (uniquePlannedIds.length / allDoctors.length);

    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      backgroundColor: _primaryColor,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedSubordinate == null
                ? "My Tour Plan"
                : "${_selectedSubordinate['name']}",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          if (_selectedSubordinate != null)
            Text(
              "Viewing Mode",
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70),
            ),
        ],
      ),
      actions: [
        if (_subordinates.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.people_alt_outlined, color: Colors.white),
            onPressed: _showSubordinatePicker,
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryColor, const Color(0xFF512DA8)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SizedBox(height: 80),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCircularStat(
                    "${(coverage * 100).toInt()}%",
                    "List Coverage",
                    coverage,
                    Colors.white,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatRow(
                        "Total Listed",
                        "${allDoctors.length}",
                        Icons.list,
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        "Unique Planned",
                        "${uniquePlannedIds.length}",
                        Icons.person_add,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCategoryCard("FRD", frdCount, Colors.orangeAccent),
                  _buildCategoryCard("KBL", kblCount, Colors.purpleAccent),
                  _buildCategoryCard(
                    "Other",
                    otherCount,
                    Colors.lightBlueAccent,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularStat(
    String mainText,
    String subText,
    double percent,
    Color color,
  ) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: percent,
            strokeWidth: 8,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  mainText,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  subText,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String label, int count, Color color) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            "$count",
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStrip() {
    int daysInMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;

    return Container(
      height: 110,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 0, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedDate),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Row(
                  children: [
                    _buildLegendDot(_approvedColor, "Appr"),
                    const SizedBox(width: 8),
                    _buildLegendDot(_rejectedColor, "Rej"),
                    const SizedBox(width: 8),
                    _buildLegendDot(_pendingColor, "Pend"),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final date = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  index + 1,
                );
                final isSelected = DateUtils.isSameDay(date, _selectedDate);
                final isChecked = _selectedDates.any(
                  (d) => DateUtils.isSameDay(d, date),
                );

                final plan = _monthlyPlans.firstWhere(
                  (p) => DateUtils.isSameDay(p.date, date),
                  orElse: () =>
                      TourPlan(id: -1, date: date, doctorIds: [], status: null),
                );

                Color statusColor = Colors.grey.shade300;
                if (plan.status?.toLowerCase() == 'approved')
                  statusColor = _approvedColor;
                if (plan.status?.toLowerCase() == 'pending')
                  statusColor = _pendingColor;
                if (plan.status?.toLowerCase() == 'rejected')
                  statusColor = _rejectedColor;

                return GestureDetector(
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelectionMode(date);
                    } else {
                      setState(() => _selectedDate = date);
                    }
                  },
                  onLongPress: () => _toggleSelectionMode(date),
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 55,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? _primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChecked
                                ? Colors.orange
                                : (isSelected
                                      ? _primaryColor
                                      : Colors.grey.shade200),
                            width: isChecked ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _primaryColor.withOpacity(0.3),
                                    blurRadius: 6,
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('EEE').format(date).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.white70
                                    : Colors.grey,
                              ),
                            ),
                            Text(
                              DateFormat('dd').format(date),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isSelectionMode && isChecked)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.orange,
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
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
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMainContent(TourPlan? plan) {
    if (plan == null) return _buildEmptyState();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBanner(plan),
          const SizedBox(height: 16),

          if ((plan.status ?? '').toLowerCase() == 'rejected' &&
              (plan.remark != null && plan.remark!.isNotEmpty))
            _buildRejectionRemark(plan.remark!),

          if (plan.isActivity == true)
            _buildActivityCard(plan.activityType ?? "General Activity")
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Planned Doctors",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 10),
                if (plan.doctors.isEmpty)
                  _buildNoDoctorsState()
                else
                  ...plan.doctors.map((doc) => _buildDoctorCard(doc)),
              ],
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildRejectionRemark(String remark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: _rejectedColor, size: 20),
              const SizedBox(width: 8),
              Text(
                "Correction Required",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _rejectedColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.red),
          Text(
            remark,
            style: GoogleFonts.poppins(color: Colors.red.shade900, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(String type) {
    IconData icon = Icons.event_note;
    Color color = Colors.blue;

    if (type.contains("Meeting")) {
      icon = Icons.groups;
      color = Colors.indigo;
    } else if (type.contains("Leave")) {
      icon = Icons.beach_access;
      color = Colors.orange;
    } else if (type.contains("Campaign")) {
      icon = Icons.campaign;
      color = Colors.teal;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            "Planned Activity",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
          ),
          Text(
            type,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(TourPlan plan) {
    String status = (plan.status ?? 'Draft').toUpperCase();
    Color color;
    IconData icon;
    String subText = "Not submitted yet";

    if (status == 'APPROVED') {
      color = _approvedColor;
      icon = Icons.check_circle;
      subText = "Plan is locked";
    } else if (status == 'REJECTED') {
      color = _rejectedColor;
      icon = Icons.cancel;
      subText = "Action required";
    } else if (status == 'PENDING') {
      color = _pendingColor;
      icon = Icons.hourglass_top;
      subText = "Awaiting approval";
    } else {
      color = Colors.grey;
      icon = Icons.edit_note;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                Text(
                  subText,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (!_isReadOnly)
            ElevatedButton(
              onPressed: _submitForApproval,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Submit",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(Doctor doc) {
    List<Widget> badges = [];
    if (doc.isFrd == true) badges.add(_buildBadge("FRD", Colors.orange));
    if (doc.isKbl == true) badges.add(_buildBadge("KBL", Colors.purple));

    String tType = (doc.territoryType ?? 'Core').toUpperCase();
    badges.add(_buildBadge(tType, Colors.blueGrey));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: _primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${doc.specialization} • ${doc.area}",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 52),
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 6, children: badges),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No plan for this date",
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDoctorsState() {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.person_off_outlined, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            "No doctors added yet.",
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(TourPlan? plan) {
    if (_isReadOnly) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      backgroundColor: _primaryColor,
      icon: Icon(plan == null ? Icons.add : Icons.edit, color: Colors.white),
      label: Text(
        plan == null ? "Create" : "Edit Plan",
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      onPressed: _navigateToEditor,
    );
  }

  Future<void> _navigateToEditor() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTourPlanScreen(
          initialDate: _selectedDate,
          existingPlan: _currentPlan,
          isReadOnly: false,
        ),
      ),
    );
    if (result == true) _fetchPlans();
  }

  void _showSubordinatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Select Team Member",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  _buildSubordinateTile(
                    name: "Myself",
                    subtitle: "My Territory",
                    isSelected: _selectedSubordinate == null,
                    hasPlan: false,
                    onTap: () {
                      Navigator.pop(ctx);
                      _onSubordinateChanged(null);
                    },
                  ),
                  ..._subordinates.map(
                    (sub) => _buildSubordinateTile(
                      name: sub['name'],
                      subtitle: sub['designation'] ?? 'Team Member',
                      imageUrl: sub['photo'],
                      isSelected: _selectedSubordinate?['id'] == sub['id'],
                      hasPlan:
                          sub['has_plan'] == true, // Check logic from your API
                      statusLabel: sub['plan_status'] ?? '',
                      onTap: () {
                        Navigator.pop(ctx);
                        _onSubordinateChanged(sub);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubordinateTile({
    required String name,
    required String subtitle,
    String? imageUrl,
    required bool isSelected,
    required bool hasPlan,
    String statusLabel = '',
    required VoidCallback onTap,
  }) {
    Color statusColor = Colors.grey;
    if (statusLabel.toLowerCase() == 'approved') statusColor = _approvedColor;
    if (statusLabel.toLowerCase() == 'pending') statusColor = _pendingColor;
    if (statusLabel.toLowerCase() == 'rejected') statusColor = _rejectedColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? _primaryColor.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? _primaryColor : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey.shade100,
              backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
              child: imageUrl == null
                  ? Icon(Icons.person, color: Colors.grey.shade400)
                  : null,
            ),
            if (hasPlan)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle, size: 16, color: statusColor),
                ),
              ),
          ],
        ),
        title: Text(
          name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isSelected ? _primaryColor : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: hasPlan
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
