import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/report_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/tour_plan.dart';

class CreateTourPlanScreen extends StatefulWidget {
  final DateTime initialDate;
  final TourPlan? existingPlan;
  final bool isReadOnly; // NEW: Lock editing

  const CreateTourPlanScreen({
    required this.initialDate,
    this.existingPlan,
    this.isReadOnly = false, // Default false
    super.key,
  });

  @override
  State<CreateTourPlanScreen> createState() => _CreateTourPlanScreenState();
}

class _CreateTourPlanScreenState extends State<CreateTourPlanScreen> {
  late DateTime _date;
  Set<String> _selectedDoctorIds = {};
  String _areaFilter = "All";
  bool _isSaving = false;
  bool _isLoadingDoctors = true;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    if (widget.existingPlan != null) {
      _selectedDoctorIds = widget.existingPlan!.doctorIds
          .map((e) => e.toString())
          .toSet();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadDoctors();
    });
  }

  Future<void> _checkAndLoadDoctors() async {
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    if (reportProvider.doctors.isNotEmpty) {
      if (mounted) setState(() => _isLoadingDoctors = false);
      return;
    }
    try {
      await reportProvider.fetchDoctors();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load doctors: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoadingDoctors = false);
    }
  }

  void _save() async {
    // PREVENT SAVE IF READ ONLY
    if (widget.isReadOnly) return;

    if (_selectedDoctorIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Select at least one doctor"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ApiService().saveTourPlan(
        _date,
        _selectedDoctorIds.map((e) => int.parse(e)).toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tour Plan Saved!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allDoctors = Provider.of<ReportProvider>(context).doctors;
    final areas = ["All", ...allDoctors.map((d) => d.area).toSet().toList()];

    // Filter Logic
    final displayDoctors = _areaFilter == "All"
        ? allDoctors
        : allDoctors.where((d) => d.area == _areaFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          widget.isReadOnly ? "View Plan (Locked)" : "Edit Tour Plan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF4A148C),
        elevation: 0,
      ),
      body: _isLoadingDoctors
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. FILTER HEADER (Hide if ReadOnly to clean UI)
                if (!widget.isReadOnly)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: areas.contains(_areaFilter)
                                    ? _areaFilter
                                    : "All",
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.filter_list,
                                  color: Color(0xFF4A148C),
                                ),
                                items: areas
                                    .map(
                                      (a) => DropdownMenuItem(
                                        value: a,
                                        child: Text(a),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _areaFilter = v!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Select All
                        InkWell(
                          onTap: () {
                            setState(() {
                              final idsInArea = displayDoctors
                                  .map((d) => d.id.toString())
                                  .toSet();
                              if (_selectedDoctorIds.containsAll(idsInArea)) {
                                _selectedDoctorIds.removeAll(idsInArea);
                              } else {
                                _selectedDoctorIds.addAll(idsInArea);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A148C).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.select_all,
                              color: Color(0xFF4A148C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 2. DOCTOR LIST
                Expanded(
                  child: displayDoctors.isEmpty
                      ? const Center(child: Text("No doctors found"))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: displayDoctors.length,
                          itemBuilder: (context, index) {
                            final doc = displayDoctors[index];
                            final String docId = doc.id.toString();
                            final bool isSelected = _selectedDoctorIds.contains(
                              docId,
                            );

                            // IF READ-ONLY: Hide unselected doctors entirely
                            if (widget.isReadOnly && !isSelected)
                              return const SizedBox.shrink();

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF4A148C)
                                      : Colors.grey.shade200,
                                ),
                              ),
                              color: isSelected
                                  ? const Color(0xFFF3E5F5)
                                  : Colors.white,
                              child: InkWell(
                                // DISABLE TAP IF READ ONLY
                                onTap: widget.isReadOnly
                                    ? null
                                    : () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedDoctorIds.remove(docId);
                                          } else {
                                            _selectedDoctorIds.add(docId);
                                          }
                                        });
                                      },
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: isSelected
                                            ? const Color(0xFF4A148C)
                                            : Colors.grey[200],
                                        child: Text(
                                          doc.name.isNotEmpty
                                              ? doc.name[0].toUpperCase()
                                              : "?",
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF4A148C),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              doc.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              doc.area,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Hide Checkbox if ReadOnly to look cleaner
                                      if (!widget.isReadOnly)
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          color: isSelected
                                              ? const Color(0xFF4A148C)
                                              : Colors.grey,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // 3. BOTTOM BAR (Hide completely if ReadOnly)
                if (!widget.isReadOnly)
                  Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${_selectedDoctorIds.length} Selected",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A148C),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 12,
                            ),
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
                              : const Text(
                                  "SAVE PLAN",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
