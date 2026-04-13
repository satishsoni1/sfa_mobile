import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../providers/report_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/tour_plan.dart';
import '../../data/models/chemist.dart';

import '../reporting/chemist_reporting_screen.dart';
import 'add_chemist_screen.dart';
import 'chemist_history_screen.dart';

class ChemistListScreen extends StatefulWidget {
  const ChemistListScreen({super.key});

  @override
  State<ChemistListScreen> createState() => _ChemistListScreenState();
}

class _ChemistListScreenState extends State<ChemistListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  List<int> _todayPlannedIds = [];
  bool _isLoadingPlan = true;

  // --- TEAM MEMBER SELECTION ---
  List<dynamic> _subordinates = [];
  dynamic _selectedSubordinate; // Null means "Myself"
  final ApiService _api = ApiService();

  final Color _primaryColor = const Color(0xFF4A148C);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubordinatesAndData();
    });
  }

  Future<void> _loadSubordinatesAndData() async {
    try {
      final subs = await _api.getSubordinates();
      if (mounted) setState(() => _subordinates = subs);
    } catch (e) {
      debugPrint("Error fetching subordinates: $e");
    }
    _fetchDataForSelectedUser();
  }

  Future<void> _fetchDataForSelectedUser() async {
    setState(() => _isLoadingPlan = true);
    final provider = Provider.of<ReportProvider>(context, listen: false);

    int? targetUserId = _selectedSubordinate?['id'];

    // Fetch Chemists specifically for the selected user
    await provider.fetchChemists(userId: targetUserId);
    await provider.fetchTodayChemistData();

    try {
      // NOTE: If your getTourPlans API doesn't support subordinate ID yet,
      // it will just default to showing the logged-in manager's plan.
      final plans = await _api.getTourPlans(DateTime.now());

      final todayPlan = plans.firstWhere(
        (p) => DateUtils.isSameDay(p.date, DateTime.now()),
        orElse: () => TourPlan(
          id: -1,
          date: DateTime.now(),
          doctorIds: [],
          status: 'None',
        ),
      );

      if (mounted) {
        setState(() {
          _todayPlannedIds = List<int>.from(todayPlan.doctorIds);
          _isLoadingPlan = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPlan = false);
    }
  }

  void _onSubordinateChanged(dynamic sub) {
    setState(() {
      _selectedSubordinate = sub;
      _searchController.clear();
      _searchQuery = "";
    });
    _fetchDataForSelectedUser();
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = Provider.of<ReportProvider>(context);
    final allChemists = reportProvider.chemists;

    // --- FILTER LOGIC ---
    final searchResults = _searchQuery.isEmpty
        ? allChemists
        : allChemists
              .where(
                (chemist) =>
                    chemist.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    chemist.area.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

    final plannedSet = _todayPlannedIds.map((e) => e.toString()).toSet();
    final plannedChemists = searchResults
        .where((c) => plannedSet.contains(c.id.toString()))
        .toList();
    final unplannedChemists = searchResults
        .where((c) => !plannedSet.contains(c.id.toString()))
        .toList();

    int visitedCount = plannedChemists
        .where(
          (chemist) => reportProvider.chemistReports.any(
            (r) => r.chemistId == chemist.id.toString(),
          ),
        )
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Chemist',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              DateFormat('EEEE, dd MMM').format(DateTime.now()),
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddChemistScreen()),
              );
              if (result == true && mounted) {
                Provider.of<ReportProvider>(
                  context,
                  listen: false,
                ).fetchChemists(userId: _selectedSubordinate?['id']);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- HEADER WITH TEAM MEMBER PICKER ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // TEAM MEMBER DROPDOWN (Only visible if manager has subordinates)
                if (_subordinates.isNotEmpty) ...[
                  _buildSubordinateFilter(),
                  const SizedBox(height: 16),
                ],

                if (plannedChemists.isNotEmpty)
                  _buildProgressCard(visitedCount, plannedChemists.length),

                const SizedBox(height: 16),

                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: "Search Chemist or Area...",
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, color: _primaryColor),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- LIST ---
          Expanded(
            child: reportProvider.isLoading || _isLoadingPlan
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    children: [
                      if (plannedChemists.isNotEmpty) ...[
                        _buildSectionHeader(
                          "PLANNED VISITS",
                          Icons.gps_fixed,
                          _primaryColor,
                        ),
                        ...plannedChemists.map(
                          (chemist) =>
                              _buildChemistCard(chemist, isPlanned: true),
                        ),
                        const SizedBox(height: 24),
                      ],

                      _buildSectionHeader(
                        plannedChemists.isEmpty
                            ? "ALL CHEMISTS"
                            : "OTHER CHEMISTS",
                        Icons.storefront_outlined,
                        Colors.grey.shade700,
                      ),

                      if (unplannedChemists.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(30),
                          child: Center(
                            child: Text(
                              "No chemists found",
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...unplannedChemists.map(
                          (chemist) =>
                              _buildChemistCard(chemist, isPlanned: false),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSubordinateFilter() {
    return InkWell(
      onTap: _showSubordinatePicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_search, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedSubordinate?['name'] ?? "My Territory (Self)",
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
    );
  }

  void _showSubordinatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Select Territory",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _selectedSubordinate == null
                          ? _primaryColor
                          : Colors.grey.shade200,
                      child: Icon(
                        Icons.person,
                        color: _selectedSubordinate == null
                            ? Colors.white
                            : Colors.grey,
                      ),
                    ),
                    title: Text(
                      "My Territory (Self)",
                      style: TextStyle(
                        fontWeight: _selectedSubordinate == null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: _selectedSubordinate == null
                        ? Icon(Icons.check_circle, color: _primaryColor)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _onSubordinateChanged(null);
                    },
                  ),
                  ..._subordinates.map((sub) {
                    bool isSelected = _selectedSubordinate?['id'] == sub['id'];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? _primaryColor
                            : Colors.grey.shade200,
                        child: Icon(
                          Icons.group,
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                      ),
                      // --- ADDED NULL SAFETY HERE ---
                      title: Text(
                        sub['name']?.toString() ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        sub['designation']?.toString() ?? 'Team Member',
                      ),
                      // ------------------------------
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: _primaryColor)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _onSubordinateChanged(sub);
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(int done, int total) {
    double progress = total == 0 ? 0 : done / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your Daily Goal",
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "$done",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    TextSpan(
                      text: " / $total Visited",
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChemistCard(Chemist chemist, {required bool isPlanned}) {
    final isReported = Provider.of<ReportProvider>(
      context,
      listen: false,
    ).chemistReports.any((r) => r.chemistId == chemist.id.toString());

    String initials = chemist.name.isNotEmpty
        ? chemist.name[0].toUpperCase()
        : "C";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              if (isPlanned)
                Container(
                  width: 4,
                  color: isReported ? Colors.green : Colors.teal.shade300,
                ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChemistReportingScreen(
                          chemistId: chemist.id.toString(),
                          chemistName: chemist.name,
                          isPlanned: isPlanned,
                        ),
                      ),
                    ).then((_) {
                      Provider.of<ReportProvider>(
                        context,
                        listen: false,
                      ).fetchTodayChemistData();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isReported
                                  ? Colors.green.shade50
                                  : (isPlanned
                                        ? Colors.teal.shade50
                                        : Colors.grey.shade100),
                              child: isReported
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : Icon(
                                      Icons.storefront,
                                      color: isPlanned
                                          ? _primaryColor
                                          : Colors.grey.shade700,
                                    ),
                            ),
                            if (isPlanned && !isReported)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.star,
                                    color: Colors.orange,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chemist.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: isReported
                                      ? Colors.grey
                                      : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      chemist.area,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (chemist.territoryType != null &&
                                  chemist.territoryType!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildTag(
                                  chemist.territoryType!,
                                  const Color(0xFFE0F2F1),
                                  const Color(0xFF00695C),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),
              SizedBox(
                width: 50,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    InkWell(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddChemistScreen(chemistToEdit: chemist),
                          ),
                        );
                        if (result == true && mounted) {
                          Provider.of<ReportProvider>(
                            context,
                            listen: false,
                          ).fetchChemists(userId: _selectedSubordinate?['id']);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ),
                    Container(
                      height: 1,
                      width: 20,
                      color: Colors.grey.shade100,
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChemistHistoryScreen(
                              chemistId: chemist.id.toString(),
                              chemistName: chemist.name,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.history,
                          size: 20,
                          color: Colors.orange.shade600,
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

  Widget _buildTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textCol,
        ),
      ),
    );
  }
}
