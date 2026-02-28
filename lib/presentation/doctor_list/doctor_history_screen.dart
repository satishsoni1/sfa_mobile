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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date & Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Color(0xFF4A148C),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd MMM yyyy').format(visit.visitTime),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                // Optional: Show "Edited" flag if updated_at != created_at
              ],
            ),
            const Divider(height: 24),

            // Remarks
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Remark: ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Expanded(
                  child: Text(
                    visit.remarks,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Products Section
            if (visit.products.isNotEmpty) ...[
              Text(
                "Products Discussed:",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: visit.products
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Added Expanded to prevent overflow with long product names
                              Expanded(
                                child: Text(
                                  p.productName,
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  if (p.pobQty > 0)
                                    _tag("POB: ${p.pobQty}", Colors.green),
                                  if (p.pobQty > 0) const SizedBox(width: 4),

                                  if (p.sampleQty > 0)
                                    _tag("Spl: ${p.sampleQty}", Colors.orange),
                                  if (p.sampleQty > 0) const SizedBox(width: 4),

                                  // --- NEW: Added Rx Tag ---
                                  if (p.rxQty > 0)
                                    _tag("Rx: ${p.rxQty}", Colors.blue),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],

            // Joint Work Section
            if (visit.workedWith.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Worked with: ${visit.workedWith.join(', ')}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
