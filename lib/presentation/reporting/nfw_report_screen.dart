import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

// ==========================================
// 1. MAIN SCREEN: LIST OF REPORTS
// ==========================================
class NfwReportScreen extends StatefulWidget {
  const NfwReportScreen({super.key});

  @override
  State<NfwReportScreen> createState() => _NfwReportScreenState();
}

class _NfwReportScreenState extends State<NfwReportScreen> {
  List<dynamic> _reports = [];
  bool _isLoading = true;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  // Fetch data from API
  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      // Ensure ApiService has a method: Future<List<dynamic>> getNfwHistory()
      final data = await _api.getNfwHistory();
      setState(() => _reports = data);
    } catch (e) {
      // Handle error cleanly
      debugPrint("Error fetching NFW history: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToAddScreen() async {
    // Wait for result from Add Screen
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddNfwReportScreen()),
    );

    // If report was submitted successfully (returned true), refresh list
    if (result == true) {
      _fetchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          "Non-Field Work",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF4A148C),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "No reports found",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reports.length,
              itemBuilder: (context, index) {
                final item = _reports[index];
                return _buildReportCard(item);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddScreen,
        backgroundColor: const Color(0xFF4A148C),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "NEW REPORT",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(dynamic item) {
    // Parse Date safely
    DateTime date = DateTime.now();
    try {
      date = DateTime.parse(item['report_date'] ?? item['visit_time']);
    } catch (e) {
      /* ignore */
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A148C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('dd').format(date),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4A148C),
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(date).toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A148C),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['activity'] ??
                        item['doctor_name'] ??
                        "Activity", // Handle varied API keys
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item['location'] ?? "No Location",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  if (item['remarks'] != null &&
                      item['remarks'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item['remarks'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Status Icon (Optional)
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. ADD FORM SCREEN (Your Existing Logic)
// ==========================================
class AddNfwReportScreen extends StatefulWidget {
  const AddNfwReportScreen({super.key});

  @override
  State<AddNfwReportScreen> createState() => _AddNfwReportScreenState();
}

class _AddNfwReportScreenState extends State<AddNfwReportScreen> {
  final _locationController = TextEditingController();
  final _remarksController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedActivity;
  bool _isLoading = false;

  final List<String> _activities = [
    "Head Office Meeting",
    "Cycle Meeting",
    "Training",
    "Admin Work",
    "Transit / Traveling",
    "Conference",
    "Meeting",
    "Closing",
    "Casual Leave",
    "Sick Leave",
    "Loss of Pay",
  ];

  Future<void> _submit() async {
    if (_selectedActivity == null || _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select activity and enter location"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call your API
      await ApiService().submitNfwReport(
        _selectedDate,
        _selectedActivity!,
        _locationController.text,
        _remarksController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Saved Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return TRUE to refresh list
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("New Report", style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF4A148C),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel("Report Date"),
            InkWell(
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: _buildInputContainer(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF4A148C)),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd MMMM yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildLabel("Activity Type"),
            DropdownButtonFormField<String>(
              value: _selectedActivity,
              decoration: _inputDecoration("Select Activity"),
              items: _activities
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedActivity = val;
                  if (val == "Head Office Meeting")
                    _locationController.text = "Head Office";
                  if (val == "Work from Home")
                    _locationController.text = "Home";
                });
              },
            ),
            const SizedBox(height: 24),

            _buildLabel("Location / City"),
            TextField(
              controller: _locationController,
              decoration: _inputDecoration(
                "e.g. Mumbai",
              ).copyWith(prefixIcon: const Icon(Icons.location_on_outlined)),
            ),
            const SizedBox(height: 24),

            _buildLabel("Remarks"),
            TextField(
              controller: _remarksController,
              maxLines: 3,
              decoration: _inputDecoration("Describe details..."),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A148C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "SUBMIT REPORT",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildInputContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintText: hint,
    );
  }
}
