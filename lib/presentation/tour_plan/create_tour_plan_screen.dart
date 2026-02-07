import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart'; // Ensure you import this
import '../../providers/report_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/tour_plan.dart';

class CreateTourPlanScreen extends StatefulWidget {
  final DateTime initialDate;
  final TourPlan? existingPlan;

  const CreateTourPlanScreen({
    required this.initialDate,
    this.existingPlan,
    super.key,
  });

  @override
  State<CreateTourPlanScreen> createState() => _CreateTourPlanScreenState();
}

class _CreateTourPlanScreenState extends State<CreateTourPlanScreen> {
  late DateTime _date;
  Set<String> _selectedDoctorIds = {}; // Using Set for unique selection
  String _areaFilter = "All";
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    if (widget.existingPlan != null) {
      _selectedDoctorIds = widget.existingPlan!.doctorIds
          .map((e) => e.toString())
          .toSet();
    }
  }

  void _save() async {
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

    // Get unique Areas for filter
    final areas = ["All", ...allDoctors.map((d) => d.area).toSet().toList()];

    // Filter list
    final displayDoctors = _areaFilter == "All"
        ? allDoctors
        : allDoctors.where((d) => d.area == _areaFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          "Create Tour Plan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF4A148C),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. FILTER HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 5,
                ),
              ],
            ),
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
                        value: _areaFilter,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.filter_list,
                          color: Color(0xFF4A148C),
                        ),
                        items: areas
                            .map(
                              (a) => DropdownMenuItem(
                                value: a,
                                child: Text(
                                  a,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _areaFilter = v!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Quick Select All Button
                if (_areaFilter != "All")
                  InkWell(
                    onTap: () {
                      setState(() {
                        final idsInArea = displayDoctors
                            .map((d) => d.id.toString())
                            .toSet();

                        // Toggle logic
                        if (_selectedDoctorIds.containsAll(idsInArea)) {
                          _selectedDoctorIds.removeAll(idsInArea);
                        } else {
                          _selectedDoctorIds.addAll(idsInArea);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A148C).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF4A148C).withOpacity(0.3),
                        ),
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
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No doctors found in this area",
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: displayDoctors.length,
                    itemBuilder: (context, index) {
                      final doc = displayDoctors[index];
                      final String docId = doc.id.toString();
                      final bool isSelected = _selectedDoctorIds.contains(
                        docId,
                      );

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF4A148C)
                                : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        color: isSelected
                            ? const Color(0xFFF3E5F5)
                            : Colors.white,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
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
                                // Checkbox / Avatar Stack
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: isSelected
                                          ? const Color(0xFF4A148C)
                                          : Colors.purple.shade50,
                                      child: Text(
                                        doc.name.isNotEmpty
                                            ? doc.name[0].toUpperCase()
                                            : "?",
                                        style: GoogleFonts.poppins(
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF4A148C),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const CircleAvatar(
                                        radius: 8,
                                        backgroundColor: Colors.white,
                                        child: Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),

                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.name,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            doc.area,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Simple Checkbox for clarity (optional, since whole card is tapable)
                                Checkbox(
                                  value: isSelected,
                                  activeColor: const Color(0xFF4A148C),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedDoctorIds.add(docId);
                                      } else {
                                        _selectedDoctorIds.remove(docId);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 3. BOTTOM SUMMARY BAR
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${_selectedDoctorIds.length} Selected",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: const Color(0xFF4A148C),
                        ),
                      ),
                      Text(
                        "Tap list to modify",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A148C),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_alt, color: Colors.white),
                  label: Text(
                    _isSaving ? "Saving..." : "SAVE PLAN",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
