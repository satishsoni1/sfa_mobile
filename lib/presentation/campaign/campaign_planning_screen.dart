import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CampaignPlanningScreen extends StatefulWidget {
  final Map<String, dynamic> campaignData;

  const CampaignPlanningScreen({super.key, required this.campaignData});

  @override
  State<CampaignPlanningScreen> createState() => _CampaignPlanningScreenState();
}

class _CampaignPlanningScreenState extends State<CampaignPlanningScreen> {
  final Color _primaryColor = const Color(0xFF4A148C);
  final Color _bgColor = const Color(0xFFF4F6F9);

  List<dynamic> _doctors = [];
  List<int> _selectedDoctorIds = [];
  bool _isLoading = true;

  late int targetDoctors;

  @override
  void initState() {
    super.initState();
    targetDoctors = widget.campaignData['target_doctors'];
    _fetchDoctorsForPlanning();
  }

  Future<void> _fetchDoctorsForPlanning() async {
    // TODO: Replace with ApiService().getDoctorsMaster()
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      _doctors = [
        {
          "id": 1,
          "doctor_name": "Dr. Ramesh Gupta",
          "speciality": "Cardiologist",
          "area": "Andheri West",
          "is_kbl": 1,
        },
        {
          "id": 2,
          "doctor_name": "Dr. Anita Sharma",
          "speciality": "Pediatrician",
          "area": "Bandra",
          "is_kbl": 0,
        },
        {
          "id": 3,
          "doctor_name": "Dr. Vikas Verma",
          "speciality": "Gen. Physician",
          "area": "Fort",
          "is_kbl": 0,
        },
        {
          "id": 4,
          "doctor_name": "Dr. Aman Kamte",
          "speciality": "Dentist",
          "area": "Panvel",
          "is_kbl": 1,
        },
      ];
      _isLoading = false;
    });
  }

  void _toggleDoctorSelection(int id) {
    setState(() {
      if (_selectedDoctorIds.contains(id)) {
        _selectedDoctorIds.remove(id);
      } else {
        if (_selectedDoctorIds.length < targetDoctors) {
          _selectedDoctorIds.add(id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "You can only select $targetDoctors doctors for this campaign.",
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  Future<void> _submitPlan() async {
    if (_selectedDoctorIds.length != targetDoctors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please select exactly $targetDoctors doctors to proceed.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // TODO: Call API to submit selected doctors for this campaign
    // await _api.submitCampaignPlan(widget.campaignData['id'], _selectedDoctorIds);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Campaign Plan Submitted!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: Text("Plan Campaign", style: GoogleFonts.poppins(fontSize: 18)),
      ),
      body: Column(
        children: [
          // Header Rules
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.campaignData['name'],
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Mandate: Select exactly $targetDoctors doctors. You must visit each doctor ${widget.campaignData['visits_per_doctor']} times during the campaign period.",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Selection Counter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Select Doctors",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  "${_selectedDoctorIds.length} / $targetDoctors Selected",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _selectedDoctorIds.length == targetDoctors
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          // Doctor List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _doctors.length,
                    itemBuilder: (context, index) {
                      final doc = _doctors[index];
                      final isSelected = _selectedDoctorIds.contains(doc['id']);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? _primaryColor
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () => _toggleDoctorSelection(doc['id']),
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? _primaryColor
                                : Colors.grey.shade200,
                            child: Icon(
                              Icons.person,
                              color: isSelected ? Colors.white : Colors.grey,
                            ),
                          ),
                          title: Text(
                            doc['doctor_name'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            "${doc['speciality']} • ${doc['area']}",
                            style: GoogleFonts.poppins(fontSize: 11),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : const Icon(
                                  Icons.radio_button_unchecked,
                                  color: Colors.grey,
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedDoctorIds.length == targetDoctors
                  ? _primaryColor
                  : Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _selectedDoctorIds.length == targetDoctors
                ? _submitPlan
                : null,
            child: Text(
              "CONFIRM PLAN",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
