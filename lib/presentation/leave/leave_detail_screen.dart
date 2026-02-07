import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/api_service.dart';

class LeaveDetailScreen extends StatefulWidget {
  final int leaveId;
  const LeaveDetailScreen({required this.leaveId, super.key});

  @override
  State<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends State<LeaveDetailScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final data = await _api.getLeaveDetails(widget.leaveId);
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_data == null)
      return const Scaffold(body: Center(child: Text("Error loading data")));

    final leave = _data!['leave'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Request Details", style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF4A148C),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _row("Request No", "#${leave['request_no']}"),
                  const Divider(),
                  _row(
                    "Status",
                    leave['status'],
                    isBold: true,
                    color: leave['status'] == 'Approved'
                        ? Colors.green
                        : (leave['status'] == 'Rejected'
                              ? Colors.red
                              : Colors.orange),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Basic Info
            Text(
              "Leave Information",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _row("From Date", leave['leave_from']),
            _row("To Date", leave['leave_to']),
            _row("Total Days", "${leave['leave_days']}"),
            _row("Half Day", leave['half_day']),
            _row("Contact", leave['contact_during_leave'] ?? '-'),
            const SizedBox(height: 12),
            Text(
              "Reason:",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
            ),
            Text(
              leave['purpose'] ?? '-',
              style: GoogleFonts.poppins(fontSize: 14),
            ),

            const Divider(height: 40),

            // Approvals Section
            Text(
              "Approval Timeline",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _approvalStep("Head Office", leave['ho_approval']),
            _approvalStep("Reporting Manager", leave['rm_approval']),
            _approvalStep("Senior RM", leave['sr_rm_approval']),
            _approvalStep("Zonal Manager", leave['zm_approval']),
            _approvalStep("Sales Manager", leave['sm_approval']),
            _approvalStep("National Sales Manager", leave['nsm_approval']),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? Colors.black,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvalStep(String title, String status) {
    if (status == 'Pending')
      return const SizedBox.shrink(); // Hide pending steps if you prefer cleaner UI, or show them as grey

    IconData icon = Icons.access_time;
    Color color = Colors.orange;

    if (status == 'Approved') {
      icon = Icons.check_circle;
      color = Colors.green;
    }
    if (status == 'Rejected') {
      icon = Icons.cancel;
      color = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: GoogleFonts.poppins(fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
