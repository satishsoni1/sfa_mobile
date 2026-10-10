import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/api_service.dart';


class BrandDrMappingDoctorScreen extends StatefulWidget {
  final Map<String, dynamic> brand;
  final int? targetUserId;
  final bool readOnly;
  final bool isDoctorListLocked;
  const BrandDrMappingDoctorScreen({
    super.key,
    required this.brand,
    this.targetUserId,
    this.readOnly = false,
    this.isDoctorListLocked = false,
  });

  @override
  State<BrandDrMappingDoctorScreen> createState() => _BrandDrMappingDoctorScreenState();
}

class ZorberryWeek {
  final int weekNumber;
  final String label;
  final String dateRange;
  final DateTime startDate;
  final DateTime endDate;

  const ZorberryWeek({
    required this.weekNumber,
    required this.label,
    required this.dateRange,
    required this.startDate,
    required this.endDate,
  });

  String get startDateStr =>
      '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
  String get endDateStr =>
      '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

  bool isFuture([DateTime? now]) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return today.isBefore(start);
  }

  bool isCurrent([DateTime? now]) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !today.isBefore(start) && !today.isAfter(end);
  }

  bool isPast([DateTime? now]) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return today.isAfter(end);
  }
}

class _BrandDrMappingDoctorScreenState extends State<BrandDrMappingDoctorScreen> {
  static const _purple = Color(0xFF4A148C);

  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = true;
  String _selectedSpeciality = 'All';

  // Dynamic Weeks generation (52 weeks)
  static List<ZorberryWeek> _generateWeeks({int count = 52}) {
    final List<ZorberryWeek> list = [];
    DateTime currentStart = DateTime(2026, 10, 4); // Campaign start (Monday / Week 1)
    for (int i = 1; i <= count; i++) {
      DateTime currentEnd = currentStart.add(const Duration(days: 6));
      final startStr = '${currentStart.day}';
      final endStr = '${currentEnd.day} ${_monthName(currentEnd.month)}';
      list.add(ZorberryWeek(
        weekNumber: i,
        label: 'Week $i',
        dateRange: currentStart.month == currentEnd.month
            ? '$startStr to $endStr'
            : '$startStr ${_monthName(currentStart.month)} to $endStr',
        startDate: currentStart,
        endDate: currentEnd,
      ));
      currentStart = currentStart.add(const Duration(days: 7));
    }
    return list;
  }

  static String _monthName(int m) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (m >= 1 && m <= 12) ? months[m] : '';
  }

  late final List<ZorberryWeek> _weeks = _generateWeeks(count: 52);
  int _selectedWeekIndex = 0;
  ZorberryWeek get _currentWeek => _weeks[_selectedWeekIndex];

  final Map<String, int> _weeklyQuantities = {};
  final Set<int> _submittedWeeks = {};
  bool _isSubmittingWeekly = false;
  bool _isWeekLoading = false;

  // Controllers per doctor for the active week input
  final Map<int, TextEditingController> _controllers = {};

  bool get _isBrandApproved {
    final raw = widget.brand['approval_status'] ??
        widget.brand['brand_approval_status'] ??
        widget.brand['status'];
    return raw?.toString().toLowerCase().trim() == 'approved';
  }

  bool get _isCurrentWeekSubmitted => _submittedWeeks.contains(_currentWeek.weekNumber);
  bool get _isCurrentWeekFuture => _currentWeek.isFuture();
  bool get _isCurrentWeekLocked =>
      !_isBrandApproved || _isCurrentWeekFuture || _isCurrentWeekSubmitted || widget.readOnly;

  int get _brandId => int.tryParse(widget.brand['id']?.toString() ?? '0') ?? 0;
  // Read brand name from 'brand' field first (dr-brand-map shape), fallback to 'name'
  String get _brandName => (widget.brand['brand'] ?? widget.brand['name'])?.toString() ?? '';
  int get _quota => int.tryParse(widget.brand['quota']?.toString() ?? '0') ?? 0;
  // quota is the MINIMUM — show quota-full badge only when count >= quota
  bool get _isQuotaMet => _quota > 0 && _doctors.length >= _quota;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    int initialIndex = 0;
    for (int i = 0; i < _weeks.length; i++) {
      if (_weeks[i].isCurrent(now)) {
        initialIndex = i;
        break;
      } else if (!_weeks[i].isFuture(now)) {
        initialIndex = i;
      }
    }
    _selectedWeekIndex = initialIndex;
    _load();
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _syncControllersForCurrentWeek() {
    final isLocked = _isCurrentWeekLocked;
    for (final d in _doctors) {
      final id = int.tryParse(d['id']?.toString() ?? '0') ?? 0;
      if (id > 0) {
        final key = '${_currentWeek.weekNumber}_$id';
        final qty = _weeklyQuantities[key] ?? 0;
        final textVal = qty > 0 ? '$qty' : (isLocked ? '0' : '');
        final ctrl = _controllers.putIfAbsent(id, () => TextEditingController());
        ctrl.text = textVal;
      }
    }
  }

  int _calculateWeekTotal(int weekNumber) {
    int total = 0;
    for (final d in _doctors) {
      final id = int.tryParse(d['id']?.toString() ?? '0') ?? 0;
      if (id > 0) {
        total += (_weeklyQuantities['${weekNumber}_$id'] ?? 0);
      }
    }
    return total;
  }

  Future<void> _fetchWeeklyRxnForWeek(ZorberryWeek week) async {
    setState(() => _isWeekLoading = true);
    try {
      final res = await ApiService().getDrBrandMapWeeklyRxn(
        _brandId,
        weekStart: week.startDateStr,
        weekEnd: week.endDateStr,
        weekNumber: week.weekNumber,
        userId: widget.targetUserId,
      );

      if (!mounted) return;

      dynamic target = res['data'] ?? res;
      if (target is List) {
        final match = target.firstWhere(
          (item) => (int.tryParse(item['week_number']?.toString() ?? '0') ?? 0) == week.weekNumber,
          orElse: () => target.isNotEmpty ? target.first : null,
        );
        target = match;
      }

      if (target is Map<String, dynamic> || target is Map) {
        final isSub = target['is_submitted'] == true ||
            target['is_submitted'] == 1 ||
            target['is_submitted']?.toString() == '1' ||
            target['is_submitted']?.toString().toLowerCase() == 'true';

        setState(() {
          if (isSub) {
            _submittedWeeks.add(week.weekNumber);
          } else {
            _submittedWeeks.remove(week.weekNumber);
          }

          final entries = target['entries'] ?? target['doctors'] ?? target['data'];
          if (entries is List) {
            for (final e in entries) {
              final dId = int.tryParse(e['doctor_id']?.toString() ?? e['id']?.toString() ?? '0') ?? 0;
              final qty = int.tryParse(e['quantity']?.toString() ?? e['rxn_qty']?.toString() ?? '0') ?? 0;
              if (dId > 0) {
                _weeklyQuantities['${week.weekNumber}_$dId'] = qty;
              }
            }
          }
        });
      }
    } catch (_) {
      // Safe fallback
    } finally {
      if (mounted) {
        setState(() {
          _isWeekLoading = false;
          _syncControllersForCurrentWeek();
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().getDrBrandMapDoctors(_brandId, userId: widget.targetUserId);
      if (mounted) {
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      }

      await _fetchWeeklyRxnForWeek(_currentWeek);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _specialities {
    final set = <String>{'All'};
    for (final d in _doctors) {
      final sp = d['specialty_practice_type']?.toString() ?? '';
      if (sp.isNotEmpty) set.add(sp);
    }
    return set.toList();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedSpeciality == 'All') return _doctors;
    return _doctors
        .where((d) => d['specialty_practice_type']?.toString() == _selectedSpeciality)
        .toList();
  }

  Map<String, int> get _summary {
    final map = <String, int>{};
    for (final d in _doctors) {
      final sp = d['specialty_practice_type']?.toString() ?? 'Unknown';
      map[sp] = (map[sp] ?? 0) + 1;
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Future<void> _removeDoctor(int doctorId) async {
    if (widget.readOnly) return;
    try {
      final msg = await ApiService().removeDrBrandMapDoctor(_brandId, doctorId);
      setState(() => _doctors.removeWhere(
          (d) => int.tryParse(d['id']?.toString() ?? '0') == doctorId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _openAddSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DrBrandMapAddDoctorSheet(
        brandId: _brandId,
        quotaRemaining: _quota > 0 ? (_quota - _doctors.length) : null,
        alreadyAdded: _doctors
            .map((d) => int.tryParse(d['id']?.toString() ?? '0') ?? 0)
            .toSet(),
      ),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(
          _brandName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${_doctors.length} Drs',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
        ],
      ),
      floatingActionButton: (widget.readOnly || widget.isDoctorListLocked)
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddSheet,
              backgroundColor: _purple,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Add Doctor',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Quota progress bar
                if (_quota > 0)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isQuotaMet ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isQuotaMet ? Colors.green.shade200 : Colors.orange.shade200,
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        _isQuotaMet ? Icons.check_circle_outline : Icons.track_changes,
                        color: _isQuotaMet ? Colors.green.shade700 : Colors.orange.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isQuotaMet
                              ? 'quota met (${_doctors.length}/$_quota) — ready to submit'
                              : '${_doctors.length}/$_quota doctors added ( $_quota required)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _isQuotaMet ? Colors.green.shade800 : Colors.orange.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                // Brand approval lock banner
                if (!_isBrandApproved)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(children: [
                      Icon(Icons.lock_outline, color: Colors.amber.shade800, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Weekly Rxn is locked until your doctor list is approved by your manager.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                // Horizontal week-wise calendar above
                _buildWeekCalendar(),
                if (_isWeekLoading)
                  const LinearProgressIndicator(
                    minHeight: 2.5,
                    color: _purple,
                    backgroundColor: Color(0xFFEDE7F6),
                  ),
                // Speciality filter chips
                if (_specialities.length > 1)
                  Container(
                    height: 48,
                    color: Colors.white,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      children: _specialities.map((sp) {
                        final sel = _selectedSpeciality == sp;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedSpeciality = sp),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: sel ? _purple : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: sel ? _purple : Colors.grey.shade300),
                              ),
                              child: Text(sp,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: sel ? Colors.white : Colors.grey.shade700)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                // Doctor list
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_search, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                _doctors.isEmpty
                                    ? 'No doctors added yet'
                                    : 'No doctors in this speciality',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                            itemCount: _filtered.length + 1,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              if (i == _filtered.length) return _buildSummaryCard();
                              return _buildDoctorCard(_filtered[i]);
                            },
                          ),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _buildWeeklySubmitBar(),
    );
  }

  Widget _buildWeekCalendar() {
    return Container(
      height: 66,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _weeks.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final w = _weeks[i];
          final isSelected = i == _selectedWeekIndex;
          final isSubmitted = _submittedWeeks.contains(w.weekNumber);
          final isFuture = w.isFuture();
          final isWeekLocked = !_isBrandApproved || isFuture;

          return GestureDetector(
            onTap: () {
              if (!_isBrandApproved) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Weekly Rxn is locked until your doctor list is approved by your manager.'),
                  duration: Duration(seconds: 2),
                ));
                return;
              }
              if (isFuture) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${w.label} is locked and will automatically unlock on ${w.dateRange.split(' to ').first}'),
                  duration: const Duration(seconds: 2),
                ));
                return;
              }
              if (_selectedWeekIndex != i) {
                setState(() {
                  _selectedWeekIndex = i;
                  _syncControllersForCurrentWeek();
                });
                _fetchWeeklyRxnForWeek(_weeks[i]);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isWeekLocked
                    ? Colors.grey.shade100
                    : isSelected
                        ? _purple
                        : isSubmitted
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isWeekLocked
                      ? Colors.grey.shade300
                      : isSelected
                          ? _purple
                          : isSubmitted
                              ? Colors.green.shade400
                              : Colors.grey.shade300,
                  width: isSelected && !isWeekLocked ? 1.5 : 1.0,
                ),
                boxShadow: (isSelected && !isWeekLocked)
                    ? [
                        BoxShadow(
                          color: _purple.withValues(alpha: 0.25),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        w.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isWeekLocked
                              ? Colors.grey.shade400
                              : isSelected
                                  ? Colors.white
                                  : isSubmitted
                                      ? Colors.green.shade800
                                      : Colors.black87,
                        ),
                      ),
                      if (isSubmitted && _isBrandApproved) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.check_circle,
                          size: 13,
                          color: isSelected
                              ? Colors.white
                              : Colors.green.shade700,
                        ),
                      ] else if (isWeekLocked) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.lock_outline,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    w.dateRange,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isWeekLocked
                          ? Colors.grey.shade400
                          : isSelected
                              ? Colors.white.withValues(alpha: 0.85)
                              : Colors.grey.shade600,
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

  Widget _buildQtyStepper(int id) {
    final key = '${_currentWeek.weekNumber}_$id';
    final qty = _weeklyQuantities[key] ?? 0;
    final isLocked = _isCurrentWeekLocked;
    final ctrl = _controllers.putIfAbsent(id, () {
      return TextEditingController(text: qty > 0 ? '$qty' : (isLocked ? '0' : ''));
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'QTY',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: isLocked ? Colors.grey.shade500 : _purple,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 30,
          decoration: BoxDecoration(
            color: isLocked ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isLocked ? Colors.grey.shade300 : _purple.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Minus button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                  onTap: (isLocked || qty <= 0)
                      ? null
                      : () {
                          final newQty = (qty - 1).clamp(0, 9999);
                          _weeklyQuantities[key] = newQty;
                          ctrl.text = newQty > 0 ? '$newQty' : '';
                          ctrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: ctrl.text.length),
                          );
                          setState(() {});
                        },
                  child: Container(
                    width: 24,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (isLocked || qty <= 0)
                          ? Colors.transparent
                          : _purple.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                    ),
                    child: Icon(
                      Icons.remove,
                      size: 14,
                      color: (isLocked || qty <= 0) ? Colors.grey.shade400 : _purple,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 16,
                color: isLocked ? Colors.grey.shade300 : _purple.withValues(alpha: 0.2),
              ),
              // Editable Text Field
              SizedBox(
                width: 30,
                child: TextField(
                  controller: ctrl,
                  enabled: !isLocked,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isLocked ? Colors.grey.shade700 : _purple,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: isLocked ? Colors.grey.shade400 : _purple.withValues(alpha: 0.35),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val.trim()) ?? 0;
                    _weeklyQuantities[key] = parsed < 0 ? 0 : parsed;
                    setState(() {});
                  },
                ),
              ),
              Container(
                width: 1,
                height: 16,
                color: isLocked ? Colors.grey.shade300 : _purple.withValues(alpha: 0.2),
              ),
              // Plus button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                  onTap: isLocked
                      ? null
                      : () {
                          final newQty = (qty + 1).clamp(0, 9999);
                          _weeklyQuantities[key] = newQty;
                          ctrl.text = '$newQty';
                          ctrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: ctrl.text.length),
                          );
                          setState(() {});
                        },
                  child: Container(
                    width: 24,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isLocked
                          ? Colors.transparent
                          : _purple.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 14,
                      color: isLocked ? Colors.grey.shade400 : _purple,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklySubmitBar() {
    if (_doctors.isEmpty) return const SizedBox.shrink();

    final isFuture = _isCurrentWeekFuture;
    final isSubmitted = _isCurrentWeekSubmitted;
    final totalRxn = _calculateWeekTotal(_currentWeek.weekNumber);
    final isDisabled = !_isBrandApproved || isFuture || isSubmitted || widget.readOnly || _isSubmittingWeekly;

    Color buttonColor;
    if (!_isBrandApproved) {
      buttonColor = Colors.grey.shade400;
    } else if (isSubmitted) {
      buttonColor = Colors.green.shade700;
    } else if (isFuture) {
      buttonColor = Colors.grey.shade400;
    } else {
      buttonColor = _purple;
    }

    String buttonLabel;
    IconData buttonIcon;
    if (!_isBrandApproved) {
      buttonLabel = 'Doctor List Not Approved (Weekly Rxn Locked)';
      buttonIcon = Icons.lock_outline;
    } else if (isSubmitted) {
      buttonLabel = '${_currentWeek.label} Submitted ($totalRxn Rxns)';
      buttonIcon = Icons.check_circle;
    } else if (isFuture) {
      buttonLabel = '${_currentWeek.label} Locked (Starts ${_currentWeek.dateRange.split(' to ').first})';
      buttonIcon = Icons.lock_outline;
    } else {
      buttonLabel = 'Submit ${_currentWeek.label} Rxn ($totalRxn Total)';
      buttonIcon = Icons.send_outlined;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: (!_isBrandApproved || isSubmitted || isFuture) ? 0 : 2,
            ),
            onPressed: isDisabled ? null : _submitCurrentWeek,
            icon: _isSubmittingWeekly
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(buttonIcon, size: 18),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                buttonLabel,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5),
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitCurrentWeek() async {
    if (_isCurrentWeekLocked) return;
    final week = _currentWeek;
    final totalRxn = _calculateWeekTotal(week.weekNumber);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.send_outlined, color: _purple),
            const SizedBox(width: 10),
            Text('Submit ${week.label} Rxn?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dates: ${week.dateRange}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Total Prescriptions: $totalRxn', style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmittingWeekly = true);
    try {
      final List<Map<String, dynamic>> entries = [];
      for (final d in _doctors) {
        final id = int.tryParse(d['id']?.toString() ?? '0') ?? 0;
        if (id > 0) {
          final qty = _weeklyQuantities['${week.weekNumber}_$id'] ?? 0;
          entries.add({
            'doctor_id': id,
            'quantity': qty,
          });
        }
      }

      final payload = {
        'brand_id': _brandId,
        'week_number': week.weekNumber,
        'week_start': week.startDateStr,
        'week_end': week.endDateStr,
        'total_quantity': totalRxn,
        'entries': entries,
      };

      await ApiService().submitDrBrandMapWeeklyRxn(_brandId, payload);

      if (mounted) {
        setState(() {
          _submittedWeeks.add(week.weekNumber);
          _syncControllersForCurrentWeek();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${week.label} Rxns submitted successfully!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMsg.isNotEmpty ? errorMsg : 'Failed to submit weekly Rxns'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmittingWeekly = false);
    }
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    final name = doctor['doctor_name']?.toString() ?? '';
    final sp = doctor['specialty_practice_type']?.toString() ?? '';
    final area = doctor['area']?.toString() ?? '';
    final id = int.tryParse(doctor['id']?.toString() ?? '0') ?? 0;
    final isPathfinder = doctor['is_pathfinder'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPathfinder ? Colors.orange.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Left side: Doctor avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isPathfinder
                  ? Colors.orange.shade50
                  : const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.person,
                color: isPathfinder ? Colors.orange.shade700 : _purple,
                size: 20),
          ),
          const SizedBox(width: 8),
          // Center: Doctor information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPathfinder) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: const Text(
                          'Pathfinder',
                          style: TextStyle(
                            fontSize: 8.5,
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (sp.isNotEmpty) ...[
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE7F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            sp,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: _purple,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (area.isNotEmpty)
                      Expanded(
                        child: Text(
                          area,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Right side: QTY Stepper (- [qty] +) with manual entry
          _buildQtyStepper(id),
          if (!widget.readOnly && !widget.isDoctorListLocked) ...[
            const SizedBox(width: 2),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _confirmRemove(id, name),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.remove_circle_outline,
                    color: Colors.red, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmRemove(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Doctor'),
        content: Text('Remove $name from $_brandName?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _removeDoctor(id);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final s = _summary;
    if (s.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Speciality Summary',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 10),
          ...s.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.key,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE7F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${e.value}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _purple,
                              fontSize: 12)),
                    ),
                  ],
                ),
              )),
          const Divider(height: 16),
          Row(
            children: [
              const Expanded(
                  child: Text('Total',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Text('${_doctors.length}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _purple)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Add Doctor Bottom Sheet (Dr-Brand-Map version) ───────────────────────────

class _DrBrandMapAddDoctorSheet extends StatefulWidget {
  final int brandId;
  final int? quotaRemaining;
  final Set<int> alreadyAdded;
  const _DrBrandMapAddDoctorSheet({
    required this.brandId,
    required this.alreadyAdded,
    required this.quotaRemaining,
  });

  @override
  State<_DrBrandMapAddDoctorSheet> createState() => _DrBrandMapAddDoctorSheetState();
}

class _DrBrandMapAddDoctorSheetState extends State<_DrBrandMapAddDoctorSheet> {
  static const _purple = Color(0xFF4A148C);

  List<Map<String, dynamic>> _allDoctors = [];
  List<Map<String, dynamic>> _filtered = [];
  final Set<int> _selected = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _apiError;
  final _searchCtrl = TextEditingController();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _apiError = null;
    });
    try {
      final docs = await ApiService().getDrBrandMapDoctorList(brandId: widget.brandId);
      if (!mounted) return;

      if (docs.length == 1 && docs.first['__error__'] == true) {
        setState(() {
          _apiError = docs.first['message']?.toString() ?? 'Failed to load doctors';
        });
        return;
      }

      if (mounted) {
        // Filter out already-added doctors
        final available = docs
            .where((d) => !widget.alreadyAdded
                .contains(int.tryParse(d['id']?.toString() ?? '0') ?? 0))
            .toList();

        // Sort: Brand Pathfinder doctors come first, rest follow
        available.sort((a, b) {
          final aP = a['is_pathfinder'] == true ? 0 : 1;
          final bP = b['is_pathfinder'] == true ? 0 : 1;
          return aP.compareTo(bP);
        });

        setState(() {
          _allDoctors = available;
          _filtered = _allDoctors;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      final base = q.isEmpty
          ? _allDoctors
          : _allDoctors
              .where((d) =>
                  (d['doctor_name'] ?? '').toString().toLowerCase().contains(q) ||
                  (d['specialty_practice_type'] ?? '').toString().toLowerCase().contains(q) ||
                  (d['area'] ?? '').toString().toLowerCase().contains(q))
              .toList();
      // Keep pathfinder doctors at the top even after filtering
      _filtered = [
        ...base.where((d) => d['is_pathfinder'] == true),
        ...base.where((d) => d['is_pathfinder'] != true),
      ];
    });
  }

  Future<void> _save() async {
    if (_selected.isEmpty) return;
    if (widget.quotaRemaining != null && _selected.length > widget.quotaRemaining!) {
      _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text('You can add only ${widget.quotaRemaining} more doctor(s).'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ApiService().addDrBrandMapDoctors(widget.brandId, _selected.toList());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Text('Add Doctors',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const Spacer(),
                      if (_selected.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE7F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${_selected.length} selected',
                              style: const TextStyle(
                                  color: _purple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      if (widget.quotaRemaining != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${widget.quotaRemaining} left',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: Colors.grey.shade600, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                        tooltip: 'Cancel',
                      ),
                    ],
                  ),
                ),
                // Pathfinder legend hint
                if (!_isLoading && _apiError == null && _allDoctors.any((d) => d['is_pathfinder'] == true))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: const Text('Brand Pathfinder Doctor',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        Text('shown at top',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                
                if (_apiError != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: Colors.orange.shade600, size: 40),
                              const SizedBox(height: 12),
                              Text(
                                _apiError!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade800,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search by name, speciality, area...',
                        prefixIcon: const Icon(Icons.search, color: _purple),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _purple)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  // List
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filtered.isEmpty
                            ? Center(
                                child: Text('No doctors available',
                                    style: TextStyle(color: Colors.grey.shade400)))
                          : ListView.separated(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              itemCount: _filtered.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final doc = _filtered[i];
                                final id = int.tryParse(doc['id']?.toString() ?? '0') ?? 0;
                                final name = doc['doctor_name']?.toString() ?? '';
                                final sp = doc['specialty_practice_type']?.toString() ?? '';
                                final area = doc['area']?.toString() ?? '';
                                final sel = _selected.contains(id);
                                final isPathfinder = doc['is_pathfinder'] == true;

                                return CheckboxListTile(
                                  value: sel,
                                  activeColor: _purple,
                                  onChanged: (v) {
                                    if (v == true &&
                                        widget.quotaRemaining != null &&
                                        _selected.length >= widget.quotaRemaining!) {
                                      _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
                                        content: Text(
                                            'Quota allows only ${widget.quotaRemaining} more doctor(s).'),
                                        backgroundColor: Colors.orange,
                                      ));
                                      return;
                                    }
                                    setState(() {
                                      if (v == true) {
                                        _selected.add(id);
                                      } else {
                                        _selected.remove(id);
                                      }
                                    });
                                  },
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(name,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500)),
                                      ),
                                      if (isPathfinder) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                                color: Colors.orange.shade300),
                                          ),
                                          child: const Text(
                                            'Brand Pathfinder Doctor',
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.deepOrange,
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                      '$sp${area.isNotEmpty ? ' • $area' : ''}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500)),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                );
                              },
                            ),
                  ),
                ],
                // Save button
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selected.isEmpty || _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              _selected.isEmpty
                                  ? 'Select doctors to add'
                                  : 'Add ${_selected.length} Doctor${_selected.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
