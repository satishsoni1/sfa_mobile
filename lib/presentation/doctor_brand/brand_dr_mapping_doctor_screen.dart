import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/api_service.dart';
import 'sobixo_verification_sheet.dart';


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

  bool get _isSobixo {
    final b = widget.brand;
    final name = (b['brand'] ?? b['name'])?.toString().toUpperCase() ?? '';
    return b['is_sobixo'] == true || name == 'SOBIXO';
  }

  String? get _brandStatus {
    final raw = widget.brand['approval_status'] ??
        widget.brand['brand_approval_status'] ??
        widget.brand['status'];
    final s = raw?.toString().toLowerCase().trim();
    if (s == null || s.isEmpty || s == 'null' || int.tryParse(s) != null) {
      return null;
    }
    return s;
  }

  bool _isStatusApproved(String? s) => s == 'approved';

  bool _isStatusPendingOrSubmitted(String? s) {
    if (s == null) return false;
    return s == 'pending' ||
        s == 'submitted' ||
        s.contains('pending') ||
        s.contains('review') ||
        s.contains('submit');
  }

  bool _isStatusRejected(String? s) => s == 'rejected';

  String? get _sobixoEffectiveStatus {
    final status = _brandStatus;
    if (status != null) return status;

    for (final doc in _doctors) {
      final docStatus = (doc['approval_status'] ?? doc['brand_approval_status'])
          ?.toString()
          .toLowerCase()
          .trim();
      if (docStatus != null &&
          docStatus.isNotEmpty &&
          docStatus != 'null' &&
          int.tryParse(docStatus) == null) {
        return docStatus;
      }
    }
    return null;
  }

  bool get _isSobixoSubmittedOrLocked {
    if (!_isSobixo) return false;
    if (widget.readOnly || widget.isDoctorListLocked) return true;

    final status = _sobixoEffectiveStatus;
    if (_isStatusApproved(status) || _isStatusPendingOrSubmitted(status)) {
      return true;
    }

    for (final doc in _doctors) {
      final docStatus = (doc['approval_status'] ?? doc['brand_approval_status'])
          ?.toString()
          .toLowerCase()
          .trim();
      if (_isStatusApproved(docStatus) ||
          _isStatusPendingOrSubmitted(docStatus)) {
        return true;
      }
    }

    return false;
  }

  String? get _rejectionReason {
    return (widget.brand['rejection_reason'] ?? widget.brand['reject_reason'])
        ?.toString();
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

  Future<void> _load({bool clearLocalSobixo = false}) async {
    setState(() => _isLoading = true);
    final List<Map<String, dynamic>> localDrafts = clearLocalSobixo
        ? <Map<String, dynamic>>[]
        : _doctors.where((d) => d['__local_only'] == true).toList();
    try {
      final Map<String, dynamic> data;
      if (_isSobixo) {
        data = await ApiService().getSobixoDoctors(_brandId, userId: widget.targetUserId);
      } else {
        data = await ApiService().getDrBrandMapDoctors(_brandId, userId: widget.targetUserId);
      }
      if (mounted) {
        setState(() {
          final backendDocs = List<Map<String, dynamic>>.from(data['data'] ?? []);
          if (_isSobixo) {
            final respStatus = (data['approval_status'] ??
                    data['brand_approval_status'])
                ?.toString()
                .trim();
            if (respStatus != null &&
                respStatus.isNotEmpty &&
                respStatus.toLowerCase() != 'null' &&
                int.tryParse(respStatus) == null) {
              widget.brand['approval_status'] = respStatus;
            } else if (backendDocs.isNotEmpty) {
              for (final doc in backendDocs) {
                final docStatus = (doc['approval_status'] ??
                        doc['brand_approval_status'])
                    ?.toString()
                    .trim();
                if (docStatus != null &&
                    docStatus.isNotEmpty &&
                    docStatus.toLowerCase() != 'null' &&
                    int.tryParse(docStatus) == null) {
                  widget.brand['approval_status'] = docStatus;
                  break;
                }
              }
            }

            final backendIds = backendDocs
                .map((d) => int.tryParse(d['id']?.toString() ?? '0') ?? 0)
                .toSet();
            final effectiveStatus = _sobixoEffectiveStatus;
            final bool alreadySubmitted = _isStatusApproved(effectiveStatus) ||
                _isStatusPendingOrSubmitted(effectiveStatus);

            if (!clearLocalSobixo && !alreadySubmitted && localDrafts.isNotEmpty) {
              for (final ld in localDrafts) {
                final lid = int.tryParse(ld['id']?.toString() ?? '0') ?? 0;
                if (lid > 0 && !backendIds.contains(lid) && backendDocs.length < 3) {
                  backendDocs.add(ld);
                  backendIds.add(lid);
                }
              }
            }
          }
          _doctors = backendDocs;
        });
      }

      if (!_isSobixo) {
        await _fetchWeeklyRxnForWeek(_currentWeek);
      }
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
    if (widget.readOnly || _isSobixoSubmittedOrLocked) return;
    if (_isSobixo) {
      final localIdx = _doctors.indexWhere(
          (d) => int.tryParse(d['id']?.toString() ?? '0') == doctorId);
      if (localIdx != -1 && _doctors[localIdx]['__local_only'] == true) {
        setState(() => _doctors.removeAt(localIdx));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Doctor removed from selection'),
            backgroundColor: Colors.green,
          ));
        }
        return;
      }
    }
    try {
      final String msg;
      if (_isSobixo) {
        msg = await ApiService().removeSobixoDoctor(_brandId, doctorId);
      } else {
        msg = await ApiService().removeDrBrandMapDoctor(_brandId, doctorId);
      }
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
    if (_isSobixoSubmittedOrLocked) return;
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DrBrandMapAddDoctorSheet(
        brandId: _brandId,
        isSobixo: _isSobixo,
        quotaRemaining: _quota > 0 ? (_quota - _doctors.length) : null,
        alreadyAdded: _doctors
            .map((d) => int.tryParse(d['id']?.toString() ?? '0') ?? 0)
            .toSet(),
      ),
    );
    if (_isSobixo && result is List) {
      final newDocs = result
          .whereType<Map>()
          .map((d) => Map<String, dynamic>.from(d))
          .toList();
      if (newDocs.isNotEmpty) {
        setState(() {
          final existingIds = _doctors
              .map((d) => int.tryParse(d['id']?.toString() ?? '0') ?? 0)
              .toSet();
          for (final d in newDocs) {
            final id = int.tryParse(d['id']?.toString() ?? '0') ?? 0;
            if (id > 0 && !existingIds.contains(id) && _doctors.length < 3) {
              _doctors.add(d);
              existingIds.add(id);
            }
          }
        });
        if (_doctors.length == 3 && !_isSobixoSubmittedOrLocked) {
          _openSobixoVerificationSheet();
        }
      }
    } else if (result == true) {
      await _load();
    }
  }

  Future<void> _openSobixoVerificationSheet({
    int? initialDoctorId,
    int initialIndex = 0,
  }) async {
    if (_isSobixoSubmittedOrLocked) return;
    if (_doctors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one doctor first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final verified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SobixoVerificationSheet(
        brandId: _brandId,
        brandName: _brandName,
        selectedDoctors: _doctors,
        initialDoctorId: initialDoctorId,
        initialDoctorIndex: initialIndex,
        onLocalUpdate: (updatedList) {
          if (!mounted) return;
          setState(() {
            for (final upd in updatedList) {
              final uid = upd['doctor_id'];
              final idx = _doctors.indexWhere(
                  (d) => (int.tryParse(d['id']?.toString() ?? '0') ?? 0) == uid);
              if (idx != -1) {
                final docMap = _doctors[idx];
                docMap['first_name'] = upd['first_name'];
                docMap['surname'] = upd['surname'];
                docMap['doctor_name'] = upd['doctor_name'];
                docMap['mobile'] = upd['mobile'];
                docMap['phone'] = upd['mobile'];
                docMap['email'] = upd['email'];
                if (docMap['has_changes'] == true && docMap['changes'] is List) {
                  for (final ch in (docMap['changes'] as List)) {
                    if (ch is Map) {
                      final f = ch['field']?.toString().trim() ?? '';
                      if (upd.containsKey(f)) {
                        ch['new_value'] = upd[f]?.toString() ?? '';
                      }
                    }
                  }
                }
              }
            }
          });
        },
      ),
    );

    if (verified == true) {
      setState(() {
        widget.brand['approval_status'] = 'pending';
        widget.brand['status'] = 'pending';
      });
      await _load(clearLocalSobixo: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          _isSobixo ? 'SOBIXO Special 3' : _brandName,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isSobixo
                    ? '${_doctors.length}/3 Drs'
                    : '${_doctors.length} Drs',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: (widget.readOnly ||
              widget.isDoctorListLocked ||
              _isSobixoSubmittedOrLocked)
          ? null
          : _isSobixo
              ? (_doctors.length >= 3
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: _openAddSheet,
                      backgroundColor: _purple,
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      label: Text('Add Doctor (${_doctors.length}/3)',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                    ))
              : FloatingActionButton.extended(
                  onPressed: _openAddSheet,
                  backgroundColor: _purple,
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: Text('Add Doctor',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // SOBIXO Status banner vs Zorberry Quota/Lock banner
                if (_isSobixo) ...[
                  _buildSobixoStatusBar(),
                ] else ...[
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
                  _buildWeekCalendar(),
                  if (_isWeekLoading)
                    const LinearProgressIndicator(
                      minHeight: 2.5,
                      color: _purple,
                      backgroundColor: Color(0xFFEDE7F6),
                    ),
                ],
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
                          onRefresh: () => _load(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                            itemCount: _filtered.length + 1,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              if (i == _filtered.length) return _buildSummaryCard();
                              return _buildDoctorCard(_filtered[i], index: i);
                            },
                          ),
                        ),
                ),
              ],
            ),
      bottomNavigationBar:
          _isSobixo ? _buildSobixoBottomBar() : _buildWeeklySubmitBar(),
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

  Widget _buildSobixoStatusBar() {
    final status = _sobixoEffectiveStatus;
    final bool isApproved = _isStatusApproved(status) ||
        _doctors.any((d) => _isStatusApproved(
            (d['approval_status'] ?? d['brand_approval_status'])
                ?.toString()
                .toLowerCase()
                .trim()));
    if (isApproved) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(children: [
          const Icon(Icons.verified, color: Color(0xFF16A34A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Doctor List Approved',
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF15803D))),
                Text('Your doctor mapping has been approved by your manager.',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF166534))),
              ],
            ),
          ),
        ]),
      );
    }

    final bool isPending = _isStatusPendingOrSubmitted(status) ||
        _doctors.any((d) => _isStatusPendingOrSubmitted(
            (d['approval_status'] ?? d['brand_approval_status'])
                ?.toString()
                .toLowerCase()
                .trim()));
    if (isPending) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(children: [
          const Icon(Icons.hourglass_top_rounded, color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending Manager Approval',
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1D4ED8))),
                Text('Your submission of 3 doctors is awaiting manager review.',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF1E40AF))),
              ],
            ),
          ),
        ]),
      );
    }

    final bool isRejected = _isStatusRejected(status) ||
        _doctors.any((d) => _isStatusRejected(
            (d['approval_status'] ?? d['brand_approval_status'])
                ?.toString()
                .toLowerCase()
                .trim()));
    if (isRejected) {
      final reason = _rejectionReason;
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Submission Rejected',
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFFB91C1C))),
                  const SizedBox(height: 2),
                  Text(reason != null && reason.isNotEmpty ? reason : 'Please review and update your doctors to re-submit.',
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF991B1B))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Draft / in progress state
    final bool exactThree = _doctors.length == 3;
    final bool isViewOnly = widget.readOnly || widget.isDoctorListLocked;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: exactThree ? const Color(0xFFF3E8FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: exactThree ? _purple.withValues(alpha: 0.3) : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: exactThree ? _purple.withValues(alpha: 0.12) : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            exactThree ? Icons.verified_outlined : Icons.track_changes_outlined,
            color: exactThree ? _purple : Colors.grey.shade700,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exactThree
                    ? '3 of 3 Doctors Selected'
                    : '${_doctors.length} of 3 Doctors Selected',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: exactThree ? _purple : Colors.black87,
                ),
              ),
              Text(
                isViewOnly
                    ? (exactThree
                        ? 'Doctor list is not submitted for approval yet.'
                        : '${_doctors.length} of 3 doctors added so far.')
                    : exactThree
                        ? 'Tap "Verify & Submit" below to verify and finalize.'
                        : 'Select ${3 - _doctors.length} more doctor${3 - _doctors.length == 1 ? '' : 's'} from Target Doctors or MCL.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: exactThree ? _purple.withValues(alpha: 0.8) : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildSobixoBottomBar() {
    final status = _sobixoEffectiveStatus;
    final bool isLocked = _isSobixoSubmittedOrLocked;

    if (isLocked) {
      final bool isApproved = _isStatusApproved(status) ||
          _doctors.any((d) => _isStatusApproved(
              (d['approval_status'] ?? d['brand_approval_status'])
                  ?.toString()
                  .toLowerCase()
                  .trim()));
      if (isApproved) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified, color: Color(0xFF16A34A), size: 16),
                const SizedBox(width: 8),
                Text('Doctor List Approved',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF15803D))),
              ],
            ),
          ),
        );
      }
      final bool isPendingOrUnderReview = _isStatusPendingOrSubmitted(status) ||
          _doctors.any((doc) {
            final ds = (doc['approval_status'] ?? doc['brand_approval_status'])
                ?.toString()
                .toLowerCase()
                .trim();
            return _isStatusPendingOrSubmitted(ds);
          });
      if (isPendingOrUnderReview) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.hourglass_top_rounded, color: Color(0xFF2563EB), size: 16),
                const SizedBox(width: 8),
                Text('Pending Manager Approval',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF1D4ED8))),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (_doctors.length == 3) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(0, -2),
              blurRadius: 8,
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              onPressed: () => _openSobixoVerificationSheet(),
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: Text(
                'Verify & Submit (3 Doctors)',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
          ),
        ),
      );
    }

    if (_doctors.isNotEmpty && _doctors.length < 3) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -2),
              blurRadius: 6,
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 16, color: _purple),
              const SizedBox(width: 8),
              Text(
                '${_doctors.length}/3 Doctors selected • Tap doctor to edit details',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _purple,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Map<String, Map<String, String>> _extractDoctorChanges(
    Map<String, dynamic> doctor,
  ) {
    final Map<String, Map<String, String>> result = {};
    if (doctor['has_changes'] != true) return result;
    final rawChanges = doctor['changes'];
    if (rawChanges is! List) return result;

    for (final item in rawChanges) {
      if (item is! Map) continue;
      final field = item['field']?.toString().trim() ?? '';
      if (field.isEmpty) continue;
      final oldVal = item['old_value']?.toString().trim() ?? '';
      final newVal = item['new_value']?.toString().trim() ?? '';
      final createdAt = item['created_at']?.toString().trim() ?? '';

      if (!result.containsKey(field)) {
        result[field] = {
          'old_value': oldVal,
          'new_value': newVal,
          'created_at': createdAt,
        };
      } else {
        result[field]!['new_value'] = newVal;
        result[field]!['created_at'] = createdAt;
      }
    }

    result.removeWhere((_, v) => v['old_value'] == v['new_value']);
    return result;
  }

  Widget _buildSobixoContactDiff({
    required IconData icon,
    required String currentValue,
    required Map<String, String>? change,
    required double fontSize,
  }) {
    final bool hasChange = change != null &&
        change['old_value'] != change['new_value'];
    final String oldVal = change?['old_value'] ?? '';
    final String displayNew = hasChange
        ? (change['new_value'] ?? '')
        : currentValue;

    if (!hasChange) {
      if (displayNew.isEmpty) return const SizedBox.shrink();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _purple.withValues(alpha: 0.8)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              displayNew,
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF15803D)),
          if (oldVal.isNotEmpty) ...[
            Text(
              oldVal,
              style: TextStyle(
                fontSize: fontSize - 0.5,
                color: Colors.grey.shade600,
                decoration: TextDecoration.lineThrough,
                decorationColor: const Color(0xFFDC2626),
                decorationThickness: 2.2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 13,
              color: Color(0xFF64748B),
            ),
          ],
          Text(
            displayNew.isNotEmpty ? displayNew : 'Removed',
            style: TextStyle(
              fontSize: fontSize,
              color: displayNew.isNotEmpty
                  ? const Color(0xFF15803D)
                  : const Color(0xFFDC2626),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor, {int index = 0}) {
    final fn = (doctor['first_name'] ?? '').toString().trim();
    final sn = (doctor['surname'] ?? '').toString().trim();
    final changesMap = _isSobixo
        ? _extractDoctorChanges(doctor)
        : const <String, Map<String, String>>{};
    final bool hasChanges =
        _isSobixo && doctor['has_changes'] == true && changesMap.isNotEmpty;

    final firstNameChange = changesMap['first_name'];
    final surnameChange = changesMap['surname'];
    final doctorNameChange = changesMap['doctor_name'];
    final mobileChange = changesMap['mobile'];
    final emailChange = changesMap['email'];

    final String effectiveFn = firstNameChange != null
        ? (firstNameChange['new_value'] ?? fn)
        : fn;
    final String effectiveSn = surnameChange != null
        ? (surnameChange['new_value'] ?? sn)
        : sn;

    final String name = doctorNameChange != null &&
            (doctorNameChange['new_value'] ?? '').isNotEmpty
        ? doctorNameChange['new_value']!
        : (effectiveFn.isNotEmpty || effectiveSn.isNotEmpty)
            ? '$effectiveFn $effectiveSn'.trim()
            : (doctor['doctor_name']?.toString() ?? '');

    String oldFullName = '';
    if (doctorNameChange != null &&
        (doctorNameChange['old_value'] ?? '').isNotEmpty) {
      oldFullName = doctorNameChange['old_value']!;
    } else if (firstNameChange != null || surnameChange != null) {
      final oldFn = firstNameChange?['old_value'] ?? fn;
      final oldSn = surnameChange?['old_value'] ?? sn;
      oldFullName = '$oldFn $oldSn'.trim();
    }
    final bool hasNameChange =
        oldFullName.isNotEmpty && oldFullName != name;

    final sp = doctor['specialty_practice_type']?.toString() ?? '';
    final area = doctor['area']?.toString() ?? '';
    final id = int.tryParse(doctor['id']?.toString() ?? '0') ?? 0;
    final isPathfinder = doctor['is_pathfinder'] == true;
    final bool canEditSobixo = _isSobixo && !_isSobixoSubmittedOrLocked;
    final bool canRemove = !widget.readOnly &&
        !widget.isDoctorListLocked &&
        !(_isSobixo && _isSobixoSubmittedOrLocked);
    final mobileStr = (doctor['mobile'] ?? doctor['phone'] ?? '').toString().trim();
    final emailStr = (doctor['email'] ?? '').toString().trim();
    final displayMobile = mobileChange != null
        ? (mobileChange['new_value'] ?? mobileStr)
        : mobileStr;
    final displayEmail = emailChange != null
        ? (emailChange['new_value'] ?? emailStr)
        : emailStr;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasChanges
              ? const Color(0xFF99F6E4)
              : isPathfinder
                  ? Colors.orange.shade200
                  : Colors.grey.shade200,
          width: hasChanges ? 1.3 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: canEditSobixo
              ? () => _openSobixoVerificationSheet(
                    initialDoctorId: id,
                    initialIndex: index,
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left side: Doctor avatar
                Container(
                  width: 38,
                  height: 38,
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
                const SizedBox(width: 10),
                // Center: Doctor information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: hasNameChange
                                ? Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        oldFullName,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.grey.shade600,
                                          decoration: TextDecoration.lineThrough,
                                          decorationColor: const Color(0xFFDC2626),
                                          decorationThickness: 2.2,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                          if (_isSobixo) ...[
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPathfinder
                                        ? Colors.orange.shade50
                                        : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isPathfinder
                                          ? Colors.orange.shade300
                                          : Colors.blue.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    isPathfinder ? 'Target Doctor' : 'MCL Doctor',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isPathfinder
                                          ? Colors.deepOrange
                                          : Colors.blueAccent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (hasChanges) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCCFBF1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0xFF5EEAD4)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_note_rounded,
                                            size: 11,
                                            color: Color(0xFF0F766E)),
                                        SizedBox(width: 2),
                                        Text(
                                          'Edited',
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            color: Color(0xFF0F766E),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ] else if (isPathfinder) ...[
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
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (sp.isNotEmpty) ...[
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE7F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sp,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: _purple,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (area.isNotEmpty)
                            Expanded(
                              child: Text(
                                area,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                      if (_isSobixo &&
                          (displayMobile.isNotEmpty ||
                              displayEmail.isNotEmpty ||
                              mobileChange != null ||
                              emailChange != null)) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (displayMobile.isNotEmpty || mobileChange != null)
                              _buildSobixoContactDiff(
                                icon: Icons.phone_android,
                                currentValue: displayMobile,
                                change: mobileChange,
                                fontSize: 13,
                              ),
                            if (displayEmail.isNotEmpty || emailChange != null)
                              _buildSobixoContactDiff(
                                icon: Icons.email_outlined,
                                currentValue: displayEmail,
                                change: emailChange,
                                fontSize: 12.5,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Right side: QTY Stepper for Zorberry, Edit/Remove icons for Sobixo
                if (!_isSobixo) ...[
                  _buildQtyStepper(id),
                ] else if (canEditSobixo) ...[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE7F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: _purple,
                    ),
                  ),
                ],
                if (canRemove) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _confirmRemove(id, name),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.remove_circle_outline,
                          color: Colors.red, size: 20),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
  final bool isSobixo;
  const _DrBrandMapAddDoctorSheet({
    required this.brandId,
    required this.alreadyAdded,
    required this.quotaRemaining,
    this.isSobixo = false,
  });

  @override
  State<_DrBrandMapAddDoctorSheet> createState() => _DrBrandMapAddDoctorSheetState();
}

class _DrBrandMapAddDoctorSheetState extends State<_DrBrandMapAddDoctorSheet> {
  static const _purple = Color(0xFF4A148C);
  Color get _primaryColor => _purple;

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
      final List<Map<String, dynamic>> docs;
      if (widget.isSobixo) {
        docs = await ApiService().getSobixoDoctorList();
      } else {
        docs = await ApiService().getDrBrandMapDoctorList(brandId: widget.brandId);
      }
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
              .where((d) {
                final fn = (d['first_name'] ?? '').toString().toLowerCase();
                final sn = (d['surname'] ?? '').toString().toLowerCase();
                final dn = (d['doctor_name'] ?? '').toString().toLowerCase();
                final sp = (d['specialty_practice_type'] ?? '').toString().toLowerCase();
                final area = (d['area'] ?? '').toString().toLowerCase();
                return fn.contains(q) ||
                    sn.contains(q) ||
                    '$fn $sn'.contains(q) ||
                    dn.contains(q) ||
                    sp.contains(q) ||
                    area.contains(q);
              })
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
      if (widget.isSobixo) {
        final newlySelectedDocs = _allDoctors
            .where((d) {
              final id = int.tryParse(d['id']?.toString() ?? '0') ?? 0;
              return _selected.contains(id);
            })
            .map((d) => {
                  ...Map<String, dynamic>.from(d),
                  '__local_only': true,
                })
            .toList();
        if (mounted) Navigator.pop(context, newlySelectedDocs);
        return;
      } else {
        await ApiService().addDrBrandMapDoctors(widget.brandId, _selected.toList());
      }
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
                            color: _primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${_selected.length} selected',
                              style: TextStyle(
                                  color: _primaryColor,
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
                          child: const Text('10 Target Doctors',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        Text('shown at top, followed by MCL Doctors',
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
                        prefixIcon: Icon(Icons.search, color: _primaryColor),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryColor)),
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
                                final fn = (doc['first_name'] ?? '').toString().trim();
                                final sn = (doc['surname'] ?? '').toString().trim();
                                final name = (fn.isNotEmpty || sn.isNotEmpty)
                                    ? '$fn $sn'.trim()
                                    : (doc['doctor_name']?.toString() ?? '');
                                final sp = doc['specialty_practice_type']?.toString() ?? '';
                                final area = doc['area']?.toString() ?? '';
                                final sel = _selected.contains(id);
                                final isPathfinder = doc['is_pathfinder'] == true;

                                return CheckboxListTile(
                                  value: sel,
                                  activeColor: _primaryColor,
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
                                            'Target Doctor',
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.deepOrange,
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ] else ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                                color: Colors.blue.shade200),
                                          ),
                                          child: const Text(
                                            'MCL Doctor',
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.blueAccent,
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
                        backgroundColor: _primaryColor,
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
