import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class TourPlanReviewScreen extends StatefulWidget {
  final DateTime currentMonth;
  final Map<String, dynamic> monthlyPlans;
  final String monthStatus;
  final int? userId; // If null = Employee View. If provided = Manager View
  final bool isCampaignTpEligible;

  const TourPlanReviewScreen({
    required this.currentMonth,
    required this.monthlyPlans,
    required this.monthStatus,
    this.userId,
    this.isCampaignTpEligible = true,
    super.key,
  });

  @override
  State<TourPlanReviewScreen> createState() => _TourPlanReviewScreenState();
}

class _TourPlanReviewScreenState extends State<TourPlanReviewScreen> {
  bool _isSubmitting = false;
  final ApiService _api = ApiService();

  // --- 1. User Action: Submit Entire Month ---
  Future<void> _submitPlan({String? reason}) async {
    setState(() => _isSubmitting = true);
    try {
      final res = await _api.submitMonthPlan(
        widget.currentMonth,
        reason: reason,
      );
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? "Month Plan Submitted for Approval!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          _showValidationErrorsDialog(
            message: res['message']?.toString(),
            errors: res['errors'],
            wasOverrideAttempt: reason != null && reason.trim().isNotEmpty,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showValidationErrorsDialog(
          message: e.toString().replaceAll('Exception: ', ''),
          wasOverrideAttempt: reason != null && reason.trim().isNotEmpty,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showValidationErrorsDialog({
    String? message,
    dynamic errors,
    bool wasOverrideAttempt = false,
  }) async {
    final List<String> errorList = [];

    if (errors != null) {
      if (errors is List) {
        for (var item in errors) {
          if (item != null && item.toString().trim().isNotEmpty) {
            errorList.add(item.toString().trim());
          }
        }
      } else if (errors is Map) {
        for (var val in errors.values) {
          if (val is List) {
            for (var sub in val) {
              if (sub != null && sub.toString().trim().isNotEmpty) {
                errorList.add(sub.toString().trim());
              }
            }
          } else if (val != null && val.toString().trim().isNotEmpty) {
            errorList.add(val.toString().trim());
          }
        }
      }
    }

    if (errorList.isEmpty && message != null && message.trim().isNotEmpty) {
      String cleanMsg = message.trim();
      if (cleanMsg.startsWith("Campaign Tour Plan validation failed: ")) {
        cleanMsg = cleanMsg.replaceFirst("Campaign Tour Plan validation failed: ", "");
      }
      final parts = cleanMsg.split(RegExp(r'\.\s+(?=[A-Z])'));
      for (var p in parts) {
        String trimmed = p.trim();
        if (trimmed.isNotEmpty) {
          if (!trimmed.endsWith('.')) trimmed += '.';
          errorList.add(trimmed);
        }
      }
      if (errorList.isEmpty) {
        errorList.add(cleanMsg);
      }
    }

    final TextEditingController reasonCtrl = TextEditingController();
    bool showReasonInput = wasOverrideAttempt;
    String? reasonError;

    final String? overrideReason = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                  maxWidth: 480,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Dialog Header ──────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        border: Border(bottom: BorderSide(color: Colors.red.shade100)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.error_outline, color: Colors.red.shade700, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Validation Failed",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                                Text(
                                  errorList.length > 1
                                      ? (widget.isCampaignTpEligible
                                          ? "${errorList.length} issues found in campaign plan"
                                          : "${errorList.length} issues found in tour plan")
                                      : "Action required before submission",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                            tooltip: "Close",
                          ),
                        ],
                      ),
                    ),

                    // ── Instruction Banner ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: const Color(0xFFFFFBEB),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Please correct these errors in your tour dates, or proceed by providing a valid reason:",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Scrollable List of Errors & Reason Input ──────────────
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (errorList.isEmpty)
                              Text(
                                message ?? "An unexpected validation error occurred.",
                                style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: errorList.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final err = errorList[index];
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF5FC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.purple.shade100),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          margin: const EdgeInsets.only(top: 2),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF4A148C),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              "${index + 1}",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            err,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12.5,
                                              height: 1.4,
                                              color: Colors.grey.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            if (showReasonInput) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Reason to Proceed *",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: reasonCtrl,
                                      maxLines: 3,
                                      minLines: 2,
                                      autofocus: true,
                                      onChanged: (_) {
                                        if (reasonError != null) {
                                          setDialogState(() => reasonError = null);
                                        }
                                      },
                                      style: GoogleFonts.poppins(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: "Enter a valid reason (min. 5 characters)...",
                                        hintStyle: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                        errorText: reasonError,
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF4A148C),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // ── Bottom Action Buttons ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: showReasonInput
                          ? Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 44,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setDialogState(() {
                                          showReasonInput = false;
                                          reasonError = null;
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.grey.shade700,
                                        side: BorderSide(color: Colors.grey.shade300),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: Text(
                                        "Back",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final r = reasonCtrl.text.trim();
                                        if (r.isEmpty) {
                                          setDialogState(() => reasonError = "Reason is required.");
                                          return;
                                        }
                                        if (r.length < 5) {
                                          setDialogState(() => reasonError = "Please enter a valid reason (at least 5 characters).");
                                          return;
                                        }
                                        Navigator.pop(ctx, r);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4A148C),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: Text(
                                        "SUBMIT WITH REASON",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4A148C),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      "I UNDERSTAND, LET ME UPDATE",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 42,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setDialogState(() => showReasonInput = true);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF4A148C),
                                      side: const BorderSide(color: Color(0xFF4A148C)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      "PROCEED WITH REASON",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    reasonCtrl.dispose();

    if (overrideReason != null && overrideReason.trim().isNotEmpty && mounted) {
      await _submitPlan(reason: overrideReason.trim());
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Month Plan $action Successfully!"),
              backgroundColor: action == 'Approved' ? Colors.green : Colors.red,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to update status."), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int daysInMonth = DateTime(widget.currentMonth.year, widget.currentMonth.month + 1, 0).day;
    final bool isManager = widget.userId != null;

    int campaignDaysCount = widget.monthlyPlans.values.where((p) {
      if (p == null) return false;
      return p['has_campaign'] == true ||
          p['campaign_id'] != null ||
          (p['campaign_ids'] is List && (p['campaign_ids'] as List).isNotEmpty) ||
          (p['campaigns'] is List && (p['campaigns'] as List).isNotEmpty);
    }).length;

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
                if (widget.isCampaignTpEligible)
                  _buildSummaryStat("Campaign Days", "$campaignDaysCount", const Color(0xFF7B1FA2)),
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

    bool hasCampaign = widget.isCampaignTpEligible && plan != null &&
        (plan['has_campaign'] == true ||
            plan['campaign_id'] != null ||
            (plan['campaign_ids'] is List && (plan['campaign_ids'] as List).isNotEmpty) ||
            (plan['campaigns'] is List && (plan['campaigns'] as List).isNotEmpty));

    String? campaignLabel;
    int? doctorCount;
    String? doctorNamesLabel;

    if (hasCampaign) {
      if (plan['campaign_names'] is List && (plan['campaign_names'] as List).isNotEmpty) {
        campaignLabel = (plan['campaign_names'] as List).join(', ');
      } else if (plan['campaign_name'] != null && plan['campaign_name'].toString().isNotEmpty) {
        campaignLabel = plan['campaign_name'].toString();
      } else if (plan['campaigns'] is List && (plan['campaigns'] as List).isNotEmpty) {
        campaignLabel = (plan['campaigns'] as List).map((c) {
          if (c is Map) return c['campaign_name'] ?? 'Campaign #${c['campaign_id']}';
          return c.toString();
        }).join(', ');
      } else if (plan['activity_name'] != null &&
          plan['activity_name'].toString().isNotEmpty &&
          plan['type'] != 'activity') {
        campaignLabel = plan['activity_name'].toString();
      } else {
        campaignLabel = "Campaign Day";
      }

      if (plan['doctor_ids'] is List) {
        doctorCount = (plan['doctor_ids'] as List).length;
      } else if (plan['doctors'] is List) {
        doctorCount = (plan['doctors'] as List).length;
      } else if (plan['doctor_count'] != null) {
        doctorCount = int.tryParse(plan['doctor_count'].toString());
      } else if (plan['campaign_doctors_count'] != null) {
        doctorCount = int.tryParse(plan['campaign_doctors_count'].toString());
      }

      if (plan['campaigns'] is List) {
        int total = 0;
        bool found = false;
        final docNames = <String>{};
        for (var c in plan['campaigns']) {
          if (c is Map) {
            if (c['doctors'] is List) {
              for (var d in (c['doctors'] as List)) {
                if (d is Map) {
                  final name = d['doctor_name']?.toString() ?? d['name']?.toString();
                  if (name != null && name.trim().isNotEmpty) {
                    docNames.add(name.trim());
                  }
                }
              }
              total += (c['doctors'] as List).length;
              found = true;
            } else if (c['doctor_ids'] is List) {
              total += (c['doctor_ids'] as List).length;
              found = true;
            }
          }
        }
        if (found) doctorCount = total;
        if (docNames.isNotEmpty) {
          doctorNamesLabel = docNames.join(', ');
        }
      }
    }

    bool hasRemark = plan != null && plan['remark'] != null && plan['remark'].toString().trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSunday
            ? Colors.red.shade50
            : (hasCampaign ? const Color(0xFFFAF5FC) : Colors.white),
        border: Border.all(
          color: hasCampaign
              ? const Color(0xFF7B1FA2).withValues(alpha: 0.35)
              : Colors.grey.shade200,
          width: hasCampaign ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSunday
                ? Colors.red.shade100
                : (hasCampaign ? const Color(0xFFF3E5F5) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('EEE').format(date),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSunday ? Colors.red : (hasCampaign ? const Color(0xFF4A148C) : Colors.grey.shade700),
                ),
              ),
              Text(
                DateFormat('dd').format(date),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSunday ? Colors.red : (hasCampaign ? const Color(0xFF4A148C) : Colors.black87),
                ),
              ),
            ],
          ),
        ),
        title: plan != null
            ? Text(
                plan['type'] == 'activity'
                    ? plan['activity_name'] ?? 'Activity'
                    : (areaNames.isNotEmpty ? areaNames.join(', ') : "Field Work"),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              )
            : Text(
                isSunday ? "Holiday / Sunday" : "Unplanned",
                style: TextStyle(
                  color: isSunday ? Colors.red : Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
        subtitle: (hasCampaign || hasRemark)
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasCampaign) ...[
                      if (plan['campaigns'] is List && (plan['campaigns'] as List).isNotEmpty)
                        for (var c in (plan['campaigns'] as List))
                          Builder(
                            builder: (_) {
                              if (c is! Map) return const SizedBox.shrink();
                              final String cName = c['campaign_name']?.toString() ?? 'Campaign #${c['campaign_id'] ?? ''}';
                              final List docsList = c['doctors'] is List ? (c['doctors'] as List) : [];
                              final List<String> cDocNames = [];
                              for (var d in docsList) {
                                if (d is Map) {
                                  final name = d['doctor_name']?.toString() ?? d['name']?.toString();
                                  if (name != null && name.trim().isNotEmpty) {
                                    cDocNames.add(name.trim());
                                  }
                                } else if (d != null && d.toString().trim().isNotEmpty) {
                                  cDocNames.add(d.toString().trim());
                                }
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E5F5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.purple.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.campaign, size: 16, color: Color(0xFF4A148C)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            cName,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF4A148C),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (cDocNames.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4A148C),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              "${cDocNames.length} ${cDocNames.length == 1 ? 'Doc' : 'Docs'}",
                                              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (cDocNames.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: cDocNames.map((name) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: Colors.purple.shade200),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.person, size: 10, color: Color(0xFF4A148C)),
                                                const SizedBox(width: 3),
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Color(0xFF4A148C),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E5F5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.campaign, size: 14, color: Color(0xFF4A148C)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      campaignLabel ?? "Campaign Day",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF4A148C),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (doctorCount != null && doctorCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4A148C),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "$doctorCount Docs",
                                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (doctorNamesLabel != null && doctorNamesLabel.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: doctorNamesLabel.split(', ').map((name) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.purple.shade200),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.person, size: 10, color: Color(0xFF4A148C)),
                                          const SizedBox(width: 3),
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: Color(0xFF4A148C),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                    if (hasRemark)
                      Padding(
                        padding: EdgeInsets.only(top: hasCampaign ? 4 : 0),
                        child: Text(
                          plan['remark'].toString(),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              )
            : null,
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Center(child: Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color))),
    );
  }

  Widget _buildUserSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : () => _submitPlan(),
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