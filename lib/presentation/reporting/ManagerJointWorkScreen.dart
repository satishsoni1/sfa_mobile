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
  List<dynamic> _allRequests = [];
  Map<String, List<dynamic>> _groupedRequests = {};
  bool _isLoading = true;
  
  // Search Controller
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  void _fetchRequests() async {
    try {
      final data = await ApiService().getJointWorkRequests();
      setState(() {
        _allRequests = data;
        _groupAndFilterRequests();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Grouping and Filtering Logic
  void _groupAndFilterRequests() {
    final Map<String, List<dynamic>> groups = {};

    final filtered = _allRequests.where((r) {
      final doctorName = r['doctor_name'].toString().toLowerCase();
      final mrName = r['user']['first_name'].toString().toLowerCase();
      return doctorName.contains(_searchQuery.toLowerCase()) || 
             mrName.contains(_searchQuery.toLowerCase());
    }).toList();

    for (var request in filtered) {
      // Format the date to use as a key (e.g., "2023-10-25")
      DateTime date = DateTime.parse(request['visit_time']);
      String dateKey = DateFormat('yyyy-MM-dd').format(date);

      if (groups[dateKey] == null) {
        groups[dateKey] = [];
      }
      groups[dateKey]!.add(request);
    }

    // Sort dates descending (newest first)
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final Map<String, List<dynamic>> sortedGroups = {
      for (var key in sortedKeys) key: groups[key]!
    };

    setState(() {
      _groupedRequests = sortedGroups;
    });
  }

  void _showApprovalDialog(Map<String, dynamic> report) {
    final remarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Approve Joint Work"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("MR: ${report['user']['first_name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("Doctor: ${report['doctor_name']}"),
            const SizedBox(height: 15),
            TextField(
              controller: remarkController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Manager Remark",
                border: OutlineInputBorder(),
                hintText: "Enter feedback...",
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (remarkController.text.isEmpty) return;
              Navigator.pop(ctx);
              _submitApproval(report['id'].toString(), remarkController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C)),
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
        const SnackBar(content: Text("Verified successfully!"), backgroundColor: Colors.green),
      );
      _fetchRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Joint Work Approvals"),
        backgroundColor: const Color(0xFF4A148C),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                _searchQuery = val;
                _groupAndFilterRequests();
              },
              decoration: InputDecoration(
                hintText: "Search Doctor or BD Name...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4A148C)),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      _searchController.clear();
                      _searchQuery = "";
                      _groupAndFilterRequests();
                    })
                  : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedRequests.isEmpty
              ? Center(
                  child: Text(
                    "No requests found.",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _groupedRequests.length,
                  itemBuilder: (context, index) {
                    String dateKey = _groupedRequests.keys.elementAt(index);
                    List<dynamic> items = _groupedRequests[dateKey]!;
                    DateTime date = DateTime.parse(dateKey);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Header
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Text(
                            DateFormat('EEEE, dd MMM yyyy').format(date),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4A148C),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        // Requests under this date
                        ...items.map((r) => _buildRequestCard(r)).toList(),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> r) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.purple.shade50,
          child: Text(
            r['user']['first_name'][0],
            style: const TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          r['doctor_name'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MR: ${r['user']['first_name']} (${r['user']['designation'] ?? 'MR'})",
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                "MR Remark: ${r['remarks']}",
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () => _showApprovalDialog(r),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text("Verify", style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ),
    );
  }
}