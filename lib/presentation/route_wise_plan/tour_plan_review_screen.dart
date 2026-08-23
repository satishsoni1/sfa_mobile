import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class TourPlanReviewScreen extends StatefulWidget {
  final DateTime currentMonth;
  final Map<String, dynamic> monthlyPlans;
  final String monthStatus;
  final List<dynamic> allRoutes;
  final int? userId; // If null = Employee View. If provided = Manager View

  const TourPlanReviewScreen({
    required this.currentMonth,
    required this.monthlyPlans,
    required this.monthStatus,
    required this.allRoutes,
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

    // Calculate Stats
    int totalRoutes = 0;
    int jointWorkDays = 0;
    
    widget.monthlyPlans.forEach((key, plan) {
      if (plan != null) {
        if (plan['areas'] != null) {
          if (plan['areas'] is List) {
            totalRoutes += (plan['areas'] as List).length;
          } else if (plan['areas'] is Map) {
            totalRoutes += (plan['areas'] as Map).length;
          }
        }
        if (plan['joint_work'] != null && plan['joint_work'] is List && (plan['joint_work'] as List).isNotEmpty) {
          jointWorkDays++;
        }
      }
    });

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
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Expanded(child: _statCard('Days Planned', '${widget.monthlyPlans.length}/$daysInMonth', Icons.event_available, Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Total Routes', '$totalRoutes', Icons.map, Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Joint Work', '$jointWorkDays', Icons.handshake, Colors.teal)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Status', widget.monthStatus, Icons.info_outline, _getStatusColor(widget.monthStatus))),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 9, color: Colors.black87, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDayCard(DateTime date, dynamic plan) {
    bool isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
    
    String routeName = '';
    if (plan != null) {
      if (plan['areas'] is Map) {
        final Map areasMap = plan['areas'];
        List<String> routes = [];
        areasMap.forEach((key, value) {
          String routeStr = value.toString();
          final routeInfo = widget.allRoutes.firstWhere(
            (r) => r['name']?.toString().toLowerCase() == routeStr.toLowerCase(),
            orElse: () => <String, dynamic>{},
          );
          if (routeInfo != null && routeInfo['dr_count'] != null) {
            routes.add('$key. $routeStr (Tagged doctor\'s: ${routeInfo['dr_count']})');
          } else {
            routes.add('$key. $routeStr');
          }
        });
        routeName = routes.join('\n');
      } else if (plan['areas'] is List) {
        List areasList = plan['areas'];
        List<String> routes = [];
        for (int i = 0; i < areasList.length; i++) {
          String routeStr = areasList[i].toString();
          final routeInfo = widget.allRoutes.firstWhere(
            (r) => r['name']?.toString().toLowerCase() == routeStr.toLowerCase(),
            orElse: () => <String, dynamic>{},
          );
          if (routeInfo != null && routeInfo['dr_count'] != null) {
            routes.add('${i + 1}. $routeStr (Tagged doctor\'s: ${routeInfo['dr_count']})');
          } else {
            routes.add('${i + 1}. $routeStr');
          }
        }
        routeName = routes.join('\n');
      } else {
        routeName = (plan['route_name'] ?? plan['route'] ?? '').toString();
      }
    }
    String activityName = plan != null ? (plan['activity_name'] ?? '').toString() : '';
    String remark = plan != null ? (plan['remark'] ?? '').toString() : '';
    
    List<dynamic> jointWorkList = plan != null && plan['joint_work'] != null && plan['joint_work'] is List ? plan['joint_work'] : [];
    String jointWorkStr = jointWorkList.join('\n');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: plan != null ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday ? const Color(0xFF2E3192) : (plan != null ? Colors.green.shade200 : Colors.grey.shade200),
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isToday ? const Color(0xFF2E3192).withValues(alpha: 0.1) : Colors.transparent,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E3192).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    DateFormat('dd').format(date),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF2E3192)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE').format(date),
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      DateFormat('MMM yyyy').format(date),
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const Spacer(),
                if (plan != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text("Saved", style: GoogleFonts.poppins(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                
              ],
            ),
          ),
          
          if (plan != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  if (w > 800) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _infoField('Route', routeName, Icons.map, Colors.orange)),
                        const SizedBox(width: 8),
                        Expanded(child: _infoField('Joint Work', jointWorkStr.isEmpty ? 'None' : jointWorkStr, Icons.handshake, Colors.teal)),
                        const SizedBox(width: 8),
                        Expanded(child: _infoField('Work Type', activityName.isEmpty ? 'N/A' : activityName, Icons.work, Colors.blue)),
                        const SizedBox(width: 8),
                        Expanded(child: _infoField('Remark', remark.isEmpty ? 'No remark' : remark, Icons.notes, Colors.grey)),
                      ],
                    );
                  } else if (w > 480) {
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _infoField('Route', routeName, Icons.map, Colors.orange)),
                            const SizedBox(width: 8),
                            Expanded(child: _infoField('Joint Work', jointWorkStr.isEmpty ? 'None' : jointWorkStr, Icons.handshake, Colors.teal)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _infoField('Work Type', activityName.isEmpty ? 'N/A' : activityName, Icons.work, Colors.blue)),
                            const SizedBox(width: 8),
                            Expanded(child: _infoField('Remark', remark.isEmpty ? 'No remark' : remark, Icons.notes, Colors.grey)),
                          ],
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoField('Route', routeName, Icons.map, Colors.orange),
                        const SizedBox(height: 8),
                        _infoField('Joint Work', jointWorkStr.isEmpty ? 'None' : jointWorkStr, Icons.handshake, Colors.teal),
                        const SizedBox(height: 8),
                        _infoField('Work Type', activityName.isEmpty ? 'N/A' : activityName, Icons.work, Colors.blue),
                        const SizedBox(height: 8),
                        _infoField('Remark', remark.isEmpty ? 'No remark' : remark, Icons.notes, Colors.grey),
                      ],
                    );
                  }
                }
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoField(String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            value.isEmpty ? '---' : value,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
          ),
        ),
      ],
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: color)
      ),
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