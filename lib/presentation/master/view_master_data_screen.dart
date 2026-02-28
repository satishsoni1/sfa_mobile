import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zforce/data/services/api_service.dart';

class ViewMasterDataScreen extends StatefulWidget {
  final String assignedToId;

  const ViewMasterDataScreen({super.key, required this.assignedToId});

  @override
  State<ViewMasterDataScreen> createState() => _ViewMasterDataScreenState();
}

class _ViewMasterDataScreenState extends State<ViewMasterDataScreen> {
  bool _isLoading = true;
  List<dynamic> _doctors = [];
  List<dynamic> _chemists = [];

  @override
  void initState() {
    super.initState();
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    try {
      final response = await ApiService().getUploadedMasterData(
        widget.assignedToId,
      );

      setState(() {
        _doctors = response['data']['doctors'] ?? [];
        _chemists = response['data']['chemists'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text(
            'Uploaded Master Data',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF4A148C),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.local_hospital), text: "Doctors"),
              Tab(icon: Icon(Icons.storefront), text: "Chemists"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4A148C)),
              )
            : TabBarView(
                children: [
                  // TAB 1: Doctors List
                  _ActualDataList(type: "Doctor", items: _doctors),

                  // TAB 2: Chemists List
                  _ActualDataList(type: "Chemist", items: _chemists),
                ],
              ),
      ),
    );
  }
}

class _ActualDataList extends StatelessWidget {
  final String type;
  final List<dynamic> items;

  const _ActualDataList({required this.type, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == "Doctor"
                  ? Icons.medical_services_outlined
                  : Icons.storefront_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "No $type Data Found",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        if (type == "Doctor") {
          return _buildDoctorCard(item);
        } else {
          return _buildChemistCard(item);
        }
      },
    );
  }

  // --- DOCTOR CARD (EXPANDABLE) ---
  Widget _buildDoctorCard(dynamic item) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        // Remove expansion tile borders
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: const Color(0xFF4A148C),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF4A148C).withOpacity(0.1),
            child: const Icon(Icons.medical_services, color: Color(0xFF4A148C)),
          ),
          title: Text(
            item['doctor_name'] ?? 'Unknown Doctor',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            item['speciality'] ?? 'No Speciality',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.category, "Category", item['category']),
            _buildDetailRow(
              Icons.merge_type,
              "KBL/FRD/Other",
              item['kbl_frd_other'],
            ),
            _buildDetailRow(
              Icons.location_city,
              "Area/Town",
              item['area_town'],
            ),
            _buildDetailRow(
              Icons.format_list_numbered,
              "No. of Visits",
              item['no_of_visit']?.toString(),
            ),
          ],
        ),
      ),
    );
  }

  // --- CHEMIST CARD (EXPANDABLE) ---
  Widget _buildChemistCard(dynamic item) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.teal.shade700,
          leading: CircleAvatar(
            backgroundColor: Colors.teal.shade50,
            child: Icon(Icons.storefront, color: Colors.teal.shade700),
          ),
          title: Text(
            item['chemist_name'] ?? 'Unknown Chemist',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            item['area'] ?? 'No Area',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.person_outline,
              "Contact Person",
              item['contact_person'],
            ),
            _buildDetailRow(
              Icons.phone_android,
              "Mobile No.",
              item['mobile_no'],
            ),
            _buildDetailRow(Icons.map_outlined, "Address", item['address']),
            _buildDetailRow(
              Icons.pin_drop_outlined,
              "Pincode",
              item['pincode'],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to display a row of data
  Widget _buildDetailRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                children: [
                  TextSpan(
                    text: "$label: ",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  TextSpan(
                    text: (value == null || value.trim().isEmpty)
                        ? "N/A"
                        : value,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
