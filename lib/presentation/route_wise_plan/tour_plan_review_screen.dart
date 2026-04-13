import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class TourPlanReviewScreen extends StatefulWidget {
  final DateTime currentMonth;
  final Map<String, dynamic> monthlyPlans;
  final String monthStatus;
  final int? userId; // If null = Employee View. If provided = Manager View

  const TourPlanReviewScreen({
    required this.currentMonth,
    required this.monthlyPlans,
    required this.monthStatus,
    this.userId,
    super.key,
  });

  @override
  State<TourPlanReviewScreen> createState() => _TourPlanReviewScreenState();
}

class _TourPlanReviewScreenState extends State<TourPlanReviewScreen> {
  bool _isSubmitting = false;
  final ApiService _api = ApiService();

  // --- 1. User Action: Submit Entire Month ---
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
          const SnackBar(content: Text("Failed to submit plan."), backgroundColor: Colors.red),
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
    String? remark;

    if (action == 'Rejected') {
      remark = await showDialog<String>(
        context: context,
        builder: (ctx) {
          String r = "";
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Reject Month Plan"),
            content: TextField(
              onChanged: (v) => r = v,
              decoration: const InputDecoration(labelText: "Reason (Required)", border: OutlineInputBorder()),
              maxLines: 3,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  if (r.trim().isEmpty) return;
                  Navigator.pop(ctx, r);
                },
                child: const Text("Reject", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
      if (remark == null || remark.isEmpty) return; 
    }

    setState(() => _isSubmitting = true);

    try {
      bool success = await _api.reviewMonthPlan(
        month: widget.currentMonth,
        action: action,
        remark: remark ?? '',
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
          const SnackBar(content: Text("Failed to update status."), backgroundColor: Colors.red),
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
    int daysInMonth = DateTime(widget.currentMonth.year, widget.currentMonth.month + 1, 0).day;
    final bool isManager = widget.userId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E3192),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Review Month: ${DateFormat('MMMM yyyy').format(widget.currentMonth)}",
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat("Days Planned", "${widget.monthlyPlans.length}/$daysInMonth", Colors.blue),
                _buildSummaryStat("Overall Status", widget.monthStatus, _getStatusColor(widget.monthStatus)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final date = DateTime(widget.currentMonth.year, widget.currentMonth.month, index + 1);
                String dateKey = DateFormat('yyyy-MM-dd').format(date);
                var plan = widget.monthlyPlans[dateKey];

                return _buildDayCard(date, plan);
              },
            ),
          ),

          // Bottom Action Area based on status and role
          if (widget.monthStatus == 'Draft' || widget.monthStatus == 'Rejected')
             if (!isManager) _buildBottomBar(_buildUserSubmitButton()),
          
          if (widget.monthStatus == 'Pending')
             if (isManager) _buildBottomBar(_buildManagerActionButtons())
             else _buildBottomBar(_buildStatusBadge("Waiting for Manager Approval", Colors.orange)),

          if (widget.monthStatus == 'Approved')
             _buildBottomBar(_buildStatusBadge("Month Plan Approved & Locked", Colors.green)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'Approved') return Colors.green;
    if (status == 'Rejected') return Colors.red;
    if (status == 'Pending') return Colors.orange;
    return Colors.grey;
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDayCard(DateTime date, dynamic plan) {
    bool isSunday = date.weekday == DateTime.sunday;
    List<String> areaNames = plan != null && plan['areas'] != null ? List<String>.from(plan['areas']) : [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSunday ? Colors.red.shade50 : Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(DateFormat('EEE').format(date), style: TextStyle(fontSize: 10, color: isSunday ? Colors.red : Colors.grey)),
            Text(DateFormat('dd').format(date), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSunday ? Colors.red : Colors.black87)),
          ],
        ),
        title: plan != null
            ? Text(
                plan['type'] == 'activity' ? plan['activity_name'] ?? 'Activity' : areaNames.join(', '),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              )
            : Text(isSunday ? "Holiday / Sunday" : "Unplanned", style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
      ),
    );
  }

  Widget _buildBottomBar(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
      ),
      child: SafeArea(child: child),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Center(child: Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color))),
    );
  }

  Widget _buildUserSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitPlan,
        icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, color: Colors.white),
        label: Text("SUBMIT MONTH FOR APPROVAL", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(vertical: 16)),
      ),
    );
  }

  Widget _buildManagerActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _managerAction('Rejected'),
            icon: const Icon(Icons.close, color: Colors.red),
            label: const Text("REJECT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.red)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _managerAction('Approved'),
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text("APPROVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ),
      ],
    );
  }
}