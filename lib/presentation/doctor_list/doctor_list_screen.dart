import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Providers & Services
import '../../providers/report_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/tour_plan.dart';

// Screens
import '../reporting/reporting_screen.dart';
import 'add_doctor_screen.dart';
import 'doctor_history_screen.dart';

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  List<int> _todayPlannedIds = [];
  bool _isLoadingPlan = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final provider = Provider.of<ReportProvider>(context, listen: false);
    await provider.fetchDoctors();
    await provider.fetchTodayData();

    try {
      final api = ApiService();
      final plans = await api.getTourPlans(DateTime.now());

      final todayPlan = plans.firstWhere(
        (p) => DateUtils.isSameDay(p.date, DateTime.now()),
        orElse: () => TourPlan(date: DateTime.now(), doctorIds: []),
      );

      if (mounted) {
        setState(() {
          _todayPlannedIds = todayPlan.doctorIds;
          _isLoadingPlan = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPlan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = Provider.of<ReportProvider>(context);
    final allDoctors = reportProvider.doctors;

    // --- FILTER LOGIC ---
    final searchResults = _searchQuery.isEmpty
        ? allDoctors
        : allDoctors
              .where(
                (doc) =>
                    doc.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    doc.area.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();

    final plannedSet = _todayPlannedIds.map((e) => e.toString()).toSet();
    final plannedDoctors = searchResults
        .where((d) => plannedSet.contains(d.id.toString()))
        .toList();
    final unplannedDoctors = searchResults
        .where((d) => !plannedSet.contains(d.id.toString()))
        .toList();
    // Calculate Progress for the "Dashboard" Widget
    int visitedCount = plannedDoctors
        .where(
          (doc) => reportProvider.reports.any((r) => r.doctorName == doc.name),
        )
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Softer grey background
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Doctor',
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
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddDoctorScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- HEADER SECTION (Progress + Search) ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF4A148C),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Progress Bar (Only show if there is a plan)
                if (plannedDoctors.isNotEmpty)
                  _buildProgressCard(visitedCount, plannedDoctors.length),

                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: "Search Doctor or Area...",
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF4A148C),
                    ),
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

          // --- LIST SECTION ---
          Expanded(
            child: reportProvider.isLoading || _isLoadingPlan
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.only(
                      top: 16,
                      left: 16,
                      right: 16,
                      bottom: 80,
                    ),
                    children: [
                      // PLANNED SECTION
                      if (plannedDoctors.isNotEmpty) ...[
                        _buildSectionHeader(
                          "PLANNED VISITS",
                          Icons.gps_fixed,
                          const Color(0xFF4A148C),
                        ),
                        ...plannedDoctors.map(
                          (doc) => _buildDoctorCard(doc, isPlanned: true),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // UNPLANNED SECTION
                      _buildSectionHeader(
                        plannedDoctors.isEmpty
                            ? "ALL DOCTORS"
                            : "OTHER DOCTORS",
                        Icons.people_outline,
                        Colors.grey.shade700,
                      ),

                      if (unplannedDoctors.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(30),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 40,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "No doctors found",
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...unplannedDoctors.map(
                          (doc) => _buildDoctorCard(doc, isPlanned: false),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: Daily Progress Summary ---
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

  Widget _buildDoctorCard(dynamic doc, {required bool isPlanned}) {
    // Logic: Check if reported
    final isReported = Provider.of<ReportProvider>(
      context,
      listen: false,
    ).reports.any((r) => r.doctorId == doc.id.toString());

    String initials = doc.name.isNotEmpty ? doc.name[0].toUpperCase() : "D";

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
              // Left Accent Strip for Planned
              if (isPlanned)
                Container(
                  width: 4,
                  color: isReported ? Colors.green : const Color(0xFFCE93D8),
                ),

              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportingScreen(
                          doctorId: doc.id.toString(),
                          doctorName: doc.name,
                          isPlanned: isPlanned,
                        ),
                      ),
                    ).then((_) {
                      Provider.of<ReportProvider>(
                        context,
                        listen: false,
                      ).fetchTodayData();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // AVATAR
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isReported
                                  ? Colors.green.shade50
                                  : (isPlanned
                                        ? Colors.purple.shade50
                                        : Colors.grey.shade100),
                              child: isReported
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : Text(
                                      initials,
                                      style: TextStyle(
                                        color: isPlanned
                                            ? const Color(0xFF4A148C)
                                            : Colors.grey.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
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

                        // DETAILS COLUMN
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name & Territory
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      doc.name,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: isReported
                                            ? Colors.grey
                                            : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Territory Tag (HQ/EX)
                                  if (doc.territoryType != null &&
                                      doc.territoryType!.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        doc.territoryType!,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              // Location
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
                                      doc.area,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Specialization & Tags
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    doc.specialization,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF4A148C),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  // Tags
                                  if (doc.isKbl)
                                    _buildTag(
                                      "KBL",
                                      const Color(0xFFE3F2FD),
                                      const Color(0xFF1565C0),
                                    ),
                                  if (doc.isFrd)
                                    _buildTag(
                                      "FRD",
                                      const Color(0xFFFFF3E0),
                                      const Color(0xFFEF6C00),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // SEPARATOR & HISTORY BUTTON
              Container(
                width: 1,
                color: Colors.grey.shade100,
                margin: const EdgeInsets.symmetric(vertical: 10),
              ),

              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorHistoryScreen(
                        doctorId: doc.id.toString(),
                        doctorName: doc.name,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        color: Colors.blueGrey.shade300,
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Hist",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.blueGrey.shade300,
                        ),
                      ),
                    ],
                  ),
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
