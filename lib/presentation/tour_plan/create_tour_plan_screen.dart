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
  Set<String> _selectedDoctorIds = {};
  List<Doctor> _availableDoctors = [];
  List<dynamic> _subordinates = [];
  
  // Controls
  int? _selectedContextUserId; // Logic: Whose doctors are we currently viewing?
  String _areaFilter = "All";
  bool _isLoading = true;
  bool _isSaving = false;

  final Color _primaryColor = const Color(0xFF4A148C);

  @override
  void initState() {
    super.initState();
    // 1. Restore previous selection
    if (widget.existingPlan != null) {
      _selectedDoctorIds = widget.existingPlan!.doctorIds.map((e) => e.toString()).toSet();
    }
    
    // 2. Set Context
    // If viewing subordinate -> Context is subordinate ID.
    // If viewing myself -> Context is null.
    _selectedContextUserId = widget.targetUserId;

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Load Subordinates (Only if creating OWN plan, to allow selecting them)
      if (!widget.isReadOnly && widget.targetUserId == null) {
        final subs = await ApiService().getSubordinates();
        if (mounted) setState(() => _subordinates = subs);
      }
      // Load doctors for the current context
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
        // CASE A: My Doctors (Check cache first)
        final provider = Provider.of<ReportProvider>(context, listen: false);
        if (provider.doctors.isEmpty) await provider.fetchDoctors();
        docs = provider.doctors;
      } else {
        // CASE B: Subordinate's Doctors (Always fetch fresh from API)
        docs = await ApiService().getDoctorsForUser(userId);
      }

      if (mounted) {
        setState(() {
          _availableDoctors = docs;
          _selectedContextUserId = userId;
          _areaFilter = "All"; // Reset filter when switching user
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load doctors: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _save() async {
    // SECURITY: Prevent saving if viewing someone else's plan
    if (widget.isReadOnly || widget.targetUserId != null) return;

    if (_selectedDoctorIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least one doctor"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Save for Self (Auth::id)
      await ApiService().saveTourPlan(
        widget.initialDate,
        _selectedDoctorIds.map((e) => int.parse(e)).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan Saved!"), backgroundColor: Colors.green));
        Navigator.pop(context, true); // Return true to refresh dashboard
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filters
    final areas = ["All", ..._availableDoctors.map((d) => d.area).toSet().toList()];
    final displayDoctors = _areaFilter == "All" 
        ? _availableDoctors 
        : _availableDoctors.where((d) => d.area == _areaFilter).toList();

    // Show controls ONLY if editing own plan (Not ReadOnly & Not Subordinate View)
    bool showControls = !widget.isReadOnly && widget.targetUserId == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isReadOnly ? "View Plan" : "Create Plan", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            Text("${DateFormat('dd MMM').format(widget.initialDate)} • ${widget.targetUserName}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          // HEADER: Dropdown + Filters
          if (showControls)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Subordinate Dropdown (For Joint Work Selection)
                  if (_subordinates.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedContextUserId,
                          isExpanded: true,
                          icon: Icon(Icons.person_search, color: _primaryColor),
                          hint: const Text("Select Territory / User"),
                          items: [
                            const DropdownMenuItem(value: null, child: Text("Myself (My Territory)")),
                            ..._subordinates.map((sub) => DropdownMenuItem<int>(value: sub['id'] as int, child: Text("${sub['name']} (Subordinate)"))),
                          ],
                          onChanged: _fetchDoctorsForContext,
                        ),
                      ),
                    ),
                  
                  // Area Filter & Select All
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: areas.contains(_areaFilter) ? _areaFilter : "All",
                              isExpanded: true,
                              icon: Icon(Icons.filter_list, color: _primaryColor),
                              items: areas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                              onChanged: (v) => setState(() => _areaFilter = v!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () {
                          setState(() {
                            final visibleIds = displayDoctors.map((d) => d.id.toString()).toSet();
                            if (_selectedDoctorIds.containsAll(visibleIds)) _selectedDoctorIds.removeAll(visibleIds);
                            else _selectedDoctorIds.addAll(visibleIds);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.select_all, color: _primaryColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // DOCTOR LIST
          Expanded(
            child: _isLoading 
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : displayDoctors.isEmpty
                    ? Center(child: Text("No doctors found", style: GoogleFonts.poppins(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: displayDoctors.length,
                        itemBuilder: (context, index) {
                          final doc = displayDoctors[index];
                          final isSelected = _selectedDoctorIds.contains(doc.id.toString());
                          
                          // If ReadOnly, hide unchecked items to clean up UI
                          if (widget.isReadOnly && !isSelected) return const SizedBox.shrink();

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isSelected ? const Color(0xFFEDE7F6) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? _primaryColor : Colors.grey.shade200)),
                            child: InkWell(
                              onTap: widget.isReadOnly ? null : () {
                                setState(() {
                                  if (isSelected) _selectedDoctorIds.remove(doc.id.toString());
                                  else _selectedDoctorIds.add(doc.id.toString());
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isSelected ? _primaryColor : Colors.grey.shade200,
                                      child: Text(doc.name.isNotEmpty ? doc.name[0].toUpperCase() : "?", style: TextStyle(color: isSelected ? Colors.white : Colors.black54, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(doc.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                                          Text("${doc.area} • ${doc.specialization}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ),
                                    if (!widget.isReadOnly)
                                      Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? _primaryColor : Colors.grey.shade400),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // SAVE BUTTON (Hide if ReadOnly or Subordinate View)
          if (!widget.isReadOnly && widget.targetUserId == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("SAVE PLAN (${_selectedDoctorIds.length} Doctors)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}