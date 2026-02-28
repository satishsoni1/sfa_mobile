import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/report_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/doctor.dart';
import '../reporting/reporting_screen.dart';
import '../doctor_list/add_doctor_screen.dart';
import '../doctor_list/doctor_history_screen.dart';

class TeamTerritoryScreen extends StatefulWidget {
  const TeamTerritoryScreen({super.key});

  @override
  State<TeamTerritoryScreen> createState() => _TeamTerritoryScreenState();
}

class _TeamTerritoryScreenState extends State<TeamTerritoryScreen> {
  // Data Lists
  List<dynamic> _allSubordinates = [];
  List<Doctor> _allMrDoctors = [];
  List<Doctor> _filteredDoctors = [];

  // Selection & State
  dynamic _selectedMr;
  bool _isLoading = false;

  // Controllers
  final TextEditingController _doctorSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSubordinates();
  }

  // --- LOGIC: SUBORDINATES (MRs) ---

  void _loadSubordinates() async {
    try {
      final data = await ApiService().getSubordinates();
      setState(() {
        _allSubordinates = data;
      });
    } catch (e) {
      debugPrint("Error loading subordinates: $e");
    }
  }

  // --- LOGIC: DOCTORS ---

  void _onMrSelected(dynamic mr) async {
    setState(() {
      _selectedMr = mr;
      _isLoading = true;
      _allMrDoctors = [];
      _filteredDoctors = [];
      _doctorSearchController.clear(); // Clear doctor search when MR changes
    });

    try {
      final doctors = await ApiService().getDoctorsForUser(mr['id']);
      setState(() {
        _allMrDoctors = doctors;
        _filteredDoctors = doctors;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading doctors: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterDoctors(String query) {
    setState(() {
      _filteredDoctors = _allMrDoctors
          .where(
            (doc) =>
                doc.name.toLowerCase().contains(query.toLowerCase()) ||
                doc.area.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  // --- LOGIC: BOTTOM SHEET ---
  void _showSubordinatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SubordinateSearchSheet(
        allSubordinates: _allSubordinates,
        selectedMr: _selectedMr,
        onSelect: (mr) {
          _onMrSelected(mr);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("Team Territory", style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF4A148C),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. TOP PANEL: NEW SLEEK SUBORDINATE SELECTOR
          _buildSubordinateSelector(),

          // 2. DOCTOR SEARCH BAR (Visible only when MR is selected)
          if (_selectedMr != null && !_isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _doctorSearchController,
                  onChanged: _filterDoctors,
                  decoration: InputDecoration(
                    hintText: "Search doctor by name or area...",
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _doctorSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () {
                              _doctorSearchController.clear();
                              _filterDoctors("");
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

          // 3. MAIN CONTENT (DOCTOR LIST)
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4A148C)),
                  )
                : _selectedMr == null
                ? _buildEmptyState(
                    "Tap above to select a subordinate",
                    Icons.groups,
                  )
                : _filteredDoctors.isEmpty
                ? _buildEmptyState(
                    "No doctors found in this territory",
                    Icons.person_off,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredDoctors.length,
                    itemBuilder: (context, index) {
                      return _buildDetailedDoctorCard(_filteredDoctors[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSubordinateSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: _showSubordinatePicker,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF4A148C).withOpacity(0.08),
                child: const Icon(
                  Icons.person_search,
                  size: 20,
                  color: Color(0xFF4A148C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reporting Subordinate (BD)",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedMr != null
                          ? _selectedMr['name']
                          : "Tap to search & select...",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _selectedMr != null
                            ? Colors.black87
                            : Colors.grey.shade400,
                        fontWeight: _selectedMr != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.unfold_more_rounded, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
            ),
            child: Icon(icon, size: 60, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedDoctorCard(Doctor doc) {
    String initials = doc.name.isNotEmpty ? doc.name[0].toUpperCase() : "D";
    final isReported = Provider.of<ReportProvider>(
      context,
      listen: false,
    ).reports.any((r) => r.doctorId.toString() == doc.id.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              Container(
                width: 4,
                color: isReported ? Colors.green : Colors.grey.shade300,
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
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isReported
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          child: isReported
                              ? const Icon(Icons.check, color: Colors.green)
                              : Text(
                                  initials,
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
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
                                overflow: TextOverflow.ellipsis,
                              ),
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
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (doc.specialization.isNotEmpty)
                                    Text(
                                      doc.specialization,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: const Color(0xFF4A148C),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  if (doc.territoryType != null)
                                    _buildTag(
                                      doc.territoryType!,
                                      const Color(0xFFE3F2FD),
                                      const Color(0xFF1565C0),
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
              // Action Column
              SizedBox(
                width: 50,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: Colors.blue.shade600,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddDoctorScreen(doctorToEdit: doc),
                          ),
                        ).then((_) {
                          if (_selectedMr != null) _onMrSelected(_selectedMr);
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.history,
                        size: 20,
                        color: Colors.orange.shade600,
                      ),
                      onPressed: () {
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

// =========================================================================
// CUSTOM SUBORDINATE SEARCH BOTTOM SHEET
// =========================================================================

class _SubordinateSearchSheet extends StatefulWidget {
  final List<dynamic> allSubordinates;
  final dynamic selectedMr;
  final Function(dynamic) onSelect;

  const _SubordinateSearchSheet({
    required this.allSubordinates,
    this.selectedMr,
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
    _filteredList = widget.allSubordinates;
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      _filteredList = widget.allSubordinates.where((mr) {
        final name = mr['name']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
                  "Select Subordinate",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Search TextField
                TextField(
                  onChanged: _filter,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Search by name...",
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF4A148C),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
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
            child: _filteredList.isEmpty
                ? Center(
                    child: Text(
                      "No subordinates found",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      var mr = _filteredList[index];
                      bool isSelected = widget.selectedMr?['id'] == mr['id'];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? const Color(0xFF4A148C)
                              : Colors.grey.shade100,
                          child: Text(
                            mr['name'].toString().substring(0, 1).toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          mr['name'],
                          style: GoogleFonts.poppins(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF4A148C)
                                : Colors.black87,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF4A148C),
                              )
                            : null,
                        onTap: () {
                          widget.onSelect(mr);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
