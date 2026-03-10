import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';
import 'create_tour_plan_screen.dart';
import 'tour_plan_review_screen.dart';

class RouteTourPlanScreen extends StatefulWidget {
  const RouteTourPlanScreen({super.key});

  @override
  State<RouteTourPlanScreen> createState() => _RouteTourPlanScreenState();
}

class _RouteTourPlanScreenState extends State<RouteTourPlanScreen> {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _subordinates = [];
  dynamic _selectedSubordinate; // Null = Myself
  bool _isLoading = false;

  Map<String, dynamic> _monthlyPlans = {};

  final Color _primaryColor = const Color(0xFF2E3192);
  final Color _bgColor = const Color(0xFFF4F6F9);
  final ApiService _api = ApiService();

  final Color _pendingColor = const Color(0xFFFFA726);
  final Color _approvedColor = const Color(0xFF66BB6A);
  final Color _rejectedColor = const Color(0xFFEF5350);

  // --- Manager Selection Mode ---
  bool _isSelectionMode = false;
  Set<DateTime> _selectedDates = {}; // Dates selected for Approve/Reject

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch Subordinates (Manager View)
      _subordinates = await _api.getSubordinates();
      await _fetchMonthlyPlans();
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- INTEGRATED API CALL ---
  Future<void> _fetchMonthlyPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await _api.getMonthlyAreaPlans(
        _selectedDate,
        userId: _selectedSubordinate?['id'],
      );
      if (mounted) {
        setState(() {
          _monthlyPlans = plans;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch plans: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Bulk Action Logic for Managers ---
  void _toggleSelectionMode(DateTime date) {
    if (_selectedSubordinate == null) return; // Only managers selecting subs
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
      final allPlanDates = _monthlyPlans.keys
          .map((k) => DateTime.parse(k))
          .toSet();
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

  // --- INTEGRATED API CALL ---
  Future<void> _performBulkAction(String action) async {
    if (_selectedDates.isEmpty) return;

    String? remark;
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
      List<String> dateStrings = _selectedDates
          .map((d) => DateFormat('yyyy-MM-dd').format(d))
          .toList();

      bool success = await _api.bulkActionAreaPlan(
        action: action,
        dates: dateStrings,
        remark: remark,
        targetUserId: _selectedSubordinate['id'],
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Plan $action Successfully"),
            backgroundColor: action == 'Approved' ? Colors.green : Colors.red,
          ),
        );
        setState(() {
          _isSelectionMode = false;
          _selectedDates.clear();
        });
        await _fetchMonthlyPlans();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update plans"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    var todaysPlan = _monthlyPlans[dateKey];
    bool isManagerView = _selectedSubordinate != null;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tour Plan (Area Wise)",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              _selectedSubordinate?['name'] ?? "My Territory",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_subordinates.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.people_alt, color: Colors.white),
              onPressed: _showSubordinatePicker,
              tooltip: "Select Team Member",
            ),
        ],
      ),
      body: Column(
        children: [
          // Manager Toolbar
          if (isManagerView)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

          _buildMonthHeaderAndReviewBtn(),
          _buildDateStrip(),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : _buildDailyPlanView(todaysPlan),
          ),
        ],
      ),
      floatingActionButton: (!isManagerView && !_isSelectionMode)
          ? (todaysPlan?['status'] == 'Approved' ||
                    todaysPlan?['status'] == 'Pending'
                ? null // Hide FAB if locked
                : FloatingActionButton.extended(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateRouteTourPlanScreen(
                            date: _selectedDate,
                            userId: _selectedSubordinate?['id'],
                            userName: _selectedSubordinate?['name'] ?? "Myself",
                            existingData: todaysPlan,
                          ),
                        ),
                      );
                      if (result == true) _fetchMonthlyPlans();
                    },
                    backgroundColor: _primaryColor,
                    icon: const Icon(Icons.map, color: Colors.white),
                    label: Text(
                      "Plan Day",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ))
          : null,
      bottomNavigationBar: _isSelectionMode ? _buildManagerActionBar() : null,
    );
  }

  Widget _buildManagerActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
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

  Widget _buildMonthHeaderAndReviewBtn() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(_selectedDate),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TourPlanReviewScreen(
                    currentMonth: _selectedDate,
                    monthlyPlans: _monthlyPlans,
                    userId: _selectedSubordinate?['id'],
                  ),
                ),
              );
              if (result == true) _fetchMonthlyPlans(); // Refresh if submitted
            },
            icon: const Icon(Icons.fact_check_outlined, size: 20),
            label: Text(
              "Review & Submit",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              elevation: 6,
              shadowColor: Colors.green.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
      height: 90,
      color: Colors.white,
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

          String dKey = DateFormat('yyyy-MM-dd').format(date);
          bool hasPlan = _monthlyPlans.containsKey(dKey);
          String status = hasPlan ? _monthlyPlans[dKey]['status'] ?? '' : '';

          Color dotColor = Colors.transparent;
          if (status == 'Approved') dotColor = Colors.green;
          if (status == 'Pending') dotColor = Colors.orange;
          if (status == 'Draft') dotColor = Colors.grey;

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
                          : (isSelected ? _primaryColor : Colors.grey.shade200),
                      width: isChecked ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white70 : Colors.grey,
                        ),
                      ),
                      Text(
                        DateFormat('dd').format(date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isSelectionMode && isChecked)
                  const Positioned(
                    top: 2,
                    right: 2,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.check, size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyPlanView(dynamic plan) {
    if (plan == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "No Areas or Activities planned.",
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    bool isActivity = plan['type'] == 'activity';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                "Status: ${plan['status']}",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (isActivity)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade100),
            ),
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.event_note, size: 40, color: Colors.blue),
                  const SizedBox(height: 12),
                  Text(
                    "Planned Activity",
                    style: GoogleFonts.poppins(color: Colors.blue.shade700),
                  ),
                  Text(
                    plan['activity_name'] ?? 'Unknown Activity',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Text(
            "Planned Areas",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),

          if (plan['areas'] != null && (plan['areas'] as List).isNotEmpty)
            ...List.generate((plan['areas'] as List).length, (index) {
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade50,
                    child: const Icon(Icons.location_on, color: Colors.green),
                  ),
                  title: Text(
                    plan['areas'][index],
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              );
            })
          else
            Text(
              "No specific areas selected.",
              style: TextStyle(
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],

        // NEW: Remark Display
        if (plan['remark'] != null &&
            plan['remark'].toString().trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.format_quote,
                  size: 20,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Daily Remark",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan['remark'],
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _onSubordinateChanged(dynamic sub) {
    setState(() {
      _selectedSubordinate = sub;
      _monthlyPlans = {};
      _isSelectionMode = false;
      _selectedDates.clear();
    });
    _fetchMonthlyPlans();
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
                      // ADDED ??.toString() and fallback 'Unknown' to prevent null crashes
                      name: sub['name']?.toString() ?? 'Unknown',
                      subtitle: sub['designation']?.toString() ?? 'Team Member',
                      imageUrl: sub['photo']?.toString(),
                      isSelected: _selectedSubordinate?['id'] == sub['id'],
                      hasPlan: sub['has_plan'] == true,
                      statusLabel: sub['plan_status']?.toString() ?? '',
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
        trailing: hasPlan && statusLabel.isNotEmpty
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
