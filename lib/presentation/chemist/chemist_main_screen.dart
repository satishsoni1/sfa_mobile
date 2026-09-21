import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/api_service.dart';
import '../../data/models/chemist_selection_model.dart';
import '../doctor_list/add_chemist_screen.dart';

class ChemistMainScreen extends StatefulWidget {
  final int? initialEmployeeId;

  const ChemistMainScreen({super.key, this.initialEmployeeId});

  @override
  State<ChemistMainScreen> createState() => _ChemistMainScreenState();
}

class _ChemistMainScreenState extends State<ChemistMainScreen>
    with SingleTickerProviderStateMixin {
  static const _purple = Color(0xFF4A148C);

  // ── Tabs ───────────────────────────────────────────────────────────────────
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  // ── Master List ────────────────────────────────────────────────────────────
  List<ChemistItem> _masterList = [];
  bool _isLoadingMaster = true;

  // ── Min-count quota (from summary.required_min_count) ─────────────────────
  int _requiredMinCount = 50; 

  // ── Selection State ────────────────────────────────────────────────────────
  Set<int> _selectedIds = {};
  bool _isSavingDraft = false;
  bool _isSubmitting = false;

  // ── My Approval Status ─────────────────────────────────────────────────────
  String? _approvalStatus; // null | 'pending' | 'approved' | 'rejected'
  String? _rejectionReason;
  // ignore: unused_field
  int? _approvalRequestId;

  // ── Summary Tab Filter ─────────────────────────────────────────────────────
  String _summaryFilter = 'All'; // 'All' | '4-visit' | 'normal'

  // ── Team View ──────────────────────────────────────────────────────────────
  List<dynamic> _subordinates = [];
  int? _selectedSubId;
  String? _selectedSubName;
  bool _isLoadingTeamData = false;
  bool _isApproving = false;
  bool _isRejecting = false;
  String? _subApprovalStatus;
  String? _subRejectionReason;
  List<Map<String, dynamic>> _teamChemists = [];
  int? _subApprovalRequestId;

  // ── Derived ────────────────────────────────────────────────────────────────

  List<ChemistItem> get _filteredMaster {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) return _masterList;
    return _masterList
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              (c.address ?? '').toLowerCase().contains(q) ||
              (c.contactPerson ?? '').toLowerCase().contains(q) ||
              (c.pincode ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  List<ChemistItem> get _selectedChemists =>
      _masterList.where((c) => _selectedIds.contains(c.chemistId)).toList();

  List<ChemistItem> get _filteredSelectedChemists {
    if (_summaryFilter == 'All') return _selectedChemists;
    return _selectedChemists
        .where((c) => c.category == _summaryFilter)
        .toList();
  }

  int get _selectedCount => _selectedIds.length;
  int get _fourVisitCount =>
      _selectedChemists.where((c) => c.category == '4-visit').length;
  int get _generalCount =>
      _selectedChemists.where((c) => c.category == 'normal').length;

  bool get _isListLocked =>
      _approvalStatus == 'pending' || _approvalStatus == 'approved';

  // ── Builds the payload list for save-draft ────────────────────────────────
  /// Payload per-item: { chemist_id, source, category?, is_selected }
  List<Map<String, dynamic>> _buildDraftPayload() {
    return _masterList
        .map(
          (c) => {
            'chemist_id': c.chemistId,
            'source': c.source,
            if (c.category.isNotEmpty) 'category': c.category,
            'is_selected': _selectedIds.contains(c.chemistId),
          },
        )
        .toList();
  }

  /// Payload per-item: { chemist_id, name, source, category, is_selected }
  /// Only sends the selected chemists (is_selected: true)
  List<Map<String, dynamic>> _buildSubmitPayload() {
    return _selectedChemists
        .map(
          (c) => {
            'chemist_id': c.chemistId,
            'name': c.name,
            'source': c.source,
            'category': c.category,
            'is_selected': true,
          },
        )
        .toList();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialEmployeeId != null) _tabController.index = 2;
    _tabController.addListener(() => setState(() {}));
    _searchCtrl.addListener(() => setState(() {}));
    _loadMasterList();
    _loadSubordinates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data Loading ───────────────────────────────────────────────────────────

  Future<void> _loadMasterList() async {
    setState(() => _isLoadingMaster = true);
    try {
      final data = await ApiService().getChemistMasterList();
      if (!mounted) return;
      final summaryRaw = data['summary'];
      final chemistsRaw = data['chemists'];
      final summary = summaryRaw is Map<String, dynamic>
          ? ChemistMasterSummary.fromJson(summaryRaw)
          : null;
      final items = (chemistsRaw is List)
          ? chemistsRaw
                .map((c) => ChemistItem.fromJson(c as Map<String, dynamic>))
                .toList()
          : <ChemistItem>[];
      setState(() {
        _masterList = items;
        _selectedIds = items
            .where((c) => c.isSelected)
            .map((c) => c.chemistId)
            .toSet();
        _approvalStatus = summary?.uiStatus;
        _rejectionReason = summary?.rejectionReason;
        _approvalRequestId = summary?.requestId;
        if (summary != null) {
          _requiredMinCount = summary.requiredMinCount;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load chemist list: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoadingMaster = false);
  }

  Future<void> _loadSubordinates() async {
    try {
      final list = await ApiService().getSubordinates();
      int? autoSelectId;
      String? autoSelectName;
      if (widget.initialEmployeeId != null) {
        for (final sub in list) {
          final id = int.tryParse(sub['id']?.toString() ?? '');
          if (id == widget.initialEmployeeId) {
            autoSelectId = id;
            autoSelectName = sub['name']?.toString();
            break;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _subordinates = list;
        if (autoSelectId != null) {
          _selectedSubId = autoSelectId;
          _selectedSubName = autoSelectName;
        }
      });
      if (_selectedSubId != null) _loadTeamData(_selectedSubId!);
    } catch (_) {}
  }

  Future<void> _loadTeamData(int subId) async {
    setState(() {
      _isLoadingTeamData = true;
      _subApprovalStatus = null;
      _subRejectionReason = null;
      _teamChemists = [];
      _subApprovalRequestId = null;
    });
    try {
      // GET /chemists/approvals?employee_id=<subId>
      final data = await ApiService().getChemistApprovalByEmployee(subId);
      if (!mounted) return;

      // The API returns a single data object — parse it directly
      final status =
          data['approval_status']?.toString() ??
          data['status']?.toString() ??
          '';
      final requestId = data['request_id'] is int
          ? data['request_id'] as int
          : int.tryParse(data['request_id']?.toString() ?? '');
      // request.id is the ID used for approve/reject actions
      final requestObj = data['request'];
      final actionId = requestObj is Map
          ? (requestObj['id'] is int
                ? requestObj['id'] as int
                : int.tryParse(requestObj['id']?.toString() ?? ''))
          : requestId;

      final chemistsRaw = data['chemists'];

      setState(() {
        _subApprovalStatus = _parseSubStatus({'status': status});
        _subRejectionReason = data['rejection_reason']?.toString();
        _subApprovalRequestId = actionId ?? requestId;
        _teamChemists = (chemistsRaw is List)
            ? chemistsRaw
                  .map((c) => Map<String, dynamic>.from(c as Map))
                  .toList()
            : [];
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _subApprovalStatus = null;
          _teamChemists = [];
        });
      }
    }
    if (mounted) setState(() => _isLoadingTeamData = false);
  }

  String? _parseSubStatus(Map<String, dynamic> approval) {
    final s = approval['status']?.toString().toLowerCase() ?? '';
    if (s == 'pending' || s == 'submitted') return 'pending';
    if (s == 'approved') return 'approved';
    if (s == 'rejected') return 'rejected';
    return null;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    setState(() => _isSavingDraft = true);
    try {
      await ApiService().saveChemistDraft(_buildDraftPayload());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save draft: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSavingDraft = false);
  }

  Future<void> _submitForApproval() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.send_outlined, color: _purple),
            SizedBox(width: 10),
            Text(
              'Submit for Approval',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Submit your selection of ${_selectedIds.length} chemist(s) for manager approval?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isSubmitting = true);
    try {
      await ApiService().submitChemistListForApproval(_buildSubmitPayload());
      if (mounted) {
        setState(() => _approvalStatus = 'pending');
        await _loadMasterList();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chemist list submitted for approval!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.startsWith('Exception: ')) {
          msg = msg.replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _approveChemistList() async {
    if (_subApprovalRequestId == null) return;
    setState(() => _isApproving = true);
    try {
      await ApiService().approveChemistRequest(
        _subApprovalRequestId!,
        employeeId: _selectedSubId,
      );
      if (mounted) {
        setState(() => _subApprovalStatus = 'approved');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chemist list approved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        title: Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red.shade600),
            const SizedBox(width: 10),
            const Text(
              'Reject List',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for rejection:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, reasonCtrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    await _rejectChemistList(reason);
  }

  Future<void> _rejectChemistList(String reason) async {
    if (_subApprovalRequestId == null) return;
    setState(() => _isRejecting = true);
    try {
      await ApiService().rejectChemistRequest(
        _subApprovalRequestId!,
        reason: reason,
        employeeId: _selectedSubId,
      );

      if (mounted) {
        setState(() {
          _subApprovalStatus = 'rejected';
          _subRejectionReason = reason;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chemist list rejected.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isRejecting = false);
  }

  // ── Subordinate Picker — vertical bottom sheet ────────────────────────────

  void _showSubordinatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline, color: _purple, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Select Team Member',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _purple,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: Colors.grey.shade200, height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _subordinates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final sub = _subordinates[i];
                    final id = int.tryParse(sub['id']?.toString() ?? '0') ?? 0;
                    final name = sub['name']?.toString() ?? 'Unknown';
                    final isSelected = _selectedSubId == id;
                    final initial = name.isNotEmpty
                        ? name[0].toUpperCase()
                        : '?';
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedSubId = id;
                          _selectedSubName = name;
                        });
                        _loadTeamData(id);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _purple.withValues(alpha: 0.06)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? _purple.withValues(alpha: 0.4)
                                : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isSelected
                                  ? _purple.withValues(alpha: 0.15)
                                  : Colors.grey.shade100,
                              child: Text(
                                initial,
                                style: TextStyle(
                                  color: isSelected
                                      ? _purple
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isSelected
                                      ? _purple
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: _purple,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (_isListLocked)
      return true; 

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(
          0xFFEBE6ED,
        ), 
        title: const Text('Save Changes?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Do you want to save your selected chemists before exiting?',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop(false); // Close dialog
                await _saveDraft(); // Save draft
                if (mounted) Navigator.of(context).pop(); // Then exit screen
              },
              child: const Text(
                'Save & Exit',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(true), 
                  child: const Text(
                    'Exit without saving',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false), 
                  child: const Text('Cancel', style: TextStyle(color: _purple)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: NestedScrollView(
          headerSliverBuilder: (_, _) => [
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Chemist Master List',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_business),
                  tooltip: 'Add Chemist',
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const AddChemistScreen(showAddArea: false),
                      ),
                    );
                    if (result == true && mounted) {
                      _loadMasterList();
                    }
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 52, 16, 52),
                        child: Row(
                          children: [
                            _statPill(
                              Icons.check_circle_outline,
                              _isLoadingMaster ? '—' : '$_selectedCount',
                              'Total selected',
                            ),
                            const SizedBox(width: 8),
                            _statPill(
                              Icons.repeat_rounded,
                              _isLoadingMaster ? '—' : '$_fourVisitCount',
                              '4-Visit',
                            ),
                            const SizedBox(width: 8),
                            _statPill(
                              Icons.local_pharmacy_outlined,
                              _isLoadingMaster ? '—' : '$_generalCount',
                              'General',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Chemist'),
                  Tab(text: 'Summary'),
                  Tab(text: 'Team View'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildChemistTab(),
              _buildSummaryTab(),
              _buildTeamViewTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stat Pill ──────────────────────────────

  Widget _statPill(IconData icon, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1 — CHEMIST LIST
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildChemistTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search chemists…',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey.shade400,
                size: 20,
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _searchCtrl.clear()),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (!_isLoadingMaster)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: _buildChemistTabActions(),
          ),
        Expanded(
          child: _isLoadingMaster
              ? const Center(child: CircularProgressIndicator())
              : _filteredMaster.isEmpty
              ? _emptyState(Icons.local_pharmacy_outlined, 'No chemists found')
              : RefreshIndicator(
                  onRefresh: _loadMasterList,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    itemCount: _filteredMaster.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _buildChemistCard(_filteredMaster[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildChemistTabActions() {
    if (_approvalStatus == 'approved') {
      return _statusBanner(
        icon: Icons.verified,
        color: Colors.green,
        title: 'List Approved!',
        subtitle: 'Your chemist list has been approved by your manager.',
      );
    }
    if (_approvalStatus == 'pending') {
      return _statusBanner(
        icon: Icons.hourglass_empty,
        color: Colors.blue,
        title: 'Pending Approval',
        subtitle: 'Your chemist list is submitted and awaiting manager review.',
      );
    }
    if (_approvalStatus == 'rejected') {
      return Column(
        children: [
          _statusBanner(
            icon: Icons.cancel,
            color: Colors.red,
            title: 'List Rejected',
            subtitle: (_rejectionReason?.isNotEmpty == true)
                ? 'Reason: $_rejectionReason'
                : 'Please update your list and re-submit.',
          ),
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSaveDraftButton(),
          ],
        ],
      );
    }
    if (_selectedIds.isNotEmpty) return _buildSaveDraftButton();
    return const SizedBox.shrink();
  }

  // ── Chemist Card ───────────────────────────────────────────────────────────

  Widget _buildChemistCard(ChemistItem chemist) {
    final isSelected = _selectedIds.contains(chemist.chemistId);
    final isFourVisit = chemist.category == '4-visit';
    final accentColor = isFourVisit ? Colors.orange : _purple;
    final initial = chemist.name.isNotEmpty
        ? chemist.name[0].toUpperCase()
        : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isListLocked
            ? null
            : () => setState(() {
                if (isSelected) {
                  _selectedIds.remove(chemist.chemistId);
                } else {
                  _selectedIds.add(chemist.chemistId);
                }
              }),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? _purple : Colors.grey.shade200,
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.06 : 0.04),
                blurRadius: isSelected ? 8 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Chemist Name [Existing] [Category] [Checkbox]
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            chemist.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ),
                        if (chemist.isExisting) ...[
                          const SizedBox(width: 6),
                          _infoChip('Existing', Colors.green),
                        ],
                        const SizedBox(width: 6),
                        if (_isListLocked)
                          _infoChip(
                            isFourVisit ? '4-Visit' : 'General',
                            accentColor,
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Gen',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: !isFourVisit
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: !isFourVisit
                                        ? _purple
                                        : Colors.grey.shade500,
                                  ),
                                ),
                                Transform.scale(
                                  scale: 0.65,
                                  child: Switch(
                                    value: isFourVisit,
                                    activeColor: Colors.orange,
                                    activeTrackColor: Colors.orange.withValues(
                                      alpha: 0.3,
                                    ),
                                    inactiveThumbColor: _purple,
                                    inactiveTrackColor: _purple.withValues(
                                      alpha: 0.2,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (val) {
                                      setState(() {
                                        final idx = _masterList.indexWhere(
                                          (c) =>
                                              c.chemistId == chemist.chemistId,
                                        );
                                        if (idx != -1) {
                                          _masterList[idx] = chemist.copyWith(
                                            category: val
                                                ? '4-visit'
                                                : 'normal',
                                          );
                                        }
                                      });
                                    },
                                  ),
                                ),
                                Text(
                                  '4-V',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isFourVisit
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isFourVisit
                                        ? Colors.orange
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 6),
                        if (!_isListLocked)
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: isSelected,
                              activeColor: _purple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (_) => setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(chemist.chemistId);
                                } else {
                                  _selectedIds.add(chemist.chemistId);
                                }
                              }),
                            ),
                          )
                        else if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: _purple,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (chemist.contactPerson?.isNotEmpty == true) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              chemist.contactPerson!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (chemist.mobile?.isNotEmpty == true) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            chemist.mobile!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (chemist.address?.isNotEmpty == true) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              chemist.address!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (chemist.pincode?.isNotEmpty == true) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.pin_drop_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'PIN: ${chemist.pincode}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveDraftButton() => SizedBox(
    width: double.infinity,
    height: 44,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: _purple,
        side: const BorderSide(color: _purple),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _isSavingDraft ? null : _saveDraft,
      icon: _isSavingDraft
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _purple),
            )
          : const Icon(Icons.save_outlined, size: 18),
      label: Text(
        _isSavingDraft
            ? 'Saving…'
            : 'Save Draft  •  ${_selectedIds.length} selected',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2 — SUMMARY
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSummaryTab() {
    final selected = _filteredSelectedChemists;
    return Column(
      children: [
        if (!_isLoadingMaster)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _buildSummaryActions(),
          ),
        if (_selectedChemists.isNotEmpty)
          Container(
            height: 46,
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              children: [
                _filterChip('All', 'All'),
                _filterChip('4-visit', '4-Visit'),
                _filterChip('normal', 'General'),
              ],
            ),
          ),
        if (_selectedChemists.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: _buildSummaryHeader(),
          ),
        Expanded(
          child: _isLoadingMaster
              ? const Center(child: CircularProgressIndicator())
              : selected.isEmpty
              ? RefreshIndicator(
                  onRefresh: _loadMasterList,
                  child: ListView(
                    children: [
                      const SizedBox(height: 80),
                      _emptyState(
                        Icons.local_pharmacy_outlined,
                        'No chemists selected yet.\nGo to the Chemist tab to make selections.',
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMasterList,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                    itemCount: selected.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _buildSummaryChemistCard(selected[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    final sel = _summaryFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: () => setState(() => _summaryFilter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: sel ? _purple : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? _purple : Colors.grey.shade300),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: sel ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryActions() {
    if (_approvalStatus == 'approved') {
      return _statusBanner(
        icon: Icons.verified,
        color: Colors.green,
        title: 'List Approved!',
        subtitle: 'Your chemist list has been approved by your manager.',
      );
    }
    if (_approvalStatus == 'pending') {
      return _statusBanner(
        icon: Icons.hourglass_empty,
        color: Colors.blue,
        title: 'Pending Approval',
        subtitle: 'Your chemist list is submitted and awaiting manager review.',
      );
    }
    if (_approvalStatus == 'rejected') {
      return Column(
        children: [
          _statusBanner(
            icon: Icons.cancel,
            color: Colors.red,
            title: 'List Rejected',
            subtitle: (_rejectionReason?.isNotEmpty == true)
                ? 'Reason: $_rejectionReason'
                : 'Please update your list and re-submit.',
          ),
          const SizedBox(height: 8),
          _buildSubmitButton(label: 'Re-submit for Approval'),
        ],
      );
    }
    return _buildSubmitButton(label: 'Submit for Approval');
  }

  Widget _buildSummaryHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _purple.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded, color: _purple, size: 18),
          const SizedBox(width: 8),
          Text(
            '${_filteredSelectedChemists.length} selected',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _purple,
            ),
          ),
          const Spacer(),
          _infoChip('4-Visit: $_fourVisitCount', Colors.orange),
          const SizedBox(width: 6),
          _infoChip('General: $_generalCount', _purple),
        ],
      ),
    );
  }

  Widget _buildSubmitButton({String label = 'Submit for Approval'}) => SizedBox(
    width: double.infinity,
    height: 48,
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      onPressed: _isSubmitting ? null : _submitForApproval,
      icon: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.send_outlined, size: 18),
      label: Text(
        _isSubmitting ? 'Submitting…' : label,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
  );

  // ── Summary Chemist Card (read-only, no right-side badge) ─────────────────

  Widget _buildSummaryChemistCard(ChemistItem chemist) {
    final isFourVisit = chemist.category == '4-visit';
    final accentColor = isFourVisit ? Colors.orange : _purple;
    final initial = chemist.name.isNotEmpty
        ? chemist.name[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        chemist.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (chemist.isExisting) ...[
                      const SizedBox(width: 6),
                      _infoChip('Existing', Colors.green),
                    ],
                    const SizedBox(width: 6),
                    _infoChip(isFourVisit ? '4-Visit' : 'General', accentColor),
                  ],
                ),
                const SizedBox(height: 6),
                if (chemist.contactPerson?.isNotEmpty == true) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          chemist.contactPerson!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                ],
                if (chemist.mobile?.isNotEmpty == true) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        chemist.mobile!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                ],
                if (chemist.address?.isNotEmpty == true) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          chemist.address!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                ],
                if (chemist.pincode?.isNotEmpty == true) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.pin_drop_outlined,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'PIN: ${chemist.pincode}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3 — TEAM VIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTeamViewTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadSubordinates();
        if (_selectedSubId != null) await _loadTeamData(_selectedSubId!);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          // Team member selector button
          if (_subordinates.isNotEmpty) ...[
            GestureDetector(
              onTap: _showSubordinatePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedSubId != null
                        ? _purple.withValues(alpha: 0.4)
                        : Colors.grey.shade300,
                    width: _selectedSubId != null ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _selectedSubId != null
                          ? _purple.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                      child: Icon(
                        Icons.person_outline,
                        size: 18,
                        color: _selectedSubId != null
                            ? _purple
                            : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedSubName ?? 'Select team member',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _selectedSubId != null
                              ? Colors.grey.shade800
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _selectedSubId != null
                          ? _purple
                          : Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Approval banner + action buttons
          if (_selectedSubId != null) ...[
            _buildSubApprovalBanner(),
            if (_subApprovalStatus == 'pending') ...[
              const SizedBox(height: 8),
              _buildApprovalButtons(),
            ],
            const SizedBox(height: 8),
          ],
          _buildSectionHeader(
            _selectedSubId == null
                ? 'Select a team member above'
                : '${_teamChemists.length} Chemists',
          ),
          if (_isLoadingTeamData)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_selectedSubId == null)
            _emptyState(
              Icons.people_outline,
              'Tap "Select team member" above to view their chemists',
            )
          else if (_teamChemists.isEmpty)
            _emptyState(
              Icons.local_pharmacy_outlined,
              'No chemists found for this team member',
            )
          else
            ..._teamChemists.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTeamChemistCard(c),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubApprovalBanner() {
    if (_subApprovalStatus == null) {
      return _statusBanner(
        icon: Icons.info_outline,
        color: Colors.orange,
        title: 'Not Submitted',
        subtitle: 'This team member has not submitted their chemist list yet.',
      );
    }
    switch (_subApprovalStatus) {
      case 'approved':
        return _statusBanner(
          icon: Icons.verified,
          color: Colors.green,
          title: 'List Approved',
          subtitle: 'This chemist list has been approved.',
        );
      case 'pending':
        return _statusBanner(
          icon: Icons.hourglass_empty,
          color: Colors.blue,
          title: 'Pending Approval',
          subtitle: 'List submitted and awaiting your review.',
        );
      default:
        return _statusBanner(
          icon: Icons.cancel,
          color: Colors.red,
          title: 'Previously Rejected',
          subtitle: (_subRejectionReason?.isNotEmpty == true)
              ? 'Reason: $_subRejectionReason'
              : 'This chemist list was rejected.',
        );
    }
  }

  Widget _buildApprovalButtons() => Row(
    children: [
      Expanded(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isApproving || _isRejecting ? null : _approveChemistList,
          icon: _isApproving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline, size: 18),
          label: Text(
            _isApproving ? 'Approving…' : 'Approve',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isApproving || _isRejecting ? null : _showRejectDialog,
          icon: _isRejecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.cancel_outlined, size: 18),
          label: Text(
            _isRejecting ? 'Rejecting…' : 'Reject',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ],
  );

  Widget _buildTeamChemistCard(Map<String, dynamic> c) {
    final name = c['name']?.toString() ?? 'Unknown Chemist';
    final category = c['category']?.toString() ?? 'normal';
    final isFourVisit = category == '4-visit';
    final accentColor = isFourVisit ? Colors.orange : _purple;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final address = c['address']?.toString().trim();
    final mobile = c['mobile']?.toString().trim();
    final contactPerson = c['contact_person']?.toString().trim();
    final pincode = c['pincode']?.toString().trim();
    final action = c['action']?.toString().trim();
    final isExisting = c['is_existing'] == true ||
        c['is_existing'] == 1 ||
        c['is_existing'] == 'true' ||
        c['is_existing'] == '1';
    final source =
        c['source']?.toString().trim() ?? c['source_table']?.toString().trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isExisting)
                      _infoChip('Existing', Colors.green)
                    else
                      _infoChip('Added', Colors.blue),
                    const SizedBox(width: 6),
                    _infoChip(isFourVisit ? '4-Visit' : 'General', accentColor),
                  ],
                ),
                const SizedBox(height: 6),
                if (contactPerson != null && contactPerson.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          contactPerson,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (mobile != null && mobile.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        mobile,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (address != null && address.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (pincode != null && pincode.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.pin_drop_outlined,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PIN: $pincode',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (action != null &&
                    action.isNotEmpty &&
                    action.toLowerCase() != 'retain' &&
                    action.toLowerCase() != 'add' &&
                    action.toLowerCase() != 'added') ...[
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [_infoChip(action.toUpperCase(), Colors.blue)],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS — exact BBA equivalents
  // ══════════════════════════════════════════════════════════════════════════

  Widget _infoChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
    ),
  );

  Widget _statusBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildSectionHeader(String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
      ],
    ),
  );

  Widget _emptyState(IconData icon, String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(
          msg,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, height: 1.5),
        ),
      ],
    ),
  );
}
