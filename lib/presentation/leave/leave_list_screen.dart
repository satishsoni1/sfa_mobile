import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/leave_provider.dart';
import 'apply_leave_screen.dart';

class LeaveListScreen extends StatefulWidget {
  const LeaveListScreen({super.key});

  @override
  State<LeaveListScreen> createState() => _LeaveListScreenState();
}

class _LeaveListScreenState extends State<LeaveListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LeaveProvider>(context, listen: false).fetchLeaves();
    });
  }

  @override
  Widget build(BuildContext context) {
    final leaveProvider = Provider.of<LeaveProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Leave Management", style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF4A148C),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()));
        },
        backgroundColor: const Color(0xFF4A148C),
        icon: const Icon(Icons.add),
        label: const Text("Apply Leave"),
      ),
      body: leaveProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : leaveProvider.leaves.isEmpty
              ? Center(child: Text("No leave history found", style: GoogleFonts.poppins(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: leaveProvider.leaves.length,
                  itemBuilder: (context, index) {
                    final leave = leaveProvider.leaves[index];
                    return _buildLeaveCard(leave);
                  },
                ),
    );
  }

  Widget _buildLeaveCard(dynamic leave) {
    String status = leave['status'] ?? 'Pending';
    Color statusColor;
    if (status == 'Approved') statusColor = Colors.green;
    else if (status == 'Rejected') statusColor = Colors.red;
    else statusColor = Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  leave['leave_type'], 
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  "${leave['from_date']}  to  ${leave['to_date']}",
                  style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 13),
                ),
              ],
            ),
            if (leave['reason'] != null) ...[
              const SizedBox(height: 8),
              Text(
                "Reason: ${leave['reason']}",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic),
              ),
            ]
          ],
        ),
      ),
    );
  }
}