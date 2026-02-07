import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _purposeController = TextEditingController();
  final _contactController = TextEditingController();
  final ApiService _api = ApiService();

  // Loading States
  bool _isLoadingMeta = true;
  bool _isSubmitting = false;

  // Data
  List<dynamic> _leaveTypes = [];
  List<dynamic> _balances = [];

  // Form Values
  int? _selectedHeadId;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isHalfDay = false;

  @override
  void initState() {
    super.initState();
    _fetchMeta();
  }

  Future<void> _fetchMeta() async {
    try {
      final data = await _api.getLeaveMeta();
      setState(() {
        _leaveTypes = data['leave_types'];
        _balances = data['balances'];
        _isLoadingMeta = false;
      });
    } catch (e) {
      setState(() => _isLoadingMeta = false);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(
        const Duration(days: 60),
      ), // Allow up to 60 days back
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4A148C),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  void _submit() async {
    if (_selectedHeadId == null || _fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Leave Type and Dates")),
      );
      return;
    }
    if (_purposeController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a Reason")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _api.applyLeave({
        'leave_head_id': _selectedHeadId,
        'leave_from': DateFormat('yyyy-MM-dd').format(_fromDate!),
        'leave_to': DateFormat('yyyy-MM-dd').format(_toDate!),
        'purpose': _purposeController.text,
        'contact_during_leave': _contactController.text,
        'half_day': _isHalfDay,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Leave Application Submitted!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Success
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Apply Leave", style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF4A148C),
      ),
      body: _isLoadingMeta
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Balances Scroll View
                  if (_balances.isNotEmpty) ...[
                    Text(
                      "AVAILABLE BALANCE",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _balances
                            .map(
                              (b) => Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.purple.shade100,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      b['head'] ?? 'Type',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4A148C),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${b['available']}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 2. Form Fields
                  _label("Leave Type"),
                  DropdownButtonFormField<int>(
                    value: _selectedHeadId,
                    decoration: _inputDeco("Select Leave Type"),
                    items: _leaveTypes
                        .map(
                          (e) => DropdownMenuItem<int>(
                            value: e['id'],
                            child: Text(e['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedHeadId = v),
                  ),
                  const SizedBox(height: 20),

                  _label("Duration"),
                  InkWell(
                    onTap: _pickDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            color: Color(0xFF4A148C),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _fromDate == null
                                ? "Select From & To Date"
                                : "${DateFormat('dd MMM').format(_fromDate!)} - ${DateFormat('dd MMM yyyy').format(_toDate!)}",
                            style: GoogleFonts.poppins(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _isHalfDay,
                          activeColor: const Color(0xFF4A148C),
                          onChanged: (v) => setState(() => _isHalfDay = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text("Apply for Half Day"),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _label("Reason"),
                  TextField(
                    controller: _purposeController,
                    maxLines: 3,
                    decoration: _inputDeco("Enter detailed reason..."),
                  ),
                  const SizedBox(height: 20),

                  _label("Contact During Leave (Optional)"),
                  TextField(
                    controller: _contactController,
                    decoration: _inputDeco("Emergency number..."),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A148C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "SUBMIT APPLICATION",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
    ),
  );
  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}
