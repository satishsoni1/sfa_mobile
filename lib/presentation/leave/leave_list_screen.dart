import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/api_service.dart';
import 'apply_leave_screen.dart';
import 'leave_detail_screen.dart';

class LeaveListScreen extends StatefulWidget {
  const LeaveListScreen({super.key});

  @override
  State<LeaveListScreen> createState() => _LeaveListScreenState();
}

class _LeaveListScreenState extends State<LeaveListScreen> {
  List<dynamic> _leaves = [];
  bool _isLoading = true;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchLeaves();
  }

  Future<void> _fetchLeaves() async {
    try {
      final data = await _api.getLeaves();
      setState(() {
        _leaves = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Optional: show error snackbar
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text("Leave Management", style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF4A148C),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()),
          );
          if (result == true) {
            _fetchLeaves(); // Refresh list on return
          }
        },
        backgroundColor: const Color(0xFF4A148C),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "APPLY LEAVE",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leaves.isEmpty
          ? Center(
              child: Text(
                "No leave history found",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _leaves.length,
              itemBuilder: (context, index) {
                return _buildLeaveCard(_leaves[index]);
              },
            ),
    );
  }

  Widget _buildLeaveCard(dynamic leave) {
    String status = leave['status'] ?? 'Pending';
    Color statusColor = Colors.orange;
    if (status == 'Approved') statusColor = Colors.green;
    if (status == 'Rejected') statusColor = Colors.red;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LeaveDetailScreen(leaveId: leave['id']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    leave['leave_type'] ?? 'Leave Request',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${leave['leave_from']}  to  ${leave['leave_to']}",
                    style: GoogleFonts.poppins(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${leave['days']} Days",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (leave['purpose'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  leave['purpose'],
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
