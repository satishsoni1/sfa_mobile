import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/report_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/models/tour_plan.dart';
import '../../data/models/doctor.dart';
import 'create_tour_plan_screen.dart';

class TourPlanScreen extends StatefulWidget {
  const TourPlanScreen({super.key});

  @override
  State<TourPlanScreen> createState() => _TourPlanScreenState();
}

class _TourPlanScreenState extends State<TourPlanScreen> {
  DateTime _selectedDate = DateTime.now();
  List<TourPlan> _monthlyPlans = [];
  bool _isPlansLoading = false;
  bool _isDoctorsLoading = true;
  final ApiService _api = ApiService();

  // Professional Color Palette
  final Color _primaryColor = const Color(0xFF5E35B1); // Deep Purple
  final Color _bgColor = const Color(0xFFF5F7FA); // Light Blue-Grey
  final Color _cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadDoctors();
    });
  }

  Future<void> _checkAndLoadDoctors() async {
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    if (reportProvider.doctors.isNotEmpty) {
      if (mounted) setState(() => _isDoctorsLoading = false);
      return;
    }
    try {
      await reportProvider.fetchDoctors();
    } catch (e) {
      debugPrint("Error loading doctors: $e");
    } finally {
      if (mounted) setState(() => _isDoctorsLoading = false);
    }
  }

  void _fetchPlans() async {
    setState(() => _isPlansLoading = true);
    try {
      final plans = await _api.getTourPlans(_selectedDate);
      setState(() => _monthlyPlans = plans);
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isPlansLoading = false);
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

  // --- SUBMIT WORKFLOW ---
  void _submitForApproval() async {
    if (_currentPlan == null) return;

    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Submit Plan?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Once submitted, the plan will be locked for approval. You cannot edit it afterwards.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Submit", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isPlansLoading = true);
      try {
        await _api.updatePlanStatus(_currentPlan!.id, 'Pending');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Plan submitted successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
        _fetchPlans();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isPlansLoading = false);
      }
    }
  }

  void _deleteCurrentPlan() async {
    if (_currentPlan?.status != 'Draft' && _currentPlan?.status != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Locked plans cannot be deleted."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Delete Plan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: const Text("Are you sure you want to delete this plan?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isPlansLoading = true);
      await _api.deletePlan(_selectedDate);
      _fetchPlans();
    }
  }

  void _handleAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$action functionality coming soon")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctors = Provider.of<ReportProvider>(context).doctors;
    final plan = _currentPlan;
    final bool isLoading = _isPlansLoading || _isDoctorsLoading;
    final bool isLocked = plan != null && (plan.status ?? 'Draft') != 'Draft';

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          "Tour Planner",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month_outlined, color: _primaryColor),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(primary: _primaryColor),
                    ),
                    child: child!,
                  );
                },
              );
              if (d != null) {
                setState(() => _selectedDate = d);
                _fetchPlans();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isLocked ? Colors.blueGrey : _primaryColor,
        icon: Icon(
          isLocked ? Icons.visibility : Icons.edit,
          color: Colors.white,
        ),
        label: Text(
          isLocked ? "View" : (plan == null ? "Create Plan" : "Edit"),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateTourPlanScreen(
                initialDate: _selectedDate,
                existingPlan: plan,
                isReadOnly: isLocked,
              ),
            ),
          );
          _fetchPlans();
        },
      ),
      body: Column(
        children: [
          // 1. STATS HEADER
          _buildSummarySection(),

          // 2. CALENDAR STRIP
          _buildDateStrip(),

          // 3. MAIN CONTENT AREA
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : plan == null
                ? _buildEmptyState()
                : _buildPlanDetails(plan, doctors, isLocked),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSummarySection() {
    int draft = _monthlyPlans.where((p) => p.status == 'Draft').length;
    int pending = _monthlyPlans.where((p) => p.status == 'Pending').length;
    int approved = _monthlyPlans.where((p) => p.status == 'Approved').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          _buildStatCard(
            "Draft",
            draft,
            Colors.grey.shade100,
            Colors.grey.shade700,
            Icons.edit_note,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            "Pending",
            pending,
            const Color(0xFFFFF3E0),
            Colors.orange.shade800,
            Icons.hourglass_top,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            "Approved",
            approved,
            const Color(0xFFE8F5E9),
            Colors.green.shade800,
            Icons.check_circle_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    int count,
    Color bg,
    Color textCol,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: textCol),
            const SizedBox(height: 4),
            Text(
              "$count",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textCol,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 11, color: textCol),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateStrip() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day,
        itemBuilder: (context, index) {
          final date = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            index + 1,
          );
          final isSelected = DateUtils.isSameDay(date, _selectedDate);

          final dayPlan = _monthlyPlans.firstWhere(
            (p) => DateUtils.isSameDay(p.date, date),
            orElse: () =>
                TourPlan(id: -1, date: date, doctorIds: [], status: 'None'),
          );

          Color statusColor = Colors.transparent;
          if (dayPlan.status == 'Draft') statusColor = Colors.grey;
          if (dayPlan.status == 'Pending') statusColor = Colors.orange;
          if (dayPlan.status == 'Approved') statusColor = Colors.green;
          if (dayPlan.status == 'Rejected') statusColor = Colors.red;

          return InkWell(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 55,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? null
                    : Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date).toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd').format(date),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (dayPlan.doctorIds.isNotEmpty)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
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
          Icon(
            Icons.event_note_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "No Plan for ${DateFormat('dd MMM').format(_selectedDate)}",
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap + to create a new tour plan",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanDetails(TourPlan plan, List<Doctor> doctors, bool isLocked) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STATUS BANNER
          _buildStatusBanner(plan.status ?? 'Draft', isLocked),

          const SizedBox(height: 16),

          // ACTIONS (Only if Draft)
          if (!isLocked)
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    Icons.copy,
                    "Copy",
                    Colors.blue,
                    () => _handleAction('copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    Icons.delete_outline,
                    "Delete",
                    Colors.red,
                    _deleteCurrentPlan,
                  ),
                ),
              ],
            ),

          if (!isLocked) const SizedBox(height: 16),

          // SUBMIT BUTTON (Only if Draft)
          if (!isLocked)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitForApproval,
                icon: const Icon(
                  Icons.send_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  "SUBMIT FOR APPROVAL",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),

          const SizedBox(height: 24),

          // DOCTOR LIST HEADER
          Row(
            children: [
              Text(
                "Planned Visits",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${plan.doctorIds.length} Doctors",
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // LIST
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: plan.doctorIds.length,
            itemBuilder: (context, index) {
              final id = plan.doctorIds[index];
              Doctor? doc;
              try {
                doc = doctors.firstWhere(
                  (d) => d.id.toString() == id.toString(),
                );
              } catch (e) {
                doc = null;
              }

              return _buildDoctorCard(doc, index, id);
            },
          ),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String status, bool isLocked) {
    Color color = Colors.grey;
    IconData icon = Icons.edit_note;

    if (status == 'Pending') {
      color = Colors.orange;
      icon = Icons.hourglass_top;
    }
    if (status == 'Approved') {
      color = Colors.green;
      icon = Icons.check_circle;
    }
    if (status == 'Rejected') {
      color = Colors.red;
      icon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Plan Status",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                status.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (isLocked)
            Chip(
              label: const Text(
                "LOCKED",
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: Colors.grey,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(Doctor? doc, int index, int id) {
    if (doc == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 20),
            const SizedBox(width: 12),
            Text(
              "Unknown Doctor (ID: $id)",
              style: TextStyle(color: Colors.red.shade900),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: _primaryColor.withOpacity(0.1),
          child: Text(
            "${index + 1}",
            style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          doc.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 14,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Text(
              doc.area,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey.shade300,
        ),
      ),
    );
  }
}
