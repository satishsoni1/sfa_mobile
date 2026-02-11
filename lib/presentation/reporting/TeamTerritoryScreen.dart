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
  List<dynamic> _subordinates = [];
  List<Doctor> _mrDoctors = [];
  dynamic _selectedMr;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSubordinates();
  }

  void _loadSubordinates() async {
    try {
      final data = await ApiService().getSubordinates();
      setState(() => _subordinates = data);
    } catch (e) {
      // Handle error
    }
  }

  void _onMrSelected(dynamic mr) async {
    setState(() {
      _selectedMr = mr;
      _isLoading = true;
      _mrDoctors = [];
    });

    try {
      final doctors = await ApiService().getDoctorsForUser(mr['id']);
      setState(() => _mrDoctors = doctors);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Matches Doctor List Bg
      appBar: AppBar(
        title: Text("Team Territory", style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF4A148C),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. SELECT MR DROPDOWN
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: DropdownButtonFormField<dynamic>(
              decoration: InputDecoration(
                labelText: "Select Subordinate (MR)",
                labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: const Icon(Icons.person_search, color: Color(0xFF4A148C)),
              ),
              value: _selectedMr,
              items: _subordinates.map<DropdownMenuItem<dynamic>>((mr) {
                return DropdownMenuItem(
                  value: mr,
                  child: Text(
                    "${mr['name']}",
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(),
                  ),
                );
              }).toList(),
              onChanged: _onMrSelected,
            ),
          ),

          // 2. DOCTOR LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedMr == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              "Select an MR to view their doctors",
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : _mrDoctors.isEmpty
                        ? Center(
                            child: Text(
                              "No doctors found for this MR",
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _mrDoctors.length,
                            itemBuilder: (context, index) {
                              return _buildDetailedDoctorCard(_mrDoctors[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  // --- REUSED DOCTOR CARD UI ---
  Widget _buildDetailedDoctorCard(Doctor doc) {
    String initials = doc.name.isNotEmpty ? doc.name[0].toUpperCase() : "D";
    
    // Check if YOU (The Manager) have reported for this doctor today
    final isReported = Provider.of<ReportProvider>(context, listen: false)
        .reports
        .any((r) => r.doctorId.toString() == doc.id.toString());

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
              // 1. LEFT ACCENT STRIP (Grey for team view, or logic based)
              Container(
                width: 4,
                color: isReported ? Colors.green : Colors.grey.shade300, 
              ),

              // 2. MAIN CONTENT
              Expanded(
                child: InkWell(
                  onTap: () {
                    // Navigate to Reporting (As Manager)
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
                        // AVATAR
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

                        // DETAILS
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 13, color: Colors.grey.shade500),
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

                              // TAGS
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
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
                                    _buildTag(doc.territoryType!, 
                                        const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
                                  if (doc.isKbl)
                                    _buildTag("KBL", 
                                        const Color(0xFFF3E5F5), const Color(0xFF7B1FA2)),
                                  if (doc.isFrd)
                                    _buildTag("FRD", 
                                        const Color(0xFFFFF3E0), const Color(0xFFE65100)),
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

              // 3. SEPARATOR
              Container(width: 1, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(vertical: 8)),

              // 4. ACTIONS COLUMN
              SizedBox(
                width: 50,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // EDIT (Manager Edit Subordinate's Doctor)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddDoctorScreen(doctorToEdit: doc),
                          ),
                        ).then((_) {
                          // Reload list after edit
                          if (_selectedMr != null) _onMrSelected(_selectedMr);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.edit_outlined, size: 20, color: Colors.blue.shade600),
                      ),
                    ),
                    
                    Container(height: 1, width: 20, color: Colors.grey.shade100),

                    // HISTORY
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
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.history, size: 20, color: Colors.orange.shade600),
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: textCol),
      ),
    );
  }
}