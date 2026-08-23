import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/api_service.dart';
import 'tour_plan_review_screen.dart';

// ---------------------------------------------------------------------------
// Data model – one per calendar day
// ---------------------------------------------------------------------------
class DayPlanData {
  final DateTime date;
  List<dynamic> selectedRoutes = [];
  List<dynamic> selectedJointWorks = [];
  dynamic selectedWorkType;
  TextEditingController remarkController = TextEditingController();
  bool isSaved = false;
  bool isSaving = false;
  bool isDirty = false;


  DayPlanData({required this.date});

  void dispose() => remarkController.dispose();
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------
class RouteTourPlanScreen extends StatefulWidget {
  const RouteTourPlanScreen({super.key});

  @override
  State<RouteTourPlanScreen> createState() => _RouteTourPlanScreenState();
}

class _RouteTourPlanScreenState extends State<RouteTourPlanScreen> {
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<dynamic> _subordinates = [];
  dynamic _selectedSubordinate; // null = myself

  List<dynamic> _allRoutes = [];
  List<dynamic> _allWorkTypes = [];
  List<dynamic> _allJointWorkMembers = []; // from /api/app/team/joint-work

  bool _isLoading = false;
  String _monthStatus = 'Draft';
  List<DayPlanData> _monthData = [];
  Map<String, dynamic> _apiPlans = {};

  static const Color _primary = AppColors.primary;
  static const Color _bgColor = Color(0xFFF4F6F9);

  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    for (final d in _monthData) {
      d.dispose();
    }
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getSubordinates().catchError((_) => <dynamic>[]),
        _api.fetchUserAreas().catchError((_) => <Map<String, dynamic>>[]),
        _api.getAdminWorkTypes().catchError((_) => <Map<String, dynamic>>[]),
        _api.getJointWorkList().catchError((_) => <dynamic>[]),
      ]);

      _subordinates = results[0];
      _allRoutes = results[1];
      _allWorkTypes = results[2];
      _allJointWorkMembers = results[3];

      await _fetchMonthlyPlans();
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMonthlyPlans() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.getMonthlyAreaPlans(
        _selectedMonth,
        userId: _selectedSubordinate?['id'],
      );
      if (mounted) {
        setState(() {
          _monthStatus = response['month_status'] ?? 'Draft';
          final plansData = response['plans'];
          _apiPlans = (plansData != null && plansData is Map)
              ? Map<String, dynamic>.from(plansData)
              : <String, dynamic>{};
          _generateMonthData(_apiPlans);
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch plans: $e');
      if (mounted) setState(() => _generateMonthData({}));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _generateMonthData(Map<String, dynamic> apiPlans) {
    for (final d in _monthData) {
      d.dispose();
    }
    _monthData = [];

    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

    for (int i = 1; i <= daysInMonth; i++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, i);
      final dKey = DateFormat('yyyy-MM-dd').format(date);
      final dayPlan = DayPlanData(date: date);

      if (apiPlans.containsKey(dKey)) {
        final p = apiPlans[dKey];
        dayPlan.isSaved = true;
        dayPlan.isDirty = false;
        dayPlan.remarkController.text = p['remark'] ?? '';

        if (p['areas'] != null) {
          List<dynamic> areaValues = [];
          if (p['areas'] is Map) {
            areaValues = (p['areas'] as Map).values.toList();
          } else if (p['areas'] is List) {
            areaValues = p['areas'] as List;
          }
          
          dayPlan.selectedRoutes = areaValues.map((areaVal) {
            return _allRoutes.firstWhere(
              (r) => r['id']?.toString() == areaVal.toString() || r['name']?.toString() == areaVal.toString(),
              orElse: () => {'id': areaVal, 'name': areaVal.toString()},
            );
          }).toList();
        }

        if (p['joint_work'] is List) {
          dayPlan.selectedJointWorks = (p['joint_work'] as List).map((jVal) {
            return _allJointWorkMembers.firstWhere(
              (s) => s['name']?.toString() == jVal.toString() || s['id']?.toString() == jVal.toString(),
              orElse: () => {'id': 0, 'name': jVal.toString()},
            );
          }).toList();
        }

        if (p['work_type_id'] != null && p['work_type_id'] != 0) {
          dayPlan.selectedWorkType = _allWorkTypes.firstWhere(
            (w) => w['id']?.toString() == p['work_type_id'].toString(),
            orElse: () => {'id': p['work_type_id'], 'name': p['activity_name'] ?? 'Unknown'},
          );
        } else if (p['activity_name'] != null) {
          dayPlan.selectedWorkType = _allWorkTypes.firstWhere(
            (w) => w['name']?.toString() == p['activity_name'].toString(),
            orElse: () => {'id': 0, 'name': p['activity_name']},
          );
        }
      }

      _monthData.add(dayPlan);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveDay(DayPlanData dayPlan) async {
    if (dayPlan.selectedRoutes.isEmpty && dayPlan.selectedWorkType == null) {
      _showSnack(
          'Please select at least a Route or Work Type before saving.',
          isError: true);
      return;
    }

    setState(() => dayPlan.isSaving = true);
    try {
      final payload = <String, dynamic>{
        'date': DateFormat('yyyy-MM-dd').format(dayPlan.date),
        'plan_date': DateFormat('yyyy-MM-dd').format(dayPlan.date),
        'plan_type': (dayPlan.selectedRoutes.isNotEmpty) ? 'Route' : 'Activity',
        'route_name': dayPlan.selectedRoutes.map((r) => r['name']).join(','),
        'activity_name': dayPlan.selectedWorkType?['name'],
        'areas': dayPlan.selectedRoutes.map((r) => r['id'] ?? r['name']).toList(),
        'joint_work': dayPlan.selectedJointWorks.map((j) => j['id']).toList(),
        'work_type_id': dayPlan.selectedWorkType?['id'],
        'remark': dayPlan.remarkController.text.trim(),
      };

      if (_selectedSubordinate != null) {
        payload['user_id'] = _selectedSubordinate['id'];
      }

      final success = await _api.saveAreaTourPlan(payload);
      if (success && mounted) {
        setState(() { 
          dayPlan.isSaved = true; 
          dayPlan.isDirty = false; 
          
          // Keep the review screen data synced
          final localAreas = {};
          for (int i = 0; i < dayPlan.selectedRoutes.length; i++) {
             localAreas['${i+1}'] = dayPlan.selectedRoutes[i]['name'] ?? '';
          }

          _apiPlans[payload['plan_date']] = {
            ...payload,
            'route': payload['route_name'],
            'areas': localAreas,
            'joint_work': dayPlan.selectedJointWorks.map((j) => j['name']).toList(),
          };
        });
        _showSnack('Day saved successfully!');
      } else {
        throw Exception('Server returned failure');
      }
    } catch (e) {
      if (mounted) _showSnack('Failed to save: $e', isError: true);
    } finally {
      if (mounted) setState(() => dayPlan.isSaving = false);
    }
  }




  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor:
          isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  int get _daysPlanned => _monthData.where((d) => d.isSaved).length;
  int get _totalRoutesSelected =>
      _monthData.fold(0, (sum, d) => sum + d.selectedRoutes.length);
  int get _daysWithJointWork =>
      _monthData.where((d) => d.selectedJointWorks.isNotEmpty).length;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isMonthLocked =
        _monthStatus == 'Pending' || _monthStatus == 'Approved';
    final bool isManagerView = _selectedSubordinate != null;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Tour Plan',
              style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            Text(
              _selectedSubordinate?['name'] ?? 'My Territory',
              style:
                  GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TourPlanReviewScreen(
                    currentMonth: _selectedMonth,
                    monthlyPlans: _apiPlans,
                    monthStatus: _monthStatus,
                    allRoutes: _allRoutes,
                    userId: _selectedSubordinate?['id'],
                  ),
                ),
              );
              if (result == true) _fetchMonthlyPlans();
            },
            icon: const Icon(Icons.fact_check_outlined,
                color: Colors.white, size: 18),
            label: Text('Review',
                style:
                    GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthHeader(),
          if (_monthStatus != 'Draft') _buildStatusBanner(),
          _buildTopStats(),

          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: _primary))
                : _buildDayList(isMonthLocked, isManagerView),
          ),

        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DateTime>(
                    value: _selectedMonth,
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.primary),
                    isDense: true,
                    items: [
                      for (int i = -3; i <= 1; i++)
                        DateTime(DateTime.now().year,
                            DateTime.now().month + i, 1)
                    ].map((date) {
                      return DropdownMenuItem<DateTime>(
                        value: date,
                        child: Text(
                          DateFormat('MMMM yyyy').format(date),
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                      );
                    }).toList(),
                    onChanged: (newMonth) {
                      if (newMonth != null) {
                        setState(() => _selectedMonth = newMonth);
                        _fetchMonthlyPlans();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          if (_subordinates.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<dynamic>(
                  value: _selectedSubordinate,
                  isExpanded: true,
                  hint: Text('View: My Own Plan',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade700)),
                  icon: const Icon(Icons.arrow_drop_down),
                  items: [
                    DropdownMenuItem<dynamic>(
                      value: null,
                      child: Text('My Own Plan',
                          style: GoogleFonts.poppins(fontSize: 13)),
                    ),
                    ..._subordinates.map((s) => DropdownMenuItem<dynamic>(
                          value: s,
                          child: Text(s['name']?.toString() ?? 'Unknown',
                              style: GoogleFonts.poppins(fontSize: 13)),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedSubordinate = val);
                    _fetchMonthlyPlans();
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color bg;
    Color fg;
    IconData icon;
    switch (_monthStatus) {
      case 'Approved':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        icon = Icons.check_circle_outline;
        break;
      case 'Pending':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        icon = Icons.hourglass_top_outlined;
        break;
      default:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        icon = Icons.cancel_outlined;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: fg, size: 16),
          const SizedBox(width: 6),
          Text('Status: ${_monthStatus.toUpperCase()}',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: fg, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTopStats() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          Expanded(
              child: _statCard('Days Planned', '$_daysPlanned',
                  Icons.event_available, Colors.blue)),
          const SizedBox(width: 8),
          Expanded(
              child: _statCard('Total Routes', '$_totalRoutesSelected',
                  Icons.map_outlined, Colors.orange)),
          const SizedBox(width: 8),
          Expanded(
              child: _statCard('Joint Work', '$_daysWithJointWork',
                  Icons.people_outline, Colors.teal)),
          const SizedBox(width: 8),
          Expanded(
              child: _statCard(
                  'Status',
                  _monthStatus,
                  Icons.edit_note,
                  _monthStatus == 'Approved'
                      ? Colors.green
                      : _monthStatus == 'Pending'
                          ? Colors.orange
                          : Colors.grey)),
        ],
      ),
    );
  }

  Widget _statCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color),
              overflow: TextOverflow.ellipsis),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 9, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
              maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildDayList(bool isMonthLocked, bool isManagerView) {
    return ListView.builder(
      padding:
          const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      itemCount: _monthData.length,
      itemBuilder: (context, idx) {
        final dayPlan = _monthData[idx];
        final isPreviousSaved =
            idx == 0 || _monthData[idx - 1].isSaved;
        final canEdit =
            !isMonthLocked && !isManagerView && isPreviousSaved;
        return _DayCard(
          dayPlan: dayPlan,
          canEdit: canEdit,
          allRoutes: _allRoutes,
          allJointWorks: _allJointWorkMembers, // /api/app/team/joint-work
          allWorkTypes: _allWorkTypes,
          primaryColor: _primary,
          onSave: () => _saveDay(dayPlan),
          onChanged: () => setState(() { dayPlan.isDirty = true; }),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Day Card
// ---------------------------------------------------------------------------
class _DayCard extends StatelessWidget {
  final DayPlanData dayPlan;
  final bool canEdit;
  final List<dynamic> allRoutes;
  final List<dynamic> allJointWorks;
  final List<dynamic> allWorkTypes;
  final Color primaryColor;
  final VoidCallback onSave;
  final VoidCallback onChanged;

  const _DayCard({
    required this.dayPlan,
    required this.canEdit,
    required this.allRoutes,
    required this.allJointWorks,
    required this.allWorkTypes,
    required this.primaryColor,
    required this.onSave,
    required this.onChanged,
  });
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(dayPlan.date, DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: dayPlan.isSaved
            ? Colors.green.shade50
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? primaryColor
              : dayPlan.isSaved
                  ? Colors.green.shade200
                  : Colors.grey.shade200,
          width: isToday ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _buildDateHeader(isToday),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    if (w > 800) {
                      // Desktop/Large Tablet: All in one line + save button
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _routeSelector(context)),
                          const SizedBox(width: 8),
                          Expanded(flex: 2, child: _jointWorkSelector(context)),
                          const SizedBox(width: 8),
                          Expanded(flex: 2, child: _workTypeSelector()),
                          const SizedBox(width: 8),
                          Expanded(flex: 2, child: _remarkField()),
                          const SizedBox(width: 12),
                          Expanded(flex: 1, child: _buildActionRow(context)),
                        ],
                      );
                    } else if (w > 480) {
                      // Tablet: 2x2 grid
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _routeSelector(context)),
                              const SizedBox(width: 8),
                              Expanded(child: _jointWorkSelector(context)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _workTypeSelector()),
                              const SizedBox(width: 8),
                              Expanded(child: _remarkField()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildActionRow(context),
                        ],
                      );
                    } else {
                      // Mobile: Stacked vertically
                      return Column(
                        children: [
                          _routeSelector(context),
                          const SizedBox(height: 8),
                          _jointWorkSelector(context),
                          const SizedBox(height: 8),
                          _workTypeSelector(),
                          const SizedBox(height: 8),
                          _remarkField(),
                          const SizedBox(height: 12),
                          _buildActionRow(context),
                        ],
                      );
                    }
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(bool isToday) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dayPlan.isSaved
            ? Colors.green.shade100
            : isToday
                ? primaryColor.withValues(alpha: 0.08)
                : Colors.grey.shade50,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday ? primaryColor : Colors.transparent,
              border: Border.all(
                  color: isToday
                      ? primaryColor
                      : Colors.grey.shade300),
            ),
            alignment: Alignment.center,
            child: Text(
              DateFormat('d').format(dayPlan.date),
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isToday ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE').format(dayPlan.date),
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(dayPlan.date),
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const Spacer(),
          if (dayPlan.isSaved)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check,
                      color: Colors.white, size: 12),
                  const SizedBox(width: 3),
                  Text('Saved',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else if (!canEdit)
            const Icon(Icons.lock_outline,
                color: Colors.grey, size: 18),
        ],
      ),
    );
  }

  Widget _routeSelector(BuildContext context) {
    final count = dayPlan.selectedRoutes.length;
    final label = count == 0
        ? 'Select Routes'
        : '$count Route${count > 1 ? 's' : ''} selected';
    final hasVal = count > 0;

    return _labelledField(
      label: 'Route',
      icon: Icons.map_outlined,
      iconColor: Colors.orange,
      child: InkWell(
        onTap: canEdit
            ? () => _showMultiSelectSheet(
                  context,
                  title: 'Select Routes',
                  allItems: allRoutes,
                  selectedItems: dayPlan.selectedRoutes,
                  displayKey: 'name',
                  idKey: 'id',
                  primaryColor: primaryColor,
                  displayBuilder: (item) {
                    final name = item['name']?.toString() ?? 'Unknown';
                    final drCount = item['dr_count'];
                    if (drCount != null) {
                      return '$name (Tagged doctor\'s: $drCount)';
                    }
                    return name;
                  },
                  onConfirm: (sel) {
                    dayPlan.selectedRoutes = sel;
                    onChanged();
                  },
                )
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: hasVal
                ? Colors.orange.withValues(alpha: 0.08)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: hasVal
                    ? Colors.orange.shade200
                    : Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: hasVal
                            ? Colors.orange.shade800
                            : Colors.grey.shade600,
                        fontWeight: hasVal
                            ? FontWeight.w600
                            : FontWeight.normal),
                    overflow: TextOverflow.ellipsis),
              ),
              Icon(Icons.keyboard_arrow_down,
                  size: 16,
                  color: hasVal
                      ? Colors.orange.shade600
                      : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jointWorkSelector(BuildContext context) {
    final count = dayPlan.selectedJointWorks.length;
    final label = count == 0
        ? 'Select Joint Work'
        : '$count Member${count > 1 ? 's' : ''} selected';
    final hasVal = count > 0;

    return _labelledField(
      label: 'Joint Work',
      icon: Icons.people_outline,
      iconColor: Colors.teal,
      child: InkWell(
        onTap: canEdit
            ? () => _showMultiSelectSheet(
                  context,
                  title: 'Select Joint Work',
                  allItems: allJointWorks,
                  selectedItems: dayPlan.selectedJointWorks,
                  displayKey: 'name',
                  idKey: 'id',
                  primaryColor: primaryColor,
                  onConfirm: (sel) {
                    dayPlan.selectedJointWorks = sel;
                    onChanged();
                  },
                )
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: hasVal
                ? Colors.teal.withValues(alpha: 0.08)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: hasVal
                    ? Colors.teal.shade200
                    : Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: hasVal
                            ? Colors.teal.shade800
                            : Colors.grey.shade600,
                        fontWeight: hasVal
                            ? FontWeight.w600
                            : FontWeight.normal),
                    overflow: TextOverflow.ellipsis),
              ),
              Icon(Icons.keyboard_arrow_down,
                  size: 16,
                  color: hasVal
                      ? Colors.teal.shade600
                      : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _workTypeSelector() {
    return _labelledField(
      label: 'Work Type',
      icon: Icons.work_outline,
      iconColor: AppColors.primary,
      child: IgnorePointer(
        ignoring: !canEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: dayPlan.selectedWorkType != null
                ? AppColors.primary.withValues(alpha: 0.06)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: dayPlan.selectedWorkType != null
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.grey.shade300,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<dynamic>(
              value: dayPlan.selectedWorkType,
              isExpanded: true,
              hint: Text('Select Work Type',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade600)),
              icon: const Icon(Icons.keyboard_arrow_down, size: 16),
              items: allWorkTypes
                  .map((wt) => DropdownMenuItem<dynamic>(
                        value: wt,
                        child: Text(wt['name']?.toString() ?? '',
                            style: GoogleFonts.poppins(fontSize: 12)),
                      ))
                  .toList(),
              onChanged: (val) {
                dayPlan.selectedWorkType = val;
                onChanged();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _remarkField() {
    return _labelledField(
      label: 'Remark',
      icon: Icons.notes_outlined,
      iconColor: Colors.grey.shade600,
      child: TextField(
        controller: dayPlan.remarkController,
        enabled: canEdit,
        maxLines: 1,
        style: GoogleFonts.poppins(fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Optional remark...',
          hintStyle: GoogleFonts.poppins(
              fontSize: 12, color: Colors.grey.shade500),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 9),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: Colors.grey.shade300)),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.primary)),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }

  Widget _labelledField({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildActionRow(BuildContext context) {
    if (dayPlan.isSaving) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.primary))));
    }

    // Locked view (not editable)
    if (!canEdit) {
      if (dayPlan.isSaved) {
        return Row(children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 6),
          Text('Plan saved',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
        ]);
      } else {
        return Row(children: [
          Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 16),
          const SizedBox(width: 6),
          Text('Save previous day first',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
        ]);
      }
    }

    // Editable view
    if (dayPlan.isSaved && !dayPlan.isDirty) {
      // Saved, no changes yet -> hide save button, show saved status
      return Row(children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 18),
        const SizedBox(width: 6),
        Text('Plan saved (tap any field to edit)',
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
      ]);
    }

    // Unsaved OR dirty -> show Save button
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onSave,
        icon: const Icon(Icons.save_outlined, size: 16),
        label: Text(
          'Save Day',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _showMultiSelectSheet(
    BuildContext context, {
    required String title,
    required List<dynamic> allItems,
    required List<dynamic> selectedItems,
    required String displayKey,
    required String idKey,
    required Color primaryColor,
    required ValueChanged<List<dynamic>> onConfirm,
    String Function(dynamic)? displayBuilder,
  }) {
    List<dynamic> tempSelected = List.from(selectedItems);
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (sheetCtx, setSheet) {
          final filteredItems = allItems.where((item) {
            final val = displayBuilder != null 
                ? displayBuilder(item).toLowerCase() 
                : (item[displayKey]?.toString().toLowerCase() ?? '');
            return val.contains(searchQuery.toLowerCase());
          }).toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.85,
            minChildSize: 0.35,
            builder: (_, scrollController) {
              return Column(children: [
                Container(
                  width: 36,
                  height: 4,
                  margin:
                      const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    onChanged: (val) {
                      setSheet(() {
                        searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16),
                  child: Row(children: [
                    Text('${tempSelected.length} selected',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: primaryColor,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (tempSelected.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            setSheet(() => tempSelected = []),
                        child: Text('Clear all',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.red)),
                      ),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Text('No options available',
                              style: GoogleFonts.poppins(
                                  color:
                                      Colors.grey.shade500)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: filteredItems.length,
                          itemBuilder: (_, index) {
                            final item = filteredItems[index];
                            final name = displayBuilder != null
                                ? displayBuilder(item)
                                : (item[displayKey]?.toString() ?? 'Unknown');
                            final isChecked = tempSelected.any(
                                (s) =>
                                    s[idKey]?.toString() ==
                                    item[idKey]?.toString());
                            return CheckboxListTile(
                              value: isChecked,
                              activeColor: primaryColor,
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              title: Text(name, style: GoogleFonts.poppins(fontSize: 13)),
                              subtitle: item['dr_count'] != null
                                  ? Text("Tagged Doctor's: ${item['dr_count']}",
                                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600))
                                  : null,
                              onChanged: (val) {
                                setSheet(() {
                                  if (val == true) {
                                    tempSelected.add(item);
                                  } else {
                                    tempSelected.removeWhere(
                                        (s) =>
                                            s[idKey]
                                                ?.toString() ==
                                            item[idKey]
                                                ?.toString());
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        onConfirm(tempSelected);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Confirm  (${tempSelected.length})',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ]);
            },
          );
        });
      },
    );
  }
}
