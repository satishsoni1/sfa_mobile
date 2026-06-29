import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/visit_report.dart';

class DoctorHistoryScreen extends StatefulWidget {
  final String doctorId; // Changed from doctorName
  final String doctorName;

  const DoctorHistoryScreen({
    required this.doctorId,
    required this.doctorName,
    super.key,
  });

  @override
  State<DoctorHistoryScreen> createState() => _DoctorHistoryScreenState();
}

class _DoctorHistoryScreenState extends State<DoctorHistoryScreen> {
  bool _isLoading = true;
  List<VisitReport> _history = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final apiService = ApiService();
      // We will add this method to ApiService shortly
      final data = await apiService.getDoctorHistory(widget.doctorId);
      if (mounted) {
        setState(() {
          _history = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Visit History", style: GoogleFonts.poppins(fontSize: 14)),
            Text(
              widget.doctorName,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4A148C),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    "No history found for this doctor.",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final visit = _history[index];
                return _buildHistoryCard(visit);
              },
            ),
    );
  }

  Widget _buildHistoryCard(VisitReport visit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6, 
      shadowColor: Colors.black.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date & Time
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Color(0xFF4A148C),
                    ),
                    const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('dd MMM yyyy - hh:mm a').format(visit.visitTime),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Remarks Subcard
            if (visit.remarks.isNotEmpty)
              _buildSubCard(
                "Remarks",
                Text(
                  visit.remarks,
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Colors.blue.shade50,
                Colors.blue.shade200,
              ),

            // Dr Business Value Subcard
            _buildSubCard(
              "Dr Business Value as per PTS",
              Text(
                visit.businessValuePts > 0 ? visit.businessValuePts.toString() : "-",
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              Colors.purple.shade50,
              Colors.purple.shade200,
            ),

            // Joint Work
            if (visit.rawJointWork.isNotEmpty)
              _buildSubCard(
                "Joint Work",
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: visit.rawJointWork.map((item) {
                    final name = item['name'] ?? item['employee_name'] ?? 'Unknown';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text("• $name", style: GoogleFonts.poppins(fontSize: 13)),
                    );
                  }).toList(),
                ),
                Colors.orange.shade50,
                Colors.orange.shade200,
              ),

            // Brands Detailed (brand_details)
            if (visit.rawBrandDetails.isNotEmpty)
              _buildSubCard(
                "Brands Detailed",
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: visit.rawBrandDetails.map((item) {
                    final name = item['name'] ?? item['brand_name'] ?? item['product_name'] ?? 'Unknown';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text("• $name", style: GoogleFonts.poppins(fontSize: 13)),
                    );
                  }).toList(),
                ),
                Colors.teal.shade50,
                Colors.teal.shade200,
              ),

            // Samples
            if (visit.rawSamples.isNotEmpty)
              _buildSubCard(
                "Samples",
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: visit.rawSamples.map((item) {
                    final name = item['name'] ?? item['brand_name'] ?? item['product_name'] ?? 'Unknown';
                    final qty = item['sample_qty']?.toString() ?? '0';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                          Expanded(child: Text("• $name", style: GoogleFonts.poppins(fontSize: 13))),
                          Text("Qty: $qty", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                Colors.green.shade50,
                Colors.green.shade200,
              ),

            // Brands Rxbed (prescribed_rx)
            if (visit.rawPrescribedRx.isNotEmpty)
              _buildSubCard(
                "Brands Rxbed",
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: visit.rawPrescribedRx.map((item) {
                    final name = item['name'] ?? item['brand_name'] ?? item['product_name'] ?? 'Unknown';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text("• $name", style: GoogleFonts.poppins(fontSize: 13)),
                    );
                  }).toList(),
                ),
                Colors.indigo.shade50,
                Colors.indigo.shade200,
              ),

            // Brands added after last visit (new_brand_rxbed)
            if (visit.rawNewBrandRxbed.isNotEmpty)
              _buildSubCard(
                "Brands added after last visit",
                Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                  children: visit.rawNewBrandRxbed.map((item) {
                    final name = item['name'] ?? item['brand_name'] ?? item['product_name'] ?? 'Unknown';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text("• $name", style: GoogleFonts.poppins(fontSize: 13)),
                    );
                  }).toList(),
                    ),
                Colors.pink.shade50,
                Colors.pink.shade200,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCard(String title, Widget content, Color bgColor, Color borderColor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          content,
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
