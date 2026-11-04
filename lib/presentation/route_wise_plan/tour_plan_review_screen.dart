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
      await _api.submitMonthPlan(widget.currentMonth);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Month Plan Submitted for Approval!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
      setState(() => _isSubmitting = false);
      }
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

    bool hasCampaign = plan != null &&
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