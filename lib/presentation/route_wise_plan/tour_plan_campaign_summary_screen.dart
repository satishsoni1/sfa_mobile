import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class TourPlanCampaignSummaryScreen extends StatefulWidget {
  final int employeeId;
  final String employeeName;
  final DateTime month;
  final Map<String, dynamic>? initialData;

  const TourPlanCampaignSummaryScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    this.initialData,
  });

  @override
  State<TourPlanCampaignSummaryScreen> createState() => _TourPlanCampaignSummaryScreenState();
}

class _TourPlanCampaignSummaryScreenState extends State<TourPlanCampaignSummaryScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _isLoading = false;
  Map<String, dynamic>? _summaryData;
  String? _errorMessage;

  late TabController _tabController;
  final Set<int> _expandedCampaignIds = {};
  String _doctorSearchQuery = '';
  String _selectedCategoryFilter = 'All';

  final Color _primaryColor = const Color(0xFF2E3192);
  final Color _purpleColor = const Color(0xFF4A148C);
  final Color _bgColor = const Color(0xFFF4F6F9);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialData != null && widget.initialData!['data'] != null) {
      _summaryData = widget.initialData;
      _isLoading = false;
    } else {
      _fetchSummary();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final monthStr = DateFormat('yyyy-MM').format(widget.month);
      final res = await _api.fetchTourPlanCampaignValidation(
        employeeId: widget.employeeId,
        month: monthStr,
      );

      if (mounted) {
        setState(() {
          if (res['success'] == true && res['data'] != null) {
            _summaryData = res;
          } else {
            _errorMessage = res['message']?.toString() ?? "Failed to load summary data.";
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _formatChipDate(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate);
      return DateFormat('dd MMM').format(dt);
    } catch (_) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(widget.month);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Campaign & Call Summary",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              "${widget.employeeName} • $monthLabel",
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Summary",
            onPressed: _isLoading ? null : _fetchSummary,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _summaryData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: 16),
            Text(
              "Loading campaign validation summary...",
              style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _summaryData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 54, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text(
                "Unable to Load Summary",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchSummary,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text("Retry", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
              ),
            ],
          ),
        ),
      );
    }

    final data = _summaryData?['data'] as Map<String, dynamic>? ?? {};
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final List<dynamic> campaigns = summary['campaigns'] as List<dynamic>? ?? [];
    final List<dynamic> doctors = data['doctors'] as List<dynamic>? ?? [];

    final bool isValid = summary['is_valid'] == true || _summaryData?['is_valid'] == true;
    final List<dynamic> validationErrors = summary['validation_errors'] as List<dynamic>? ??
        (_summaryData?['errors'] as List<dynamic>? ?? []);

    return RefreshIndicator(
      onRefresh: _fetchSummary,
      color: _primaryColor,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildValidationBanner(isValid, validationErrors),
                  _buildEmployeeContext(summary),
                  _buildKpiMetrics(summary, campaigns.length),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: _primaryColor,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: _primaryColor,
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.campaign_outlined, size: 18),
                          const SizedBox(width: 6),
                          Text("Campaigns (${campaigns.length})"),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_pin_outlined, size: 18),
                          const SizedBox(width: 6),
                          Text("Doctor Matrix (${doctors.length})"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildCampaignsTab(campaigns),
            _buildDoctorMatrixTab(doctors),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 1. EXECUTIVE VALIDATION BANNER
  // =========================================================================
  Widget _buildValidationBanner(bool isValid, List<dynamic> validationErrors) {
    if (isValid) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9), // Light green
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade300, width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, color: Colors.green.shade800, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tour Plan Validated & Compliant",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "All campaign visit frequencies and expected call targets are satisfied.",
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE), // Light red
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade800, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Validation Issues Detected",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Colors.red.shade900,
                      ),
                    ),
                    Text(
                      validationErrors.isNotEmpty
                          ? "${validationErrors.length} requirement(s) must be adjusted before final approval."
                          : "Review campaign visits to match the expected calls.",
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (validationErrors.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFFFCDD2)),
            const SizedBox(height: 8),
            ...validationErrors.take(5).map((err) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(Icons.circle, size: 6, color: Colors.red.shade700),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          err.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.red.shade900,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            if (validationErrors.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  "+ ${validationErrors.length - 5} more issues",
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // 2. EMPLOYEE & TERRITORY CONTEXT BADGE
  // =========================================================================
  Widget _buildEmployeeContext(Map<String, dynamic> summary) {
    final repName = summary['employee_name']?.toString() ?? widget.employeeName;
    final desig = summary['designation']?.toString() ?? '';
    final hq = summary['head_qtr']?.toString() ?? '';
    final division = summary['division']?.toString() ?? '';
    final manager = summary['manager_name']?.toString().trim() ?? '';
    final tpStatus = summary['tp_status']?.toString() ?? 'Draft';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.badge_outlined, color: _primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$repName ${desig.isNotEmpty ? '($desig)' : ''}",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "${hq.isNotEmpty ? 'HQ: $hq' : ''}${division.isNotEmpty ? ' • Div: $division' : ''}${manager.isNotEmpty ? ' • Mgr: $manager' : ''}",
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tpStatus == 'Approved'
                  ? Colors.green.shade50
                  : (tpStatus == 'Pending' ? Colors.orange.shade50 : Colors.blue.shade50),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: tpStatus == 'Approved'
                    ? Colors.green.shade300
                    : (tpStatus == 'Pending' ? Colors.orange.shade300 : Colors.blue.shade300),
              ),
            ),
            child: Text(
              tpStatus.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: tpStatus == 'Approved'
                    ? Colors.green.shade800
                    : (tpStatus == 'Pending' ? Colors.orange.shade800 : Colors.blue.shade800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. EXECUTIVE KPI TILES (4 TILES)
  // =========================================================================
  Widget _buildKpiMetrics(Map<String, dynamic> summary, int actualCampaignsCount) {
    final int expectedCalls = int.tryParse(summary['expected_calls']?.toString() ?? '0') ?? 0;
    final int plannedCalls = int.tryParse(summary['planned_calls']?.toString() ?? '0') ?? 0;
    final int callsDiff = int.tryParse(summary['calls_difference']?.toString() ?? '0') ?? (plannedCalls - expectedCalls);

    final int targetDoctors = int.tryParse(summary['target_doctors_count']?.toString() ?? '0') ?? 0;
    final int uniqueDoctors = int.tryParse(summary['unique_doctors_planned']?.toString() ?? '0') ?? 0;
    final int daysFilled = int.tryParse(summary['tp_days_filled']?.toString() ?? '0') ?? 0;
    final int campCount = int.tryParse(summary['campaigns_count']?.toString() ?? '0') ?? actualCampaignsCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.phone_in_talk_outlined,
                  title: "Total Calls",
                  mainValue: "$plannedCalls / $expectedCalls",
                  subtitle: callsDiff == 0
                      ? "Target Met (0 diff)"
                      : (callsDiff > 0 ? "+$callsDiff Extra calls" : "$callsDiff Short of target"),
                  color: callsDiff == 0 ? Colors.green.shade700 : (callsDiff > 0 ? Colors.blue.shade700 : Colors.red.shade700),
                  progress: expectedCalls > 0 ? (plannedCalls / expectedCalls).clamp(0.0, 1.0) : 0.0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.people_outline,
                  title: "Target Doctors",
                  mainValue: "$uniqueDoctors / $targetDoctors",
                  subtitle: "$uniqueDoctors unique planned",
                  color: uniqueDoctors >= targetDoctors ? Colors.indigo.shade700 : Colors.orange.shade800,
                  progress: targetDoctors > 0 ? (uniqueDoctors / targetDoctors).clamp(0.0, 1.0) : 0.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.calendar_month_outlined,
                  title: "Days Filled",
                  mainValue: "$daysFilled Days",
                  subtitle: "Active planned days",
                  color: _primaryColor,
                  progress: null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.campaign,
                  title: "Campaigns",
                  mainValue: "$campCount Active",
                  subtitle: "${summary['mapped_doctor_campaigns_count'] ?? 0} mapped slots",
                  color: _purpleColor,
                  progress: null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String title,
    required String mainValue,
    required String subtitle,
    required Color color,
    double? progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mainValue,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              color: Colors.grey.shade600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. TAB 1: CAMPAIGNS BREAKDOWN
  // =========================================================================
  Widget _buildCampaignsTab(List<dynamic> campaigns) {
    if (campaigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              "No campaign data found",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: campaigns.length,
      itemBuilder: (context, index) {
        final camp = campaigns[index] as Map<String, dynamic>;
        final int campId = int.tryParse(camp['campaign_id']?.toString() ?? '') ?? index;
        final isExpanded = _expandedCampaignIds.contains(campId);
        final bool isCampValid = camp['is_valid'] == true;
        final List<dynamic> doctors = camp['doctors'] as List<dynamic>? ?? [];
        final List<dynamic> errors = camp['validation_errors'] as List<dynamic>? ?? [];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isCampValid ? Colors.grey.shade200 : Colors.red.shade200,
              width: isCampValid ? 1 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCampValid ? const Color(0xFFFAF5FC) : Colors.red.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _purpleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.campaign, color: _purpleColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            camp['campaign_name']?.toString() ?? 'Campaign #$campId',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _purpleColor,
                            ),
                          ),
                          if (camp['campaign_type'] != null && camp['campaign_type'].toString().trim().isNotEmpty)
                            Text(
                              camp['campaign_type'].toString().trim(),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCampValid ? Colors.green.shade50 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCampValid ? Colors.green.shade300 : Colors.red.shade400,
                        ),
                      ),
                      child: Text(
                        isCampValid ? "Valid" : "Issues",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCampValid ? Colors.green.shade800 : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Campaign Quick Stats
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildPillTag(
                      "Target: ${camp['no_of_dr'] ?? camp['no_of_doctors']} Drs",
                      Colors.blue.shade50,
                      Colors.blue.shade800,
                    ),
                    _buildPillTag(
                      "Freq: ${camp['visit_count']}x / Dr",
                      Colors.purple.shade50,
                      _purpleColor,
                    ),
                    _buildPillTag(
                      "Calls: ${camp['planned_calls']} / ${camp['expected_calls']}",
                      camp['planned_calls'] == camp['expected_calls']
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      camp['planned_calls'] == camp['expected_calls']
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                    ),
                  ],
                ),
              ),

              // Any validation errors
              if (errors.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: errors.map((err) => Text(
                        "• $err",
                        style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                      )).toList(),
                    ),
                  ),
                ),

              // Expand / Collapse Action
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedCampaignIds.remove(campId);
                    } else {
                      _expandedCampaignIds.add(campId);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.people : Icons.people_outline,
                        size: 16,
                        color: _purpleColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isExpanded
                            ? "Hide Tagged Doctors (${doctors.length})"
                            : "View ${doctors.length} Tagged Doctors",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _purpleColor,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: _purpleColor,
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded Doctors List
              if (isExpanded)
                Container(
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: doctors.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            "No doctors tagged for this campaign.",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        )
                      : Column(
                          children: doctors.map((doc) {
                            final List<dynamic> plannedDates = doc['planned_dates'] as List<dynamic>? ?? [];
                            final bool isDocValid = doc['is_valid'] == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          doc['doctor_name']?.toString() ?? 'Unnamed Doctor',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                      if (doc['category'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            doc['category'].toString(),
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo.shade800,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${doc['planned_calls']}/${doc['required_visits']} visits",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDocValid ? Colors.green.shade800 : Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (doc['speciality'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: Text(
                                        doc['speciality'].toString(),
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  if (plannedDates.isNotEmpty)
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: plannedDates.map((d) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _purpleColor.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: _purpleColor.withValues(alpha: 0.2)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.calendar_today, size: 9, color: _purpleColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatChipDate(d.toString()),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: _purpleColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // 5. TAB 2: DOCTOR COVERAGE MATRIX
  // =========================================================================
  Widget _buildDoctorMatrixTab(List<dynamic> doctors) {
    if (doctors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              "No planned doctors found in summary",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Extract categories for filter
    final categories = <String>{'All'};
    for (var d in doctors) {
      final cat = d['category']?.toString();
      if (cat != null && cat.isNotEmpty) categories.add(cat);
    }

    final filtered = doctors.where((d) {
      final name = d['doctor_name']?.toString().toLowerCase() ?? '';
      final spec = d['speciality']?.toString().toLowerCase() ?? '';
      final cat = d['category']?.toString() ?? '';

      final matchesQuery = _doctorSearchQuery.isEmpty ||
          name.contains(_doctorSearchQuery.toLowerCase()) ||
          spec.contains(_doctorSearchQuery.toLowerCase());

      final matchesCategory = _selectedCategoryFilter == 'All' || cat == _selectedCategoryFilter;

      return matchesQuery && matchesCategory;
    }).toList();

    return Column(
      children: [
        // Search & Filter Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _doctorSearchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: "Search doctor by name or speciality...",
                  hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: categories.map((cat) {
                    final isSel = _selectedCategoryFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? Colors.white : Colors.black87,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: _primaryColor,
                        backgroundColor: Colors.grey.shade100,
                        onSelected: (_) => setState(() => _selectedCategoryFilter = cat),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Count header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Showing ${filtered.length} of ${doctors.length} Doctors",
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),

        // Doctor List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final doc = filtered[index] as Map<String, dynamic>;
              final List<dynamic> plannedDates = doc['planned_dates'] as List<dynamic>? ?? [];
              final List<dynamic> docCampaigns = doc['campaigns'] as List<dynamic>? ?? [];
              final int campCount = int.tryParse(doc['campaigns_count']?.toString() ?? '') ?? docCampaigns.length;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc['doctor_name']?.toString() ?? 'Unnamed Doctor',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  "${doc['speciality'] ?? ''} ${doc['category'] != null ? '• ${doc['category']}' : ''}",
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: campCount > 1 ? Colors.purple.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: campCount > 1 ? Colors.purple.shade200 : Colors.blue.shade200,
                              ),
                            ),
                            child: Text(
                              "$campCount Campaign${campCount > 1 ? 's' : ''}",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: campCount > 1 ? _purpleColor : Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Planned dates
                      Text(
                        "Planned Visit Dates (${plannedDates.length}):",
                        style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: plannedDates.map((d) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EAF6), // soft indigo
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.indigo.shade100),
                            ),
                            child: Text(
                              _formatChipDate(d.toString()),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade900,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Campaign sub-breakdown
                      if (docCampaigns.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: docCampaigns.map((c) {
                              final List<dynamic> cDates = c['planned_dates'] as List<dynamic>? ?? [];
                              final datesStr = cDates.map((cd) => _formatChipDate(cd.toString())).join(', ');
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.campaign, size: 12, color: _purpleColor),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        "${c['campaign_name']}: ${c['planned_calls']} calls on [$datesStr]",
                                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade800),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPillTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}

// Delegate for sticky tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
