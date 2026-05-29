import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/new_doctor.dart';
import '../../data/models/speciality_target.dart';
import '../../data/services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'add_edit_new_doctor_screen.dart';

class NewDrMasterScreen extends StatefulWidget {
  const NewDrMasterScreen({super.key});

  @override
  State<NewDrMasterScreen> createState() => _NewDrMasterScreenState();
}

class _NewDrMasterScreenState extends State<NewDrMasterScreen>
    with SingleTickerProviderStateMixin {
  static const _purple = Color(0xFF4A148C);

  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isApproving = false;
  bool _isRejecting = false;
  bool _isDownloadingMclCsv = false;

  List<NewDoctor> _myDoctors = [];
  List<NewDoctor> _subDoctors = [];
  List<dynamic> _subordinates = [];
  int? _selectedSubId;
  bool _isLoadingSub = false;

  // My list approval state
  String? _myApprovalStatus;   // null / 'pending' / 'approved' / 'rejected'
  String? _myRejectionReason;

  // Selected subordinate approval state
  String? _subApprovalStatus;
  String? _subRejectionReason;

  // Three independent target lists (each entry groups multiple specialities)
  List<SpecialityTarget> _mslTargets   = [];   // Full MCL list
  List<SpecialityTarget> _kblTargets   = [];   // KBL doctors
  List<SpecialityTarget> _core3Targets = [];   // 3-Visit Core FRD
  // {core_3: int, frd_2: int, kbl: int} — for overall category badges
  Map<String, int> _overallTargets = {};
  bool _isLoadingTargets = true;

  // ── Filtered lists ─────────────────────────────────────────────────────────

  List<NewDoctor> get _filteredMyDoctors {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _myDoctors;
    return _myDoctors.where((d) =>
        d.fullName.toLowerCase().contains(q) ||
        d.specialtyPracticeType.toLowerCase().contains(q) ||
        d.city.toLowerCase().contains(q)).toList();
  }

  List<NewDoctor> get _filteredSubDoctors {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _subDoctors;
    return _subDoctors.where((d) =>
        d.fullName.toLowerCase().contains(q) ||
        d.specialtyPracticeType.toLowerCase().contains(q) ||
        d.city.toLowerCase().contains(q)).toList();
  }

  // ── Group-based counting helpers ───────────────────────────────────────────

  // How many docs in a given list fall into a target group (any visit category)
  int _countGroup(SpecialityTarget g, List<NewDoctor> docs) =>
      docs.where((d) => g.contains(d.specialtyPracticeType)).length;

  // KBL docs in a group
  int _countKblGroup(SpecialityTarget g, List<NewDoctor> docs) =>
      docs.where((d) => g.contains(d.specialtyPracticeType) && d.visitCategory == 'KBL').length;

  // CORE_3 docs in a group
  int _countCore3Group(SpecialityTarget g, List<NewDoctor> docs) =>
      docs.where((d) => g.contains(d.specialtyPracticeType) && d.visitCategory == 'CORE_3').length;

  // Full MCL counts the complete doctor list, including "No target" specialities.
  int _countFullMclDoctors(List<NewDoctor> docs) =>
      docs.where((d) => d.specialtyPracticeType.isNotEmpty).length;

  int get _fullMclRequiredTotal =>
      _mslTargets.fold(0, (sum, t) => sum + t.quota);

  // Full MCL allowance stays data-driven from the backend target.
  int _fullMclMinAllowed(int required) => (required * 0.9).ceil();

  int _fullMclMaxAllowed(int required) => (required * 11) ~/ 10;

  Map<String, int> _categoryCounts(List<NewDoctor> docs) {
    final map = {'CORE_3': 0, 'FRD_2': 0, 'KBL': 0, 'REMAINING': 0, 'UNSET': 0};
    for (final d in docs) {
      final k = d.visitCategory ?? 'UNSET';
      map[k] = (map[k] ?? 0) + 1;
    }
    return map;
  }

  bool get _allTargetsMet {
    if (_mslTargets.isEmpty && _kblTargets.isEmpty && _core3Targets.isEmpty) return false;
    final fullMclRequired = _fullMclRequiredTotal;
    if (fullMclRequired > 0 &&
        _countFullMclDoctors(_myDoctors) < fullMclRequired) {
      return false;
    }
    for (final t in _kblTargets) {
      if (t.quota > 0 && _countKblGroup(t, _myDoctors) < t.quota) return false;
    }
    for (final t in _core3Targets) {
      if (t.quota > 0 && _countCore3Group(t, _myDoctors) < t.quota) return false;
    }
    return true;
  }

  // Allows submission when Full MCL is within the complete-list allowance.
  // KBL and CORE_3 quotas must still be fully met.
  bool get _canSubmit {
    if (_mslTargets.isEmpty && _kblTargets.isEmpty && _core3Targets.isEmpty) return false;
    final fullMclRequired = _fullMclRequiredTotal;
    if (fullMclRequired > 0) {
      final fullMclAdded = _countFullMclDoctors(_myDoctors);
      final minAllowed = _fullMclMinAllowed(fullMclRequired);
      final maxAllowed = _fullMclMaxAllowed(fullMclRequired);
      if (fullMclAdded < minAllowed || fullMclAdded > maxAllowed) return false;
    }
    for (final t in _kblTargets) {
      if (t.quota > 0 && _countKblGroup(t, _myDoctors) < t.quota) return false;
    }
    for (final t in _core3Targets) {
      if (t.quota > 0 && _countCore3Group(t, _myDoctors) < t.quota) return false;
    }
    return true;
  }

  bool get _canEditMyList =>
      _myApprovalStatus != 'pending' && _myApprovalStatus != 'approved';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _searchCtrl.addListener(() => setState(() {}));
    _loadMyDoctors();
    _loadSubordinates();
    _loadSpecialityTargets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data loaders ───────────────────────────────────────────────────────────

  Future<void> _loadMyDoctors() async {
    setState(() => _isLoading = true);
    try {
      final raw = await ApiService().getNewDoctorMaster();
      final docs = raw.map((e) => NewDoctor.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _myDoctors = docs;
        _myApprovalStatus  = docs.isNotEmpty ? docs.first.approvalStatus  : null;
        _myRejectionReason = docs.isNotEmpty ? docs.first.rejectionReason : null;
      });
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSubordinates() async {
    try {
      final list = await ApiService().getSubordinates();
      if (mounted) setState(() => _subordinates = list);
    } catch (_) {}
  }

  Future<void> _loadSubDoctors(int userId) async {
    setState(() {
      _isLoadingSub      = true;
      _subApprovalStatus = null;
      _subRejectionReason = null;
    });
    try {
      final raw = await ApiService().getNewDoctorMaster(userId: userId);
      final docs = raw.map((e) => NewDoctor.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _subDoctors         = docs;
        _subApprovalStatus  = docs.isNotEmpty ? docs.first.approvalStatus  : null;
        _subRejectionReason = docs.isNotEmpty ? docs.first.rejectionReason : null;
      });
    } catch (_) {
      setState(() => _subDoctors = []);
    }
    if (mounted) setState(() => _isLoadingSub = false);
  }

  Future<void> _loadSpecialityTargets() async {
    setState(() => _isLoadingTargets = true);
    try {
      final raw = await ApiService().getDoctorSpecialityTargets();
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : raw;

      List<SpecialityTarget> parseList(String key) {
        final list = data[key];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((e) => SpecialityTarget.fromJson(Map<String, dynamic>.from(e)))
              .where((t) => t.category.isNotEmpty)
              .toList();
        }
        return [];
      }

      final overallRaw = data['overall'];
      final overall = <String, int>{};
      if (overallRaw is Map) {
        int ri(List<String> keys) {
          for (final k in keys) {
            final v = overallRaw[k];
            if (v is num) return v.toInt();
            if (v is String) return int.tryParse(v) ?? 0;
          }
          return 0;
        }
        overall['core_3'] = ri(['core_3']);
        overall['frd_2']  = ri(['frd_2']);
        overall['kbl']    = ri(['kbl']);
      }

      if (mounted) {
        setState(() {
          _overallTargets = overall;
          _mslTargets     = parseList('msl_targets');
          _kblTargets     = parseList('kbl_targets');
          _core3Targets   = parseList('core3_targets');
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingTargets = false);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Map<String, dynamic>? get _selectedSubordinate {
    if (_selectedSubId == null) return null;
    for (final sub in _subordinates) {
      if (sub is Map && sub['id'] == _selectedSubId) {
        return Map<String, dynamic>.from(sub);
      }
    }
    return null;
  }

  String? get _selectedSubordinateEmployeeCode {
    final sub = _selectedSubordinate;
    if (sub == null) return null;

    final rawCode = sub['employee_code'] ??
        sub['emp_code'];
    final code = rawCode?.toString().trim();
    if (code != null && code.isNotEmpty) return code;

    return null;
  }

  Future<void> _downloadSelectedSubordinateMclCsv() async {
    final employeeCode = _selectedSubordinateEmployeeCode;
    if (employeeCode == null || employeeCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee code not found for selected team member'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isDownloadingMclCsv = true);
    try {
      final uri = ApiService().getMclDoctorCsvExportUri(employeeCode);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open download link');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isDownloadingMclCsv = false);
  }

  Future<void> _downloadMyMclCsv() async {
    final employeeCode = Provider.of<AuthProvider>(context, listen: false)
        .user
        ?.employeeCode
        .trim();
    if (employeeCode == null || employeeCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee code not found for logged-in user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isDownloadingMclCsv = true);
    try {
      final uri = ApiService().getMclDoctorCsvExportUri(employeeCode);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open download link');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isDownloadingMclCsv = false);
  }

  Future<void> _submitForApproval() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.send_outlined, color: _purple),
          SizedBox(width: 10),
          Text('Submit for Approval',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          'Submit your doctor list (${_myDoctors.length} doctors) for manager approval?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _purple, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      await ApiService().submitDoctorListForApproval();
      if (mounted) {
        setState(() => _myApprovalStatus = 'pending');
        await _loadMyDoctors();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Doctor list submitted for approval!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _approveList() async {
    if (_selectedSubId == null) return;
    setState(() => _isApproving = true);
    try {
      await ApiService().approveNewDoctorList(_selectedSubId!);
      if (mounted) {
        setState(() => _subApprovalStatus = 'approved');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Doctor list approved!'), backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _isApproving = false);
  }

  Future<void> _showRejectDialog() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.cancel_outlined, color: Colors.red.shade600),
          const SizedBox(width: 10),
          const Text('Reject List',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, reasonCtrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    await _rejectList(reason);
  }

  Future<void> _rejectList(String reason) async {
    if (_selectedSubId == null) return;
    setState(() => _isRejecting = true);
    try {
      await ApiService().rejectNewDoctorList(_selectedSubId!, reason);
      if (mounted) {
        setState(() {
          _subApprovalStatus  = 'rejected';
          _subRejectionReason = reason;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Doctor list rejected.'), backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _isRejecting = false);
  }

  void _openAddEdit([NewDoctor? doc]) async {
    if (!_canEditMyList) return;
    if (_isLoadingTargets) await _loadSpecialityTargets();
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditNewDoctorScreen(
          doctor: doc,
          existingDoctors: _myDoctors,
          mslTargets:    _mslTargets,
          kblTargets:    _kblTargets,
          core3Targets:  _core3Targets,
          overallTargets: _overallTargets,
        ),
      ),
    );
    if (result == true) {
      await Future.wait([_loadMyDoctors(), _loadSpecialityTargets()]);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text('New Dr. Master',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(text: 'My Doctors (${_myDoctors.length})'),
            const Tab(text: 'Team View'),
          ],
        ),
      ),
      floatingActionButton: _canEditMyList
          ? FloatingActionButton(
              backgroundColor: _purple,
              onPressed: () => _openAddEdit(),
              child: const Icon(Icons.person_add_alt_1, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, specialty, city…',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchCtrl.clear()))
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildMyDoctorsTab(), _buildTeamTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ── My Doctors Tab ─────────────────────────────────────────────────────────

  Widget _buildMyDoctorsTab() {
    if (_isLoading && _myDoctors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final docs = _filteredMyDoctors;
    final cat  = _categoryCounts(_myDoctors);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadMyDoctors(), _loadSpecialityTargets()]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
        children: [
          _buildMyCsvDownloadButton(),
          const SizedBox(height: 10),
          _buildCategoryRow(cat),
          const SizedBox(height: 10),
          _buildMslSummaryCard(_myDoctors),
          const SizedBox(height: 8),
          _buildKblSummaryCard(_myDoctors),
          const SizedBox(height: 8),
          _buildCore3SummaryCard(_myDoctors),
          const SizedBox(height: 8),
          _buildSubmitSection(),
          const SizedBox(height: 4),
          _buildSectionHeader(
              _searchCtrl.text.isEmpty
                  ? '${_myDoctors.length} Doctors'
                  : '${docs.length} of ${_myDoctors.length} shown'),
          if (docs.isEmpty)
            _buildEmptyState('No doctors added yet. Tap + to add your first doctor.')
          else
            ...docs.map((d) => _buildDoctorCard(d, canEdit: _canEditMyList)),
        ],
      ),
    );
  }

  // ── Team Tab ───────────────────────────────────────────────────────────────

  Widget _buildTeamTab() {
    final docs = _filteredSubDoctors;
    final cat  = _categoryCounts(_subDoctors);

    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedSubId != null) await _loadSubDoctors(_selectedSubId!);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
        children: [
          if (_subordinates.isNotEmpty) ...[
            _buildSubordinatePicker(),
            const SizedBox(height: 10),
          ],
          if (_selectedSubId != null) ...[
            _buildTeamCsvDownloadButton(),
            const SizedBox(height: 10),
            _buildSubApprovalBanner(),
            if (_subApprovalStatus != null) const SizedBox(height: 8),
            _buildCategoryRow(cat),
            const SizedBox(height: 10),
            _buildMslSummaryCard(_subDoctors),
            const SizedBox(height: 8),
            _buildKblSummaryCard(_subDoctors),
            const SizedBox(height: 8),
            _buildCore3SummaryCard(_subDoctors),
            const SizedBox(height: 8),
            if (_subApprovalStatus == 'pending') ...[
              _buildApprovalButtons(),
              const SizedBox(height: 4),
            ],
          ],
          _buildSectionHeader(
              _selectedSubId == null ? 'Select a team member' : '${docs.length} Doctors'),
          if (_isLoadingSub)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_selectedSubId == null)
            _buildEmptyState('Select a team member above to view their doctors')
          else if (docs.isEmpty)
            _buildEmptyState('No doctors found for selected member')
          else
            ...docs.map((d) => _buildDoctorCard(d, canEdit: false)),
        ],
      ),
    );
  }

  // ── Category Distribution Row ──────────────────────────────────────────────

  Widget _buildCategoryRow(Map<String, int> counts) {
    final items = [
      {'label': '3V Core FRD', 'key': 'CORE_3',    'color': _purple,                'tk': 'core_3'},
      {'label': '2V FRD',      'key': 'FRD_2',     'color': Colors.blue.shade700,   'tk': 'frd_2'},
      {'label': 'KBL',         'key': 'KBL',       'color': Colors.deepOrange,      'tk': 'kbl'},
      {'label': 'Remaining',   'key': 'REMAINING',  'color': Colors.teal,            'tk': null},
      {'label': 'Unset',       'key': 'UNSET',     'color': Colors.grey,            'tk': null},
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Icon(Icons.donut_small_outlined, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text('Category',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              final color = item['color'] as Color;
              final count  = counts[item['key'] as String] ?? 0;
              final tk     = item['tk'] as String?;
              final target = tk != null ? (_overallTargets[tk] ?? 0) : 0;
              final met    = target > 0 && count >= target;
              return Expanded(
                child: Column(children: [
                  Text(item['label'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Container(
                    constraints: const BoxConstraints(minWidth: 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: met ? Colors.green.shade50 : color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: met
                          ? Border.all(color: Colors.green.shade300, width: 0.5)
                          : null,
                    ),
                    child: Text(
                      target > 0 ? '$count/$target' : '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: met ? Colors.green.shade700 : color),
                    ),
                  ),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ── 3 Speciality Summary Cards ─────────────────────────────────────────────

  Widget _buildMslSummaryCard(List<NewDoctor> docs) {
    int totalQ = 0;
    final totalA = _countFullMclDoctors(docs);
    // Collect all specialities NOT covered by any MSL group (extras)
    final allGroupSp = _mslTargets.expand((t) => t.specialities).toSet();
    final extraSp = docs
        .map((d) => d.specialtyPracticeType)
        .where((sp) => sp.isNotEmpty && !allGroupSp.contains(sp))
        .toSet()
        .toList()
      ..sort();

    final rows = <_TableRow>[];
    for (final t in _mslTargets) {
      final added = _countGroup(t, docs);
      totalQ += t.quota;
      rows.add(_TableRow(
        label: t.category,
        subLabel: t.specialities.join(' · '),
        col2: t.quota > 0 ? '${t.quota}' : '—',
        col3: '$added',
        status: t.quota == 0 ? _RowStatus.noTarget
            : added >= t.quota ? _RowStatus.done
            : added == 0 ? _RowStatus.zero
            : _RowStatus.partial,
        remaining: t.quota > 0 ? t.quota - added : null,
      ));
    }
    for (final sp in extraSp) {
      final added = docs.where((d) => d.specialtyPracticeType == sp).length;
      rows.add(_TableRow(
        label: sp, col2: '—', col3: '$added', status: _RowStatus.noTarget,
      ));
    }

    return _buildSummaryCard(
      title: 'Full MCL — Complete List',
      icon: Icons.list_alt_outlined,
      color: Colors.blue.shade700,
      col2Header: 'Required',
      col3Header: 'Added',
      totalLabel: '$totalA / $totalQ',
      totalMet: totalQ > 0 && totalA >= totalQ,
      isLoading: _isLoadingTargets,
      rows: rows.isEmpty
          ? [const _TableRow(label: 'No MSL targets configured', col2: '—', col3: '—', status: _RowStatus.noTarget)]
          : rows,
    );
  }

  Widget _buildKblSummaryCard(List<NewDoctor> docs) {
    int totalQ = 0, totalA = 0;
    final allGroupSp = _kblTargets.expand((t) => t.specialities).toSet();
    final extraSp = docs
        .where((d) => d.visitCategory == 'KBL' &&
            d.specialtyPracticeType.isNotEmpty &&
            !allGroupSp.contains(d.specialtyPracticeType))
        .map((d) => d.specialtyPracticeType)
        .toSet()
        .toList()
      ..sort();

    final rows = <_TableRow>[];
    for (final t in _kblTargets) {
      final added = _countKblGroup(t, docs);
      totalQ += t.quota;
      totalA += added;
      rows.add(_TableRow(
        label: t.category,
        subLabel: t.specialities.join(' · '),
        col2: t.quota > 0 ? '${t.quota}' : '—',
        col3: '$added',
        status: t.quota == 0 ? _RowStatus.noTarget
            : added >= t.quota ? _RowStatus.done
            : added == 0 ? _RowStatus.zero
            : _RowStatus.partial,
        remaining: t.quota > 0 ? t.quota - added : null,
      ));
    }
    for (final sp in extraSp) {
      final added = docs.where((d) => d.specialtyPracticeType == sp && d.visitCategory == 'KBL').length;
      rows.add(_TableRow(
        label: sp, col2: '—', col3: '$added', status: _RowStatus.noTarget,
      ));
    }

    return _buildSummaryCard(
      title: 'KBL Doctors — Speciality Quota',
      icon: Icons.star_outline,
      color: Colors.deepOrange,
      col2Header: 'Quota',
      col3Header: 'KBL',
      totalLabel: totalQ > 0 ? '$totalA / $totalQ' : '$totalA',
      totalMet: totalQ > 0 && totalA >= totalQ,
      isLoading: _isLoadingTargets,
      rows: rows.isEmpty
          ? [const _TableRow(label: 'No KBL targets configured', col2: '—', col3: '—', status: _RowStatus.noTarget)]
          : rows,
    );
  }

  Widget _buildCore3SummaryCard(List<NewDoctor> docs) {
    int totalQ = 0, totalA = 0;
    final allGroupSp = _core3Targets.expand((t) => t.specialities).toSet();
    final extraSp = docs
        .where((d) => d.visitCategory == 'CORE_3' &&
            d.specialtyPracticeType.isNotEmpty &&
            !allGroupSp.contains(d.specialtyPracticeType))
        .map((d) => d.specialtyPracticeType)
        .toSet()
        .toList()
      ..sort();

    final rows = <_TableRow>[];
    for (final t in _core3Targets) {
      final added = _countCore3Group(t, docs);
      totalQ += t.quota;
      totalA += added;
      rows.add(_TableRow(
        label: t.category,
        subLabel: t.specialities.join(' · '),
        col2: t.quota > 0 ? '${t.quota}' : '—',
        col3: '$added',
        status: t.quota == 0 ? _RowStatus.noTarget
            : added >= t.quota ? _RowStatus.done
            : added == 0 ? _RowStatus.zero
            : _RowStatus.partial,
        remaining: t.quota > 0 ? t.quota - added : null,
      ));
    }
    for (final sp in extraSp) {
      final added = docs.where((d) => d.specialtyPracticeType == sp && d.visitCategory == 'CORE_3').length;
      rows.add(_TableRow(
        label: sp, col2: '—', col3: '$added', status: _RowStatus.noTarget,
      ));
    }

    return _buildSummaryCard(
      title: '3-Visit Core FRD — Speciality Quota',
      icon: Icons.repeat_outlined,
      color: _purple,
      col2Header: 'Quota',
      col3Header: '3V',
      totalLabel: totalQ > 0 ? '$totalA / $totalQ' : '$totalA',
      totalMet: totalQ > 0 && totalA >= totalQ,
      isLoading: _isLoadingTargets,
      rows: rows.isEmpty
          ? [const _TableRow(label: 'No 3V Core FRD targets configured', col2: '—', col3: '—', status: _RowStatus.noTarget)]
          : rows,
    );
  }

  // ── Generic summary card ───────────────────────────────────────────────────

  Widget _buildSummaryCard({
    required String title,
    required IconData icon,
    required Color color,
    required String col2Header,
    required String col3Header,
    required String totalLabel,
    required bool totalMet,
    required bool isLoading,
    required List<_TableRow> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: totalMet ? Colors.green.shade300 : color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: totalMet ? Colors.green.shade50 : color.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              Icon(totalMet ? Icons.check_circle : icon,
                  size: 15,
                  color: totalMet ? Colors.green.shade600 : color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: totalMet ? Colors.green.shade700 : color)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: totalMet ? Colors.green.shade100 : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  totalMet ? '✓ $totalLabel' : totalLabel,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: totalMet ? Colors.green.shade700 : color),
                ),
              ),
            ]),
          ),
          // Column headers
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(children: [
              const Expanded(
                flex: 10,
                child: Text('Category / Speciality',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                        color: Color(0xFF888888))),
              ),
              _colHead(col2Header, 52),
              _colHead(col3Header, 52),
              _colHead('Status', 56),
            ]),
          ),
          const Divider(height: 1),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Center(child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            ...rows.asMap().entries.map((e) => _buildTableRow(e.value, e.key, color)),
        ],
      ),
    );
  }

  Widget _colHead(String text, double width) => SizedBox(
    width: width,
    child: Text(text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
            color: Color(0xFF888888))),
  );

  Widget _buildTableRow(_TableRow r, int index, Color themeColor) {
    Color statusColor, statusBg;
    String statusText;
    switch (r.status) {
      case _RowStatus.done:
        statusColor = Colors.green.shade700;
        statusBg    = Colors.green.shade50;
        statusText  = '✓ Done';
        break;
      case _RowStatus.partial:
        statusColor = Colors.orange.shade700;
        statusBg    = Colors.orange.shade50;
        statusText  = 'Need ${r.remaining}';
        break;
      case _RowStatus.zero:
        statusColor = Colors.red.shade600;
        statusBg    = Colors.red.shade50;
        statusText  = r.remaining != null ? 'Need ${r.remaining}' : 'None';
        break;
      case _RowStatus.noTarget:
        statusColor = Colors.grey.shade500;
        statusBg    = Colors.grey.shade100;
        statusText  = 'No target';
        break;
    }

    return Container(
      color: index.isOdd ? themeColor.withValues(alpha: 0.025) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Expanded(
          flex: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              if (r.subLabel != null && r.subLabel!.isNotEmpty)
                Text(r.subLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
            ],
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(r.col2,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600)),
        ),
        SizedBox(
          width: 52,
          child: Text(r.col3,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold,
                  color: r.status == _RowStatus.done
                      ? Colors.green.shade700
                      : r.status == _RowStatus.zero
                          ? Colors.red.shade400
                          : themeColor)),
        ),
        SizedBox(
          width: 56,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
                color: statusBg, borderRadius: BorderRadius.circular(6)),
            child: Text(statusText,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
        ),
      ]),
    );
  }

  // ── Submit Section ─────────────────────────────────────────────────────────

  Widget _buildSubmitSection() {
    if (_myApprovalStatus == 'approved') {
      return Column(children: [
        _statusBanner(
          icon: Icons.verified, color: Colors.green,
          title: 'List Approved!',
          subtitle: 'Your doctor list has been approved by your manager.',
        ),
        const SizedBox(height: 8),
        _editLockedBanner(),
      ]);
    }
    if (_myApprovalStatus == 'pending') {
      return Column(children: [
        _statusBanner(
          icon: Icons.hourglass_empty, color: Colors.blue,
          title: 'Pending Approval',
          subtitle: 'Your list is submitted and awaiting manager review.',
        ),
        const SizedBox(height: 8),
        _editLockedBanner(),
      ]);
    }
    if (_myApprovalStatus == 'rejected') {
      return Column(children: [
        _statusBanner(
          icon: Icons.cancel, color: Colors.red,
          title: 'List Rejected',
          subtitle: (_myRejectionReason != null && _myRejectionReason!.isNotEmpty)
              ? 'Reason: $_myRejectionReason'
              : 'Please update your list and re-submit.',
        ),
        const SizedBox(height: 8),
        _submitButton(label: 'Re-submit for Approval', icon: Icons.replay_outlined),
      ]);
    }
    if (_allTargetsMet) {
      return Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(children: [
            Icon(Icons.emoji_events, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('All targets met! Ready to submit.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
          ]),
        ),
        const SizedBox(height: 8),
        _submitButton(label: 'Submit List for Approval', icon: Icons.send_outlined),
      ]);
    }
    if (_isLoadingTargets) return const SizedBox.shrink();

    // Full MCL within complete-list allowance — allow submission with a notice.
    // Full MCL total uses actual doctors added, including "No target" rows.
    if (_canSubmit) {
      final totalRequired = _fullMclRequiredTotal;
      final totalAdded = _countFullMclDoctors(_myDoctors);
      return Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, color: Colors.amber.shade800, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MSL nearly complete ($totalAdded / $totalRequired)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900)),
              Text('Within Full MCL allowance — you may submit now.',
                  style: TextStyle(fontSize: 11, color: Colors.amber.shade800)),
            ])),
          ]),
        ),
        const SizedBox(height: 8),
        _submitButton(label: 'Submit List for Approval', icon: Icons.send_outlined),
      ]);
    }

    final totalRequired = _fullMclRequiredTotal;
    final totalAdded = _countFullMclDoctors(_myDoctors);
    final minAllowed = _fullMclMinAllowed(totalRequired);
    final stillNeeded = (minAllowed - totalAdded).clamp(0, minAllowed);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(children: [
        Icon(Icons.hourglass_top_outlined, color: Colors.orange.shade700, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need $stillNeeded more doctor${stillNeeded == 1 ? '' : 's'} to complete Full MCL',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: Colors.orange.shade800),
            ),
            Text(
              '$totalAdded of $totalRequired required doctors added',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
            ),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$totalAdded/$totalRequired',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: Colors.orange.shade800),
          ),
        ),
      ]),
    );
  }

  Widget _editLockedBanner() {
    return _statusBanner(
      icon: Icons.lock_outline,
      color: Colors.orange,
      title: 'Editing Locked',
      subtitle:
          'You cannot add a new Dr or update Dr details because the list has already been submitted to the manager.',
    );
  }

  Widget _statusBanner({
    required IconData icon,
    required MaterialColor color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade300),
      ),
      child: Row(children: [
        Icon(icon, color: color.shade600, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: color.shade800)),
          Text(subtitle,
              style: TextStyle(fontSize: 11, color: color.shade600)),
        ])),
      ]),
    );
  }

  Widget _submitButton({required String label, required IconData icon}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _purple, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        onPressed: _isSubmitting ? null : _submitForApproval,
        icon: _isSubmitting
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(_isSubmitting ? 'Submitting…' : label,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }

  // ── Sub Approval Banner & Buttons ──────────────────────────────────────────

  Widget _buildSubApprovalBanner() {
    //if (_subApprovalStatus == null) return const SizedBox.shrink();
    IconData icon;
    MaterialColor color;
    String title, subtitle;
    switch (_subApprovalStatus) {
      case 'approved':
        icon = Icons.verified; color = Colors.green;
        title = 'List Approved';
        subtitle = 'This doctor list has been approved.';
        break;
      case 'pending':
        icon = Icons.hourglass_empty; color = Colors.blue;
        title = 'Pending Approval';
        subtitle = 'List submitted — awaiting your review.';
        break;
      default: // rejected
        icon = Icons.cancel; color = Colors.red;
        title = 'Previously Rejected';
        subtitle = (_subRejectionReason != null && _subRejectionReason!.isNotEmpty)
            ? 'Reason: $_subRejectionReason'
            : 'This list was rejected.';
    }
    return _statusBanner(icon: icon, color: color, title: title, subtitle: subtitle);
  }

  Widget _buildApprovalButtons() {
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isApproving || _isRejecting ? null : _approveList,
          icon: _isApproving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline, size: 18),
          label: Text(_isApproving ? 'Approving…' : 'Approve',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isApproving || _isRejecting ? null : _showRejectDialog,
          icon: _isRejecting
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.cancel_outlined, size: 18),
          label: Text(_isRejecting ? 'Rejecting…' : 'Reject',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  // ── Common widgets ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: Colors.grey.shade500)),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
      ]),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(children: [
          Icon(Icons.person_search, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildSubordinatePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedSubId,
          isExpanded: true,
          hint: Text('Select team member',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          icon: Icon(Icons.expand_more, color: Colors.grey.shade500),
          items: _subordinates.map((s) => DropdownMenuItem<int>(
            value: s['id'] as int,
            child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 14)),
          )).toList(),
          onChanged: (val) {
            setState(() {
              _selectedSubId      = val;
              _subDoctors         = [];
              _subApprovalStatus  = null;
              _subRejectionReason = null;
            });
            if (val != null) _loadSubDoctors(val);
          },
        ),
      ),
    );
  }

  // ── Doctor Card ────────────────────────────────────────────────────────────

  Widget _buildTeamCsvDownloadButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isDownloadingMclCsv ? null : _downloadSelectedSubordinateMclCsv,
        icon: _isDownloadingMclCsv
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined, size: 18),
        label: Text(
          _isDownloadingMclCsv ? 'Opening CSV...' : 'Download MCL CSV',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _purple,
          side: BorderSide(color: _purple.withOpacity(0.35)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildMyCsvDownloadButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isDownloadingMclCsv ? null : _downloadMyMclCsv,
        icon: _isDownloadingMclCsv
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined, size: 18),
        label: Text(
          _isDownloadingMclCsv ? 'Opening CSV...' : 'Download MCL CSV',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _purple,
          side: BorderSide(color: _purple.withOpacity(0.35)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildDoctorCard(NewDoctor doc, {required bool canEdit}) {
    final profileColors = {'H': Colors.blue, 'T': Colors.green, 'HT': Colors.purple};
    final profileColor = profileColors[doc.doctorProfile] ?? Colors.grey;
    Color? catColor;
    if (doc.visitCategory == 'CORE_3')    catColor = _purple;
    if (doc.visitCategory == 'FRD_2')     catColor = Colors.blue.shade700;
    if (doc.visitCategory == 'KBL')       catColor = Colors.deepOrange;
    if (doc.visitCategory == 'REMAINING') catColor = Colors.teal;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canEdit ? () => _openAddEdit(doc) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _purple.withValues(alpha: 0.1),
              child: Text(doc.initials,
                  style: const TextStyle(color: _purple,
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text('Dr. ${doc.fullName}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  if (doc.isKbl) _badge('KBL', Colors.deepOrange),
                  if (doc.isFrd) _badge('FRD', Colors.indigo),
                  if (catColor != null) _badge(doc.visitCategoryLabel, catColor),
                ]),
                const SizedBox(height: 2),
                Text(
                    doc.specialtyPracticeType.isNotEmpty
                        ? doc.specialtyPracticeType
                        : doc.specialtyQualification,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _infoBadge(_profileLabel(doc.doctorProfile), profileColor),
                  if (doc.routeName != null && doc.routeName!.isNotEmpty)
                    _infoBadge(doc.routeName!, Colors.teal),
                  if (doc.town.isNotEmpty || doc.city.isNotEmpty)
                    _infoText(Icons.location_on_outlined,
                        [doc.town, doc.city].where((s) => s.isNotEmpty).join(', ')),
                  if (doc.businessPotential != null)
                    _infoText(Icons.trending_up,
                        '₹${doc.businessPotential!.toStringAsFixed(1)}L',
                        color: Colors.green.shade700),
                ]),
              ]),
            ),
            if (canEdit)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    margin: const EdgeInsets.only(left: 4),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
    child: Text(label,
        style: const TextStyle(color: Colors.white, fontSize: 8,
            fontWeight: FontWeight.bold)),
  );

  Widget _infoBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
    child: Text(text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );

  Widget _infoText(IconData icon, String text, {Color? color}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 10, color: color ?? Colors.grey.shade500),
      const SizedBox(width: 2),
      Text(text, style: TextStyle(fontSize: 10, color: color ?? Colors.grey.shade500)),
    ],
  );

  String _profileLabel(String p) {
    if (p == 'H') return 'Hospital';
    if (p == 'T') return 'Trade/Clinic';
    if (p == 'HT') return 'Hospital + Trade';
    return p;
  }
}

// ── Data helpers ──────────────────────────────────────────────────────────────

enum _RowStatus { done, partial, zero, noTarget }

class _TableRow {
  final String label;
  final String? subLabel;   // speciality names shown as sub-text
  final String col2;
  final String col3;
  final _RowStatus status;
  final int? remaining;
  const _TableRow({
    required this.label,
    this.subLabel,
    required this.col2,
    required this.col3,
    required this.status,
    this.remaining,
  });
}
