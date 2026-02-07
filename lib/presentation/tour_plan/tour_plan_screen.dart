import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/report_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/tour_plan.dart';
import '../../data/models/doctor.dart'; // Import Doctor model to use as type
import 'create_tour_plan_screen.dart';

class TourPlanScreen extends StatefulWidget {
  const TourPlanScreen({super.key});

  @override
  State<TourPlanScreen> createState() => _TourPlanScreenState();
}

class _TourPlanScreenState extends State<TourPlanScreen> {
  DateTime _selectedDate = DateTime.now();
  List<TourPlan> _monthlyPlans = [];
  bool _isLoading = false;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  void _fetchPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await _api.getTourPlans(_selectedDate);
      setState(() => _monthlyPlans = plans);
    } catch (e) {
      // debugPrint("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  TourPlan? get _currentPlan {
    try {
      return _monthlyPlans.firstWhere(
        (p) => DateUtils.isSameDay(p.date, _selectedDate),
      );
    } catch (e) {
      return null;
    }
  }

  void _handleAction(String action) async {
    if (_currentPlan == null) return;

    final DateTime? targetDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate.add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      helpText: "Select Target Date to $action",
    );

    if (targetDate != null) {
      setState(() => _isLoading = true);
      try {
        await _api.duplicatePlan(
          _selectedDate,
          targetDate,
          action.toLowerCase(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Plan ${action}d successfully!")),
          );
        }
        _fetchPlans();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _deleteCurrentPlan() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Plan"),
        content: const Text("Are you sure you want to delete this plan?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await _api.deletePlan(_selectedDate);
      _fetchPlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get the list of doctors from Provider
    final doctors = Provider.of<ReportProvider>(context).doctors;
    final plan = _currentPlan;

    return Scaffold(
      appBar: AppBar(
        title: Text("Tour Plan", style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF4A148C),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
              );
              if (d != null) {
                setState(() => _selectedDate = d);
                _fetchPlans();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4A148C),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateTourPlanScreen(
                initialDate: _selectedDate,
                existingPlan: plan,
              ),
            ),
          );
          _fetchPlans();
        },
      ),
      body: Column(
        children: [
          // 1. Horizontal Date Strip
          Container(
            height: 80,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 30, // Note: Should ideally be daysInMonth
              itemBuilder: (context, index) {
                final startOfMonth = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  1,
                );
                final date = DateTime(
                  startOfMonth.year,
                  startOfMonth.month,
                  index + 1,
                );

                if (date.month != _selectedDate.month)
                  return const SizedBox.shrink();

                final isSelected = DateUtils.isSameDay(date, _selectedDate);
                final hasPlan = _monthlyPlans.any(
                  (p) => DateUtils.isSameDay(p.date, date),
                );

                return InkWell(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4A148C)
                          : (hasPlan ? Colors.purple[50] : Colors.transparent),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4A148C)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white : Colors.grey,
                          ),
                        ),
                        Text(
                          DateFormat('dd').format(date),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                        if (hasPlan && !isSelected)
                          const CircleAvatar(
                            radius: 3,
                            backgroundColor: Colors.purple,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // 2. Plan Details
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : plan == null
                ? Center(
                    child: Text(
                      "No plan for this date",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : Column(
                    children: [
                      // Action Bar
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _actionBtn(
                              Icons.copy,
                              "Copy To",
                              () => _handleAction('copy'),
                            ),
                            _actionBtn(
                              Icons.drive_file_move_outlined,
                              "Move To",
                              () => _handleAction('move'),
                            ),
                            _actionBtn(
                              Icons.delete_outline,
                              "Delete",
                              _deleteCurrentPlan,
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),

                      // Doctor List
                      Expanded(
                        child: ListView.builder(
                          itemCount: plan.doctorIds.length,
                          itemBuilder: (context, index) {
                            final id = plan.doctorIds[index];

                            // --- FIX STARTS HERE ---
                            // Attempt to find the doctor by converting BOTH IDs to String.
                            // This handles cases where one is int and the other is String.
                            Doctor? doc;
                            try {
                              doc = doctors.firstWhere(
                                (d) => d.id.toString() == id.toString(),
                              );
                            } catch (e) {
                              doc = null; // Doctor not found in master list
                            }

                            // If not found, show a placeholder instead of incorrect data
                            if (doc == null) {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red.shade100,
                                  child: const Icon(
                                    Icons.error,
                                    color: Colors.red,
                                  ),
                                ),
                                title: Text(
                                  "Unknown Doctor (ID: $id)",
                                  style: const TextStyle(color: Colors.red),
                                ),
                                subtitle: const Text(
                                  "Not found in master list",
                                ),
                              );
                            }
                            // --- FIX ENDS HERE ---

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[200],
                                child: Text(
                                  "${index + 1}",
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                              title: Text(
                                doc.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(doc.area),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = Colors.black87,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
