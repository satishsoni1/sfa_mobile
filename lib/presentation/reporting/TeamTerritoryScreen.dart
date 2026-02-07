import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/report_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/doctor.dart';
import '../reporting/reporting_screen.dart';

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
      _mrDoctors = []; // Clear previous
    });

    try {
      final doctors = await ApiService().getDoctorsForUser(mr['id']);
      setState(() => _mrDoctors = doctors);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error fetching doctors: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Team Territory Report"),
        backgroundColor: const Color(0xFF4A148C),
      ),
      body: Column(
        children: [
          // 1. SELECT MR DROPDOWN
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: DropdownButtonFormField<dynamic>(
              decoration: const InputDecoration(
                labelText: "Select Subordinate (MR)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_search),
              ),
              value: _selectedMr,
              items: _subordinates.map((mr) {
                return DropdownMenuItem(
                  value: mr,
                  child: Text("${mr['name']} (${mr['designation'] ?? 'MR'})"),
                );
              }).toList(),
              onChanged: _onMrSelected,
            ),
          ),

          const Divider(height: 1),

          // 2. DOCTOR LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedMr == null
                ? Center(
                    child: Text(
                      "Select an MR to view their doctors",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : _mrDoctors.isEmpty
                ? const Center(child: Text("No doctors found for this MR"))
                : ListView.builder(
                    itemCount: _mrDoctors.length,
                    itemBuilder: (context, index) {
                      final doc = _mrDoctors[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(child: Text(doc.name[0])),
                          title: Text(
                            doc.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("${doc.area} • ${doc.specialization}"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // Open Reporting Screen
                            // Since we are reporting as Manager, the submission logic in ReportingScreen
                            // uses Auth token, so it will be saved under Manager's ID.
                            // But the Doctor info comes from the MR's list. Perfect.
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
