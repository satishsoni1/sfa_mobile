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
  String _monthStatus = 'Draft'; // NEW: Tracks the status of the entire month

  final Color _primaryColor = const Color(0xFF2E3192);
  final Color _bgColor = const Color(0xFFF4F6F9);
  final ApiService _api = ApiService();

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
      _subordinates = await _api.getSubordinates();
      await _fetchMonthlyPlans();
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- API CALL ---
 Future<void> _fetchMonthlyPlans() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.getMonthlyAreaPlans(
        _selectedDate,
        userId: _selectedSubordinate?['id'],
      );
      if (mounted) {
        setState(() {
          _monthStatus = response['month_status'] ?? 'Draft';
          
          // --- THE FIX IS HERE ---
          var plansData = response['plans'];
          
          if (plansData == null || plansData is List) {
            // Laravel returned [] (List) because it was empty. 
            // Force it to be an empty Map {} so Dart doesn't crash.
            _monthlyPlans = {}; 
          } else {
            // It has data, so it correctly came back as a Map
            _monthlyPlans = Map<String, dynamic>.from(plansData);
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch plans: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    var todaysPlan = _monthlyPlans[dateKey];
    bool isManagerView = _selectedSubordinate != null;

    // The month is locked if it's pending approval or already approved.
    bool isMonthLocked = _monthStatus == 'Pending' || _monthStatus == 'Approved';

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
              "Monthly Tour Plan",
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
          _buildMonthHeaderAndReviewBtn(),
          
          // Month Status Banner
          if (_monthStatus != 'Draft')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: _monthStatus == 'Approved' 
                  ? Colors.green.shade50 
                  : (_monthStatus == 'Pending' ? Colors.orange.shade50 : Colors.red.shade50),
              child: Center(
                child: Text(
                  "Month Plan Status: ${_monthStatus.toUpperCase()}",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: _monthStatus == 'Approved' 
                        ? Colors.green.shade800 
                        : (_monthStatus == 'Pending' ? Colors.orange.shade800 : Colors.red.shade800),
                  ),
                ),
              ),
            ),

          _buildDateStrip(),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : _buildDailyPlanView(todaysPlan),
          ),
        ],
      ),
      
      // Hide FAB if manager is viewing OR if the employee's month is locked
      floatingActionButton: (isManagerView || isMonthLocked)
          ? null 
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
                    monthStatus: _monthStatus, // Pass status to review screen
                    userId: _selectedSubordinate?['id'],
                  ),
                ),
              );
              if (result == true) _fetchMonthlyPlans(); // Refresh if status changed
            },
            icon: const Icon(Icons.fact_check_outlined, size: 20),
            label: Text(
              "Review Month",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
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
    int daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    return Container(
      height: 90,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: daysInMonth,
        itemBuilder: (context, index) {
          final date = DateTime(_selectedDate.year, _selectedDate.month, index + 1);
          final isSelected = DateUtils.isSameDay(date, _selectedDate);

          String dKey = DateFormat('yyyy-MM-dd').format(date);
          bool hasPlan = _monthlyPlans.containsKey(dKey);
          
          Color dotColor = Colors.transparent;
          if (hasPlan) {
             // If month is approved, all dots are green. Otherwise grey for draft.
             dotColor = _monthStatus == 'Approved' ? Colors.green : (_monthStatus == 'Pending' ? Colors.orange : Colors.grey);
          }

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 55,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? _primaryColor : Colors.grey.shade200,
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
              "No Activity planned for this day.",
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

        if (plan['remark'] != null && plan['remark'].toString().trim().isNotEmpty)
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
                Icon(Icons.format_quote, size: 20, color: Colors.orange.shade800),
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
                        style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
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
      _monthStatus = 'Draft';
    });
    _fetchMonthlyPlans();
  }

  void _showSubordinatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SubordinateSearchSheet(
        subordinates: _subordinates,
        selectedSubordinate: _selectedSubordinate,
        primaryColor: _primaryColor,
        approvedColor: _approvedColor,
        pendingColor: _pendingColor,
        rejectedColor: _rejectedColor,
        onSelect: (sub) {
          _onSubordinateChanged(sub);
        },
      ),
    );
  }
}

// =========================================================================
// CUSTOM SUBORDINATE SEARCH BOTTOM SHEET
// =========================================================================

class _SubordinateSearchSheet extends StatefulWidget {
  final List<dynamic> subordinates;
  final dynamic selectedSubordinate;
  final Function(dynamic) onSelect;
  final Color primaryColor;
  final Color approvedColor;
  final Color pendingColor;
  final Color rejectedColor;

  const _SubordinateSearchSheet({
    required this.subordinates,
    this.selectedSubordinate,
    required this.onSelect,
    required this.primaryColor,
    required this.approvedColor,
    required this.pendingColor,
    required this.rejectedColor,
  });

  @override
  State<_SubordinateSearchSheet> createState() =>
      _SubordinateSearchSheetState();
}

class _SubordinateSearchSheetState extends State<_SubordinateSearchSheet> {
  String _searchQuery = "";
  late List<dynamic> _filteredList;

  @override
  void initState() {
    super.initState();
    _filteredList = widget.subordinates;
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      _filteredList = widget.subordinates.where((sub) {
        final name = sub['name']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // 75% height for better search experience
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header & Drag Handle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Select Team Member",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Search TextField
                TextField(
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: "Search name...",
                    prefixIcon: Icon(Icons.search, color: widget.primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List View
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredList.length + 1, // +1 for "Myself"
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "Myself" Option at the top
                  if (_searchQuery.isNotEmpty && !"myself".contains(_searchQuery.toLowerCase())) {
                    return const SizedBox.shrink();
                  }
                  bool isSelected = widget.selectedSubordinate == null;
                  return _buildSubordinateTile(
                    name: "Myself",
                    subtitle: "My Territory",
                    isSelected: isSelected,
                    hasPlan: false,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSelect(null);
                    },
                  );
                }

                var sub = _filteredList[index - 1];
                bool isSelected = widget.selectedSubordinate?['id'] == sub['id'];

                return _buildSubordinateTile(
                  name: sub['name']?.toString() ?? 'Unknown',
                  subtitle: sub['designation']?.toString() ?? 'Team Member',
                  imageUrl: sub['photo']?.toString(),
                  isSelected: isSelected,
                  hasPlan: sub['has_plan'] == true,
                  statusLabel: sub['plan_status']?.toString() ?? '',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSelect(sub);
                  },
                );
              },
            ),
          ),
        ],
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
    if (statusLabel.toLowerCase() == 'approved') statusColor = widget.approvedColor;
    if (statusLabel.toLowerCase() == 'pending') statusColor = widget.pendingColor;
    if (statusLabel.toLowerCase() == 'rejected') statusColor = widget.rejectedColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? widget.primaryColor.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? widget.primaryColor : Colors.grey.shade200,
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
            color: isSelected ? widget.primaryColor : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: hasPlan && statusLabel.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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