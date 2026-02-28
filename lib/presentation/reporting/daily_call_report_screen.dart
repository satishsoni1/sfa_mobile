import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class CallReportScreen extends StatefulWidget {
  const CallReportScreen({super.key});

  @override
  State<CallReportScreen> createState() => _CallReportScreenState();
}

class _CallReportScreenState extends State<CallReportScreen> {
  // 1. Updated to DateRange for weekly/custom filtering
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)),
    end: DateTime.now(),
  );

  List<dynamic> _hierarchy = [];
  dynamic _selectedSub; // Null = Myself

  bool _isLoading = true;
  Map<String, dynamic> _reportData = {};

  final ApiService _api = ApiService();
  final Color _primaryColor = const Color(0xFF4A148C);
  final Color _bgColor = const Color(0xFFF4F6F9);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final subs = await _api.getSubordinates();
      setState(() => _hierarchy = subs);
      await _fetchReportData();
    } catch (e) {
      debugPrint("Init Error: $e");
    }
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      int? targetId = _selectedSub?['id'];

      final responseData = await _api.getCallReport(
        startDate: _selectedDateRange.start,
        endDate: _selectedDateRange.end,
        userId: targetId,
      );

      if (mounted) {
        setState(() {
          // --- THE FIX IS HERE ---
          // Extract the inner 'data' object from the JSON response
          _reportData = responseData['data'] ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Fetch Error: $e");
    }
  }

  // 2. Updated to pick a date range
  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: ColorScheme.light(primary: _primaryColor)),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _fetchReportData();
    }
  }

  // 3. Open Searchable Bottom Sheet
  void _showSubordinatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SubordinateSearchSheet(
        hierarchy: _hierarchy,
        selectedSub: _selectedSub,
        onSelect: (sub) {
          setState(() => _selectedSub = sub);
          _fetchReportData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String dateRangeText =
        "${DateFormat('dd MMM').format(_selectedDateRange.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange.end)}";

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Execution Report",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              dateRangeText,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_hierarchy.isNotEmpty) _buildFilterBar(),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : RefreshIndicator(
                    onRefresh: _fetchReportData,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildSummarySection()),
                        _buildGroupedDetailsList(), // New Grouped List
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: _primaryColor,
      child: InkWell(
        onTap: _showSubordinatePicker,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_search, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedSub?['name'] ?? "Myself (Default)",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down_circle, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final summary = _reportData['summary'] ?? {};
    final int planned = summary['total_planned'] ?? 0;
    final int totalVisited = summary['total_visited'] ?? 0;
    final int plannedVisited = summary['planned_visited'] ?? 0;
    final int unplannedVisited = summary['unplanned_visited'] ?? 0;
    final int frdMet = summary['frd_met'] ?? 0;
    final int kblMet = summary['kbl_met'] ?? 0;
    final double productivity = (summary['productivity'] ?? 0).toDouble();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
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
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCategoryBadge("Planned", plannedVisited, Colors.teal),
                _buildCategoryBadge(
                  "Unplanned",
                  unplannedVisited,
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCategoryBadge("FRD Met", frdMet, Colors.indigo),
                _buildCategoryBadge("KBL Met", kblMet, Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for the summary (Place this near your other helper widgets)
  Widget _buildCategoryBadge(String label, int count, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: col.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$label: $count",
        style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  // 4. Group by Date and build flattened list
  Widget _buildGroupedDetailsList() {
    final List details = _reportData['details'] ?? [];

    if (details.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(
            child: Text(
              "No data found for this period.",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    Map<String, List<dynamic>> groupedData = {};
    for (var item in details) {
      String date = item['date'] ?? 'Unknown Date';
      groupedData.putIfAbsent(date, () => []).add(item);
    }

    List<dynamic> flattenedList = [];
    groupedData.forEach((date, items) {
      flattenedList.add({'is_header': true, 'date_label': date});
      flattenedList.addAll(items);
    });

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = flattenedList[index];

          if (item['is_header'] == true) {
            // --- NEW: Format the date string ---
            String displayDate = item['date_label'];
            try {
              DateTime parsed = DateTime.parse(displayDate);
              displayDate = DateFormat('EEEE, dd MMM yyyy').format(parsed);
            } catch (e) {
              // Keep original if parsing fails
            }

            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
              child: Text(
                displayDate,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            );
          }

          final bool isNfw = item['type'] == 'NFW' || item['is_nfw'] == true;
          if (isNfw) {
            return _buildNfwCard(item);
          } else {
            return _buildDoctorCard(item);
          }
        }, childCount: flattenedList.length),
      ),
    );
  }
  // --- CARD WIDGETS ---

  Widget _buildNfwCard(dynamic call) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.shade200, width: 1),
      ),
      elevation: 0,
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business_center,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Non-Field Work (NFW)",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Category: ${call['nfw_category'] ?? 'N/A'}",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  if (call['remarks'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"${call['remarks']}"',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(dynamic call) {
    final String statusStr = call['status']?.toString().toLowerCase() ?? '';
    final bool isUnplanned = statusStr.contains('unplanned');
    final bool isVisited = statusStr.contains('visited') || isUnplanned;
    final bool isMissed = statusStr.contains('missed');

    Color statusColor = Colors.grey;
    Color statusBgColor = Colors.grey.shade50;
    IconData statusIcon = Icons.access_time;

    if (isUnplanned) {
      statusColor = Colors.orange;
      statusBgColor = Colors.orange.shade50;
      statusIcon = Icons.bolt;
    } else if (isVisited) {
      statusColor = Colors.green;
      statusBgColor = Colors.green.shade50;
      statusIcon = Icons.check_circle;
    } else if (isMissed) {
      statusColor = Colors.red;
      statusBgColor = Colors.red.shade50;
      statusIcon = Icons.cancel;
    }

    // --- NEW: Extract Data ---
    final String workedWith = call['worked_with']?.toString() ?? '';
    final bool isJfw = call['is_jfw'] == true && workedWith.isNotEmpty;
    final List products = call['products'] ?? [];
    final String remarks = call['remarks']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.4), width: 1),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    call['doctor_name'] ?? 'Unknown',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        call['status']?.toUpperCase() ?? 'N/A',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "${call['specialization']} • ${call['area']}",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),

            // --- NEW: Joint Work Section ---
            if (isJfw) ...[
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.group, size: 16, color: Colors.blueAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Joint Work: $workedWith",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // --- NEW: Products Section ---
            if (products.isNotEmpty) ...[
              if (!isJfw)
                const Divider(height: 24)
              else
                const SizedBox(height: 12),
              Text(
                "Products Detailed:",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: products.map<Widget>((p) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purple.shade100),
                    ),
                    child: Text(
                      "${p['product_name']} (S: ${p['sample_qty']} | POB: ${p['pob_qty']} | Rx: ${p['rx_qty']})",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.purple.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // --- NEW: Remarks Section ---
            if (remarks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Remark: $remarks",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCircle(double percent, String label, Color color) {
    return Column(
      children: [
        SizedBox(
          height: 60,
          width: 60,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: percent / 100,
                strokeWidth: 6,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Center(
                child: Text(
                  "${percent.toInt()}%",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleStat(String val, String label, IconData icon, Color col) {
    return Column(
      children: [
        Icon(icon, color: col, size: 28),
        const SizedBox(height: 4),
        Text(
          val,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// CUSTOM SUBORDINATE SEARCH BOTTOM SHEET
// =========================================================================

class _SubordinateSearchSheet extends StatefulWidget {
  final List<dynamic> hierarchy;
  final dynamic selectedSub;
  final Function(dynamic) onSelect;

  const _SubordinateSearchSheet({
    required this.hierarchy,
    this.selectedSub,
    required this.onSelect,
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
    _filteredList = widget.hierarchy;
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      _filteredList = widget.hierarchy.where((sub) {
        final name = sub['name']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // 75% of screen
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                Text(
                  "Select Reporting User",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Search TextField
                TextField(
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: "Search name...",
                    prefixIcon: const Icon(Icons.search),
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
              itemCount: _filteredList.length + 1, // +1 for "Myself"
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "Myself" Option at the very top (only if not filtering strictly)
                  if (_searchQuery.isNotEmpty &&
                      !"myself".contains(_searchQuery.toLowerCase())) {
                    return const SizedBox.shrink();
                  }
                  bool isSelected = widget.selectedSub == null;
                  return _buildListTile(null, "Myself (Default)", isSelected);
                }

                var sub = _filteredList[index - 1];
                bool isSelected = widget.selectedSub?['id'] == sub['id'];
                return _buildListTile(sub, sub['name'], isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(dynamic sub, String name, bool isSelected) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? const Color(0xFF4A148C)
            : Colors.grey.shade200,
        child: Icon(
          Icons.person,
          color: isSelected ? Colors.white : Colors.grey,
        ),
      ),
      title: Text(
        name,
        style: GoogleFonts.poppins(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFF4A148C))
          : null,
      onTap: () {
        widget.onSelect(sub);
        Navigator.pop(context);
      },
    );
  }
}
