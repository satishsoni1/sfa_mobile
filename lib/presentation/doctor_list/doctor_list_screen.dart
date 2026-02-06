import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

// Providers & Screens
import '../../providers/report_provider.dart';
import '../reporting/reporting_screen.dart';
import 'add_doctor_screen.dart';
import 'doctor_history_screen.dart'; // <--- NEW IMPORT

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  // SEARCH CONTROLLER
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    // TRIGGER FETCH ON LOAD
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportProvider>(context, listen: false).fetchDoctors();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = Provider.of<ReportProvider>(context);
    
    // Filter Logic
    final allDoctors = reportProvider.doctors;
    final displayedDoctors = _searchQuery.isEmpty 
        ? allDoctors 
        : allDoctors.where((doc) => 
            doc.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
            doc.area.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text('Select Doctor', style: GoogleFonts.poppins(fontSize: 18)),
        backgroundColor: const Color(0xFF4A148C),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDoctorScreen())),
          )
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF4A148C),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search by Name or Area...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              ),
            ),
          ),
          
          // List
          Expanded(
            child: reportProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayedDoctors.isEmpty
                    ? Center(child: Text("No doctors found.", style: GoogleFonts.poppins(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayedDoctors.length,
                        itemBuilder: (context, index) {
                          final doc = displayedDoctors[index];
                          
                          // Helper for Initials
                          String initials = doc.name.isNotEmpty ? doc.name[0].toUpperCase() : "D";
                          if (doc.name.split(" ").length > 1) {
                             initials += doc.name.split(" ")[1][0].toUpperCase();
                          }

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ReportingScreen(doctorName: doc.name)
                                ));
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center, // Aligned center for better icon placement
                                  children: [
                                    // 1. Avatar
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: const Color(0xFFE1BEE7),
                                      child: Text(initials, style: const TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // 2. Info Column
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Name + Territory Badge
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  doc.name, 
                                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (doc.territoryType != null)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 6),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.grey.shade400)
                                                  ),
                                                  child: Text(
                                                    doc.territoryType!, 
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)
                                                  ),
                                                )
                                            ],
                                          ),
                                          
                                          const SizedBox(height: 4),
                                          
                                          // Area (City)
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(doc.area, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                                            ],
                                          ),
                                          
                                          const SizedBox(height: 6),

                                          // Specialization + Tags
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                doc.specialization, 
                                                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF4A148C), fontWeight: FontWeight.w500)
                                              ),
                                              Container(height: 12, width: 1, color: Colors.grey.shade300),
                                              if (doc.isKbl) _buildTag("KBL", Colors.blue.shade50, Colors.blue.shade700),
                                              if (doc.isFrd) _buildTag("FRD", Colors.orange.shade50, Colors.orange.shade800),
                                              if (doc.isOther) _buildTag("General", Colors.green.shade50, Colors.green.shade700),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    
                                    // 3. ACTION BUTTONS (History | Chevron)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // --- NEW HISTORY BUTTON ---
                                        IconButton(
                                          icon: const Icon(Icons.history, color: Colors.blueAccent),
                                          tooltip: "View History",
                                          onPressed: () {
                                            Navigator.push(context, MaterialPageRoute(
                                              builder: (_) => DoctorHistoryScreen(doctorName: doc.name)
                                            ));
                                          },
                                        ),
                                        // Standard Chevron to indicate "Tap to Report"
                                        const Icon(Icons.chevron_right, color: Colors.grey),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Helper for small colored tags
  Widget _buildTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textCol.withOpacity(0.3))
      ),
      child: Text(
        text, 
        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: textCol)
      ),
    );
  }
}