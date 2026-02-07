import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class ManagerJointWorkScreen extends StatefulWidget {
  const ManagerJointWorkScreen({super.key});

  @override
  State<ManagerJointWorkScreen> createState() => _ManagerJointWorkScreenState();
}

class _ManagerJointWorkScreenState extends State<ManagerJointWorkScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  void _fetchRequests() async {
    try {
      final data = await ApiService().getJointWorkRequests();
      setState(() {
        _requests = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showApprovalDialog(Map<String, dynamic> report) {
    final remarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Approve & Add to Report"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "MR: ${report['user']['name']}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("Doctor: ${report['doctor_name']}"),
            const SizedBox(height: 10),
            TextField(
              controller: remarkController,
              decoration: const InputDecoration(
                labelText: "Manager Remark",
                border: OutlineInputBorder(),
                hintText: "e.g. Good detailing, pointed out...",
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (remarkController.text.isEmpty) return;
              Navigator.pop(ctx);
              _submitApproval(report['id'].toString(), remarkController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A148C),
            ),
            child: const Text("Approve", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _submitApproval(String id, String remark) async {
    setState(() => _isLoading = true);
    try {
      await ApiService().approveJointWork(id, remark);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Added to your report!"),
          backgroundColor: Colors.green,
        ),
      );
      _fetchRequests(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Joint Work Approvals"),
        backgroundColor: const Color(0xFF4A148C),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? Center(
              child: Text(
                "No pending joint work requests.",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final r = _requests[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.shade50,
                      child: Text(
                        r['user']['name'][0],
                        style: const TextStyle(color: Color(0xFF4A148C)),
                      ),
                    ),
                    title: Text(
                      r['doctor_name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "MR: ${r['user']['name']} (${r['user']['designation'] ?? 'MR'})",
                        ),
                        Text(
                          DateFormat(
                            'dd MMM h:mm a',
                          ).format(DateTime.parse(r['visit_time'])),
                        ),
                        Text(
                          "Remark: ${r['remarks']}",
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _showApprovalDialog(r),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text(
                        "Verify",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
