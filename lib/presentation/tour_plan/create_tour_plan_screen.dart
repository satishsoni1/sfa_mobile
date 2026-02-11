import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/report_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/doctor.dart';
import '../../data/models/tour_plan.dart';

class CreateTourPlanScreen extends StatefulWidget {
  final DateTime initialDate;
  final TourPlan? existingPlan;
  final bool isReadOnly;
  final int? targetUserId; // NULL = Self
  final String targetUserName;

  const CreateTourPlanScreen({
    required this.initialDate,
    this.existingPlan,
    this.isReadOnly = false,
    this.targetUserId,
    this.targetUserName = "Myself",
    super.key,
  });

  @override
  State<CreateTourPlanScreen> createState() => _CreateTourPlanScreenState();
}

class _CreateTourPlanScreenState extends State<CreateTourPlanScreen> {
  // --- Doctor Selection State ---
  Set<String> _selectedDoctorIds = {};
  List<Doctor> _availableDoctors = [];
  List<dynamic> _subordinates = [];

  // --- Activity Selection State ---
  bool _isActivity = false;
  String? _selectedActivityType;
  final List<String> _activityTypes = [
    'Meeting',
    'Campaign',
    'Leave',
    'Holiday',
    'Admin Work',
  ];

  // --- UI Controls ---
  int? _selectedContextUserId;
  String _areaFilter = "All";
  bool _isLoading = true;
  bool _isSaving = false;

  final Color _primaryColor = const Color(0xFF4A148C);
  final Color _plannedColor = const Color(
    0xFFE8F5E9,
  ); // Light Green for existing plans

  @override
  void initState() {
    super.initState();
    if (widget.existingPlan != null) {
      _selectedDoctorIds = widget.existingPlan!.doctorIds
          .map((e) => e.toString())
          .toSet();
      _isActivity = widget.existingPlan!.isActivity;
      _selectedActivityType = widget.existingPlan!.activityType;
    }

    _selectedContextUserId = widget.targetUserId;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      if (!widget.isReadOnly && widget.targetUserId == null) {
        final subs = await ApiService().getSubordinates();
        if (mounted) setState(() => _subordinates = subs);
      }
      await _fetchDoctorsForContext(_selectedContextUserId);
    } catch (e) {
      debugPrint("Init Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDoctorsForContext(int? userId) async {
    setState(() => _isLoading = true);
    try {
      List<Doctor> docs = [];
      if (userId == null) {
        // CASE A: My Doctors
        final provider = Provider.of<ReportProvider>(context, listen: false);
        if (provider.doctors.isEmpty) await provider.fetchDoctors();
        docs = provider.doctors;
      } else {
        // CASE B: Subordinate's Doctors (Using NEW API with Date)
        // This fetches doctors AND marks which ones are already planned for this specific date
        docs = await ApiService().getDoctorsWithPlanStatus(
          userId,
          widget.initialDate,
        );
      }

      if (mounted) {
        setState(() {
          _availableDoctors = docs;
          _selectedContextUserId = userId;
          _areaFilter = "All";
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load doctors: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _save() async {
    if (widget.isReadOnly || widget.targetUserId != null) return;

    if (_isActivity) {
      if (_selectedActivityType == null) {
        _showError("Select activity type");
        return;
      }
    } else {
      if (_selectedDoctorIds.isEmpty) {
        _showError("Select at least one doctor");
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final planData = {
        'plan_date': widget.initialDate.toIso8601String().split('T').first,
        'is_activity': _isActivity,
        'activity_type': _isActivity ? _selectedActivityType : null,
        'doctor_ids': _isActivity
            ? []
            : _selectedDoctorIds.map((e) => int.parse(e)).toList(),
        'status': 'Draft',
      };

      await ApiService().addTourPlan(planData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Plan Saved!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orange),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filters
    final areas = [
      "All",
      ..._availableDoctors.map((d) => d.area).toSet().toList(),
    ];
    final displayDoctors = _areaFilter == "All"
        ? _availableDoctors
        : _availableDoctors.where((d) => d.area == _areaFilter).toList();

    // Sort: Put "Planned by Subordinate" doctors at the top for visibility
    displayDoctors.sort((a, b) {
      if ((a.isPlanned ?? false) && !(b.isPlanned ?? false)) return -1;
      if (!(a.isPlanned ?? false) && (b.isPlanned ?? false)) return 1;
      return a.name.compareTo(b.name);
    });

    bool canEdit = !widget.isReadOnly && widget.targetUserId == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isReadOnly ? "View Plan" : "Create Plan",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "${DateFormat('dd MMM').format(widget.initialDate)} • ${widget.targetUserName}",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 1. TOP CONTROLS
          if (canEdit)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Activity Toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _buildToggleBtn("Field Work", !_isActivity),
                        _buildToggleBtn("Activity", _isActivity),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_isActivity)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Select Activity Type",
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedActivityType,
                      items: _activityTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedActivityType = val),
                    )
                  else ...[
                    // Subordinate Dropdown
                    if (_subordinates.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _selectedContextUserId,
                            isExpanded: true,
                            icon: Icon(
                              Icons.person_search,
                              color: _primaryColor,
                            ),
                            hint: const Text("Select Territory / User"),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text("Myself (My Territory)"),
                              ),
                              ..._subordinates.map(
                                (sub) => DropdownMenuItem<int>(
                                  value: sub['id'] as int,
                                  child: Text("${sub['name']} (Subordinate)"),
                                ),
                              ),
                            ],
                            onChanged: _fetchDoctorsForContext,
                          ),
                        ),
                      ),

                    // Area Filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: areas.contains(_areaFilter)
                              ? _areaFilter
                              : "All",
                          isExpanded: true,
                          items: areas
                              .map(
                                (a) =>
                                    DropdownMenuItem(value: a, child: Text(a)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _areaFilter = v!),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // 2. MAIN LIST
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : _isActivity
                ? _buildActivityPlaceholder()
                : _buildDoctorList(displayDoctors),
          ),

          // 3. SAVE BUTTON
          if (canEdit)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isActivity
                            ? "SAVE ACTIVITY"
                            : "SAVE PLAN (${_selectedDoctorIds.length})",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Helpers ---

  Widget _buildToggleBtn(String label, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isActivity = label.contains("Activity")),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? _primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No doctors required for Activity",
            style: GoogleFonts.poppins(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorList(List<Doctor> displayDoctors) {
    if (displayDoctors.isEmpty) {
      return Center(
        child: Text(
          "No doctors found",
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: displayDoctors.length,
      itemBuilder: (context, index) {
        final doc = displayDoctors[index];
        final isSelected = _selectedDoctorIds.contains(doc.id.toString());

        // CHECK: Is this doctor already planned by the subordinate?
        final bool isSubordinatePlanned = doc.isPlanned == true;

        if (widget.isReadOnly && !isSelected) return const SizedBox.shrink();

        return GestureDetector(
          onTap: widget.isReadOnly
              ? null
              : () {
                  setState(() {
                    if (isSelected)
                      _selectedDoctorIds.remove(doc.id.toString());
                    else
                      _selectedDoctorIds.add(doc.id.toString());
                  });
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              // Highlight if planned by subordinate OR selected by manager
              color: isSubordinatePlanned
                  ? _plannedColor // Green background if planned by sub
                  : (isSelected
                        ? _primaryColor.withOpacity(0.08)
                        : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? _primaryColor
                    : (isSubordinatePlanned
                          ? Colors.green.shade300
                          : Colors.grey.shade200),
                width: isSelected || isSubordinatePlanned ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _primaryColor
                          : (isSubordinatePlanned
                                ? Colors.green
                                : Colors.grey.shade100),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        doc.name.isNotEmpty ? doc.name[0].toUpperCase() : "?",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: (isSelected || isSubordinatePlanned)
                              ? Colors.white
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Info
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

                        // Badge Row
                        Row(
                          children: [
                            Text(
                              "${doc.area} • ${doc.specialization}",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            // SHOW "PLANNED" BADGE
                            if (isSubordinatePlanned) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "PLANNED",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Selection Checkmark
                  if (!widget.isReadOnly)
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? _primaryColor : Colors.grey.shade400,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
