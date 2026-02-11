import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/report_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/tour_plan.dart';
import '../../data/models/doctor.dart';
import 'create_tour_plan_screen.dart';
import '../doctor_list/add_doctor_screen.dart';

class TourPlanScreen extends StatefulWidget {
  const TourPlanScreen({super.key});

  @override
  State<TourPlanScreen> createState() => _TourPlanScreenState();
}

class _TourPlanScreenState extends State<TourPlanScreen> {
  // State
  DateTime _selectedDate = DateTime.now();
  List<TourPlan> _monthlyPlans = [];
  List<dynamic> _subordinates = [];
  dynamic _selectedSubordinate; // Null = Myself

  bool _isLoading = false;
  final ApiService _api = ApiService();

  // UX Colors
  final Color _primaryColor = const Color(0xFF4A148C);
  final Color _accentColor = const Color(0xFF7B1FA2);
  final Color _bgColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final subs = await _api.getSubordinates();
      await _fetchPlans();
      
      // Always fetch latest doctor list for "Myself" to ensure cache is fresh
      if (mounted) {
        final provider = Provider.of<ReportProvider>(context, listen: false);
        await provider.fetchDoctors();
      }

      if (mounted) setState(() => _subordinates = subs);
    } catch (e) {
      debugPrint("Error loading data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPlans() async {
    setState(() => _isLoading = true);
    try {
      // If viewing subordinate, pass their ID. Else pass null (for Self).
      int? targetUserId = _selectedSubordinate?['id'];
      final plans = await _api.getTourPlans(_selectedDate, userId: targetUserId);
      if (mounted) setState(() => _monthlyPlans = plans);
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSubordinateChanged(dynamic sub) {
    setState(() {
      _selectedSubordinate = sub;
      _monthlyPlans = []; // Clear view immediately
    });
    _fetchPlans();
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

  Future<void> _submitForApproval() async {
    if (_currentPlan == null) return;

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Submission"),
        content: const Text("Once submitted, the plan will be locked for approval."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text("Submit", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );

    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    try {
      await _api.updatePlanStatus(_currentPlan!.id, 'Pending'); // Ensure your API supports this
      await _fetchPlans(); 
      if(mounted) _showSnack("Plan submitted successfully!", Colors.green);
    } catch (e) {
      if(mounted) _showSnack("Failed to submit: $e", Colors.red);
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDoctorsCount = Provider.of<ReportProvider>(context).doctors.length;
    final plan = _currentPlan;

    // --- LOCK LOGIC ---
    // 1. View Only: If viewing a Subordinate
    // 2. Locked: If Plan status is Pending, Approved, or Rejected
    bool isViewingSubordinate = _selectedSubordinate != null;
    bool isStatusLocked = false;
    
    if (plan != null && plan.status != null) {
      final s = plan.status!.trim().toLowerCase();
      if (s == 'pending' || s == 'approved' || s == 'rejected') isStatusLocked = true;
    }

    bool isReadOnly = isViewingSubordinate || isStatusLocked;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Tour Planner", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
            Text(
              isViewingSubordinate ? "Viewing: ${_selectedSubordinate['name']}" : "Planning for: Myself",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            )
          ],
        ),
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isReadOnly ? Colors.grey : _primaryColor,
        icon: Icon(
          isViewingSubordinate ? Icons.visibility : (isStatusLocked ? Icons.lock : (plan == null ? Icons.add : Icons.edit)), 
          color: Colors.white
        ),
        label: Text(
          isViewingSubordinate 
              ? "View Plan" 
              : (isStatusLocked ? "Locked" : (plan == null ? "Create Plan" : "Edit Plan")),
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        onPressed: () async {
          // Navigate to Create/View Screen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateTourPlanScreen(
                initialDate: _selectedDate,
                existingPlan: plan,
                isReadOnly: isReadOnly, 
                // Pass subordinate info to load correct context
                targetUserId: _selectedSubordinate?['id'],
                targetUserName: _selectedSubordinate?['name'] ?? "Myself",
              ),
            ),
          );
          
          // Refresh list if save occurred
          if (result == true) {
            _fetchPlans();
          }
        },
      ),

      body: Column(
        children: [
          // 1. SUBORDINATE DROPDOWN
          if (_subordinates.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<dynamic>(
                decoration: const InputDecoration(
                  labelText: "Select View",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                value: _selectedSubordinate,
                items: [
                  const DropdownMenuItem(value: null, child: Text("Myself (Edit Mode)")),
                  ..._subordinates.map((sub) => DropdownMenuItem(value: sub, child: Text("${sub['name']} (View Only)"))),
                ],
                onChanged: _onSubordinateChanged,
              ),
            ),

          // 2. SUMMARY DASHBOARD
          _buildMonthlySummary(totalDoctorsCount),

          // 3. CALENDAR STRIP
          _buildDateStrip(),

          // 4. PLAN DETAILS
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : plan == null
                    ? _buildEmptyState()
                    : _buildPlanDetails(plan, isReadOnly),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildMonthlySummary(int totalDocs) {
    Set<int> uniqueDocs = {};
    int plannedDays = 0;
    
    for (var p in _monthlyPlans) {
      if (p.doctorIds.isNotEmpty) {
        uniqueDocs.addAll(p.doctorIds);
        plannedDays++;
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_primaryColor, _accentColor]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem("Planned\nDays", "$plannedDays", Icons.calendar_today),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem("Unique\nDoctors", "${uniqueDocs.length}", Icons.pie_chart),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem("Total\nVisits", "${_monthlyPlans.fold(0, (sum, p) => sum + p.doctorIds.length)}", Icons.directions_walk),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10, height: 1.2)),
      ],
    );
  }

  Widget _buildDateStrip() {
    return Container(
      height: 90,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day,
        itemBuilder: (context, index) {
          final date = DateTime(_selectedDate.year, _selectedDate.month, index + 1);
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          
          final plan = _monthlyPlans.firstWhere(
            (p) => DateUtils.isSameDay(p.date, date),
            orElse: () => TourPlan(id: -1, date: date, doctorIds: [], status: null),
          );

          Color dotColor = Colors.transparent;
          String s = (plan.status ?? '').toLowerCase();
          if (s == 'draft') dotColor = Colors.grey;
          if (s == 'pending') dotColor = Colors.orange;
          if (s == 'approved') dotColor = Colors.green;
          if (s == 'rejected') dotColor = Colors.red;

          return InkWell(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 55,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                boxShadow: isSelected ? [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 5)] : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('EEE').format(date).toUpperCase(), style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : Colors.grey)),
                  Text(DateFormat('dd').format(date), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                  if (plan.status != null)
                    Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: isSelected ? Colors.white : dotColor, shape: BoxShape.circle)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_calendar, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No Plan Set", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildPlanDetails(TourPlan plan, bool isReadOnly) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status & Submit Button
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getStatusColor(plan.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getStatusColor(plan.status).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(_getStatusIcon(plan.status), size: 18, color: _getStatusColor(plan.status)),
                    const SizedBox(width: 8),
                    Text(
                      plan.status ?? "Draft", 
                      style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(plan.status)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (!isReadOnly)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _submitForApproval,
                  icon: const Icon(Icons.send, size: 16, color: Colors.white),
                  label: const Text("Submit Plan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 20),
        Text("Planned Doctors (${plan.doctorIds.length})", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),

        // List logic: Use embedded doctors if available, otherwise ID fallback
        if (plan.doctors.isNotEmpty)
          ...plan.doctors.map((doc) => _buildDoctorRow(doc, isReadOnly))
        else
          ...plan.doctorIds.map((id) => Card(child: ListTile(title: Text("Doctor ID: $id (Details Loading...)")))),
        
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildDoctorRow(Doctor doc, bool isReadOnly) {
  // We use a high-contrast border and a slight background tint to highlight
  // doctors that were returned as part of the employee's plan.
  final bool isHighlighted = doc.isPlanned ?? false;

  return Card(
    elevation: isHighlighted ? 4 : 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: isHighlighted ? Colors.orange.shade700 : Colors.grey.shade200,
        width: isHighlighted ? 2.0 : 1.0,
      ),
    ),
    child: Container(
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.orange.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isHighlighted ? Colors.orange : _primaryColor.withOpacity(0.1),
              child: Icon(
                isHighlighted ? Icons.star : Icons.person,
                size: 18,
                color: isHighlighted ? Colors.white : _primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        doc.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isHighlighted ? Colors.orange.shade900 : Colors.black,
                        ),
                      ),
                      if (isHighlighted) ...[
                        const SizedBox(width: 8),
                        _buildTag("PLANNED", Colors.orange, Colors.white),
                      ]
                    ],
                  ),
                  Text(
                    "${doc.area} • ${doc.specialization}",
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: textCol)),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    String s = status.toLowerCase();
    if (s == 'approved') return Colors.green;
    if (s == 'pending') return Colors.orange;
    if (s == 'rejected') return Colors.red;
    return Colors.grey;
  }

  IconData _getStatusIcon(String? status) {
    if (status == null) return Icons.edit_note;
    String s = status.toLowerCase();
    if (s == 'approved') return Icons.check_circle;
    if (s == 'pending') return Icons.hourglass_top;
    if (s == 'rejected') return Icons.cancel;
    return Icons.edit_note;
  }
}