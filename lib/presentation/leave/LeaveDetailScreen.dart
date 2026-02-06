import 'package:flutter/material.dart';
import '../../data/services/api_service.dart';

class LeaveDetailScreen extends StatefulWidget {
  final int leaveId;
  const LeaveDetailScreen({required this.leaveId, super.key});

  @override
  State<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends State<LeaveDetailScreen> {
  Map<String, dynamic>? _leaveData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final api = ApiService();
      // Assume you added getLeaveDetails(id) to ApiService
      final data = await api.getLeaveDetails(widget.leaveId); 
      setState(() {
        _leaveData = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_leaveData == null) return const Scaffold(body: Center(child: Text("Error loading details")));

    final leave = _leaveData!['leave']; // Main details
    final details = _leaveData!['details'] as List; // Breakdown of days per head

    return Scaffold(
      appBar: AppBar(title: const Text("Request Details"), backgroundColor: const Color(0xFF4A148C)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row("Request No", "#${leave['request_no']}"),
            _row("Status", leave['status']),
            _row("From", leave['leave_from']),
            _row("To", leave['leave_to']),
            _row("Total Days", "${leave['leave_days']}"),
            const Divider(height: 30),
            const Text("Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ...details.map((d) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(d['leave_head']),
              trailing: Text("${d['required_days']} days", style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}