import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class TourPlanReviewScreen extends StatefulWidget {
  final DateTime currentMonth;
  final Map<String, dynamic> monthlyPlans;
  final int? userId; // If null = Employee View. If provided = Manager View

  const TourPlanReviewScreen({
    required this.currentMonth,
    required this.monthlyPlans,
    this.userId,
    super.key,
  });

  @override
  State<TourPlanReviewScreen> createState() => _TourPlanReviewScreenState();
}

class _TourPlanReviewScreenState extends State<TourPlanReviewScreen> {
  bool _isSubmitting = false;
  final ApiService _api = ApiService();

  // --- 1. User Action: Submit Own Plan ---
  Future<void> _submitPlan() async {
    setState(() => _isSubmitting = true);
    try {
      bool success = await _api.submitMonthPlan(widget.currentMonth);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Month Plan Submitted for Approval!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to submit plan. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // --- 2. Manager Action: Approve / Reject Entire Month ---
  Future<void> _managerAction(String action) async {
    List<String> planDates = widget.monthlyPlans.keys.toList();

    if (planDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No plans found for this month to process."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? remark;

    if (action == 'Rejected') {
      remark = await showDialog<String>(
        context: context,
        builder: (ctx) {
          String r = "";
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.cancel, color: Colors.red),
                const SizedBox(width: 8),
                const Text("Reject Month Plan"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Rejecting all ${planDates.length} planned days."),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => r = v,
                  decoration: InputDecoration(
                    labelText: "Reason for Rejection (Required)",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  if (r.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Remark is required to reject."),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx, r);
                },
                child: const Text(
                  "Reject All",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (remark == null || remark.isEmpty) return; // User cancelled
    }

    setState(() => _isSubmitting = true);

    try {
      bool success = await _api.bulkActionAreaPlan(
        action: action,
        dates: planDates,
        remark: remark,
        targetUserId: widget.userId!,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Month Plan $action Successfully!"),
            backgroundColor: action == 'Approved' ? Colors.green : Colors.red,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update status."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int daysInMonth = DateTime(
      widget.currentMonth.year,
      widget.currentMonth.month + 1,
      0,
    ).day;
    final Color primaryColor = const Color(0xFF2E3192);
    final bool isManager = widget.userId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Review Month: ${DateFormat('MMMM yyyy').format(widget.currentMonth)}",
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Summary Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat(
                  "Days Planned",
                  "${widget.monthlyPlans.length}/$daysInMonth",
                  Colors.blue,
                ),
                _buildSummaryStat("Overall Status", "Reviewing", Colors.orange),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Day by Day List
          Expanded(
            child: ListView.builder(
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final date = DateTime(
                  widget.currentMonth.year,
                  widget.currentMonth.month,
                  index + 1,
                );
                String dateKey = DateFormat('yyyy-MM-dd').format(date);
                bool isSunday = date.weekday == DateTime.sunday;

                var plan = widget.monthlyPlans[dateKey];

                List<String> areaNames = [];
                if (plan != null && plan['areas'] != null) {
                  areaNames = List<String>.from(plan['areas']);
                }

                bool hasRemark =
                    plan != null &&
                    plan['remark'] != null &&
                    plan['remark'].toString().trim().isNotEmpty;

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSunday ? Colors.red.shade50 : Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSunday ? Colors.red : Colors.grey,
                          ),
                        ),
                        Text(
                          DateFormat('dd').format(date),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSunday ? Colors.red : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    title: plan != null
                        ? Text(
                            plan['type'] == 'activity'
                                ? plan['activity_name'] ?? 'Activity'
                                : areaNames.join(', '),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          )
                        : Text(
                            isSunday ? "Holiday / Sunday" : "Unplanned",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),

                    // NEW: Display Remark in the Subtitle
                    subtitle: hasRemark
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.format_quote,
                                  size: 14,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    plan['remark'],
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : null,

                    trailing: plan != null
                        ? _buildStatusIcon(plan['status'])
                        : null,
                  ),
                );
              },
            ),
          ),
          // Bottom Action Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: isManager
                  ? _buildManagerActionButtons()
                  : _buildUserSubmitButton(),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Blocks ---

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatusIcon(String? status) {
    if (status == 'Approved')
      return const Icon(Icons.check_circle, color: Colors.green, size: 20);
    if (status == 'Rejected')
      return const Icon(Icons.cancel, color: Colors.red, size: 20);
    if (status == 'Pending')
      return const Icon(Icons.hourglass_top, color: Colors.orange, size: 20);
    return const Icon(Icons.edit_note, color: Colors.grey, size: 20);
  }

  Widget _buildUserSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitPlan,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.send, color: Colors.white),
        label: Text(
          _isSubmitting ? "SUBMITTING..." : "SUBMIT MONTH FOR APPROVAL",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildManagerActionButtons() {
    if (_isSubmitting) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _managerAction('Rejected'),
            icon: const Icon(Icons.close, color: Colors.red),
            label: Text(
              "REJECT MONTH",
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _managerAction('Approved'),
            icon: const Icon(Icons.check, color: Colors.white),
            label: Text(
              "APPROVE MONTH",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
