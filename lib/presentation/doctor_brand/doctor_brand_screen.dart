import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/api_service.dart';
import 'brand_doctor_screen.dart';

class DoctorBrandScreen extends StatefulWidget {
  const DoctorBrandScreen({super.key});

  @override
  State<DoctorBrandScreen> createState() => _DoctorBrandScreenState();
}

class _DoctorBrandScreenState extends State<DoctorBrandScreen>
    with SingleTickerProviderStateMixin {
  static const _purple = Color(0xFF4A148C);

  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _doctorSummary = [];
  List<Map<String, dynamic>> _teamBrands = [];
  List<dynamic> _subordinates = [];
  int? _selectedSubId;
  bool _isLoadingBrands = true;
  bool _isLoadingSummary = false;
  bool _isLoadingTeamBrands = false;
  bool _isSubmitting = false;
  bool _isApproving = false;
  bool _isRejecting = false;

  String? _myApprovalStatus;
  String? _myRejectionReason;
  String? _subApprovalStatus;
  String? _subRejectionReason;

  String _summarySpecialityFilter = 'All';

  // ── Derived ──────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredBrands {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _brands;
    return _brands.where((b) =>
        (b['name'] ?? '').toString().toLowerCase().contains(q) ||
        (b['division'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  List<String> get _summarySpecialities {
    final set = <String>{'All'};
    for (final d in _doctorSummary) {
      final sp = d['speciality']?.toString() ?? '';
      if (sp.isNotEmpty) set.add(sp);
    }
    return set.toList();
  }

  List<Map<String, dynamic>> get _filteredSummary {
    if (_summarySpecialityFilter == 'All') return _doctorSummary;
    return _doctorSummary
        .where((d) => d['speciality']?.toString() == _summarySpecialityFilter)
        .toList();
  }

  int get _totalTagCount =>
      _brands.fold(0, (s, b) => s + (int.tryParse(b['doctor_count']?.toString() ?? '0') ?? 0));

  bool get _isMyListLocked =>
      _myApprovalStatus == 'pending' || _myApprovalStatus == 'approved';

  bool get _allBrandQuotasComplete =>
      _brands.isNotEmpty && _brands.every((b) {
        final quota = int.tryParse(b['quota']?.toString() ?? '0') ?? 0;
        final count = int.tryParse(b['doctor_count']?.toString() ?? '0') ?? 0;
        return quota <= 0 || count >= quota;
      });

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _doctorSummary.isEmpty && !_isLoadingSummary) {
        _loadDoctorSummary();
      }
      setState(() {});
    });
    _searchCtrl.addListener(() => setState(() {}));
    _loadBrands();
    _loadDoctorSummary();
    _loadSubordinates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    setState(() => _isLoadingBrands = true);
    try {
      final user = await ApiService().getUser();
      final brands = await ApiService().getBrands(userId: user?.employeeId);
      if (mounted) {
        setState(() {
          _brands = brands;
          _myApprovalStatus = _readApprovalStatus(brands);
          _myRejectionReason = _readRejectionReason(brands);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingBrands = false);
  }

  Future<void> _loadDoctorSummary() async {
    setState(() => _isLoadingSummary = true);
    try {
      final data = await ApiService().getDoctorBrandSummary();
      if (mounted) setState(() => _doctorSummary = data);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingSummary = false);
  }

  Future<void> _loadSubordinates() async {
    try {
      final list = await ApiService().getSubordinates();
      if (mounted) setState(() => _subordinates = list);
    } catch (_) {}
  }

  Future<void> _loadTeamBrands(int userId) async {
    setState(() {
      _isLoadingTeamBrands = true;
      _subApprovalStatus = null;
      _subRejectionReason = null;
    });
    try {
      final brands = await ApiService().getBrands(userId: userId);
      if (mounted) {
        setState(() {
          _teamBrands = brands;
          _subApprovalStatus = _readApprovalStatus(brands);
          _subRejectionReason = _readRejectionReason(brands);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _teamBrands = []);
    }
    if (mounted) setState(() => _isLoadingTeamBrands = false);
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
        content: const Text(
          'Submit brands list for manager approval?',
          style: TextStyle(fontSize: 13),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      await ApiService().submitBrandsForApproval();
      if (mounted) {
        setState(() => _myApprovalStatus = 'pending');
        await _loadBrands();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Brands list submitted for approval!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _approveBrandList() async {
    if (_selectedSubId == null) return;
    setState(() => _isApproving = true);
    try {
      await ApiService().approveBrandList(_selectedSubId!);
      if (mounted) {
        setState(() => _subApprovalStatus = 'approved');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Brands list approved!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
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
                hintText: 'Enter rejection reason...',
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
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, reasonCtrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    await _rejectBrandList(reason);
  }

  Future<void> _rejectBrandList(String reason) async {
    if (_selectedSubId == null) return;
    setState(() => _isRejecting = true);
    try {
      await ApiService().rejectBrandList(_selectedSubId!, reason);
      if (mounted) {
        setState(() {
          _subApprovalStatus = 'rejected';
          _subRejectionReason = reason;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Brands list rejected.'),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _isRejecting = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Padding(
              padding: const EdgeInsets.only(bottom: 04),
            
              child: Text(
                'Dr. Brands',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              ),
             ),
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
                          _statPill(Icons.medication_outlined, '${_brands.length}', 'Brands'),
                          const SizedBox(width: 8),
                          _statPill(Icons.people_outline, '${_doctorSummary.length}', 'Doctors'),
                          const SizedBox(width: 8),
                          _statPill(Icons.link_rounded, '$_totalTagCount', 'Total Tags'),
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
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 13),
              tabs: const [Tab(text: 'Brands'), Tab(text: 'Dr. Summary'), Tab(text: 'Team View')],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildBrandsTab(), _buildSummaryTab(), _buildTeamTab()],
        ),
      ),
    );
  }

  Widget _statPill(IconData icon, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
      ]),
    ),
  );

  // ── Brands Tab ────────────────────────────────────────────────────────────────

  Widget _buildBrandsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search brands…',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
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
        if (!_isLoadingBrands)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: _buildSubmitSection(),
          ),
        Expanded(
          child: _isLoadingBrands
              ? const Center(child: CircularProgressIndicator())
              : _filteredBrands.isEmpty
                  ? _emptyState(Icons.medication_outlined, 'No brands found')
                  : RefreshIndicator(
                      onRefresh: _loadBrands,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                        itemCount: _filteredBrands.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _buildBrandCard(_filteredBrands[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildBrandCard(
    Map<String, dynamic> brand, {
    bool readOnly = false,
    int? targetUserId,
  }) {
    final name = brand['name']?.toString() ?? '';
    final division = brand['division']?.toString() ?? '';
    final count = int.tryParse(brand['doctor_count']?.toString() ?? '0') ?? 0;
    final quota = int.tryParse(brand['quota']?.toString() ?? '0') ?? 0;
    final quotaMet = quota > 0 && count >= quota;
    final preferredSps = _parsePreferredSpecialities(brand['preferred_specialities']);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _brandColor(name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => BrandDoctorScreen(
                brand: brand,
                targetUserId: targetUserId,
                readOnly: readOnly || _isMyListLocked,
              )));
          if (targetUserId == null) {
            _loadBrands();
            _loadDoctorSummary();
          } else {
            _loadTeamBrands(targetUserId);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(initial,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + division
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        if (division.isNotEmpty)
                          Text(division,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  // Doctor count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: quotaMet ? Colors.green.shade50 : color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: quotaMet ? Border.all(color: Colors.green.shade200) : null,
                    ),
                    child: Column(children: [
                      Text(quota > 0 ? '$count/$quota' : '$count',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: quota > 0 ? 14 : 18,
                              color: quotaMet ? Colors.green.shade700 : color)),
                      Text('Drs',
                          style: TextStyle(fontSize: 9, color: quotaMet ? Colors.green.shade700 : color)),
                    ]),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
              // Preferred specialities
              if (preferredSps.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.star_rounded, size: 13, color: Colors.amber.shade700),
                      const SizedBox(width: 5),
                      Text('Preferred Speciality   ',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.w600)),
                      Expanded(
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: preferredSps
                              .map((sp) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(sp,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.amber.shade900,
                                            fontWeight: FontWeight.w500)),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamTab() {
    final brands = _teamBrands.where((b) {
      final q = _searchCtrl.text.toLowerCase();
      if (q.isEmpty) return true;
      return (b['name'] ?? '').toString().toLowerCase().contains(q) ||
          (b['division'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedSubId != null) await _loadTeamBrands(_selectedSubId!);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          if (_subordinates.isNotEmpty) ...[
            _buildSubordinatePicker(),
            const SizedBox(height: 10),
          ],
          if (_selectedSubId != null) ...[
            _buildSubApprovalBanner(),
            if (_subApprovalStatus == 'pending') ...[
              const SizedBox(height: 8),
              _buildApprovalButtons(),
            ],
            const SizedBox(height: 8),
          ],
          _buildSectionHeader(
            _selectedSubId == null ? 'Select a team member' : '${brands.length} Brands',
          ),
          if (_isLoadingTeamBrands)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_selectedSubId == null)
            _emptyState(Icons.people_outline, 'Select a team member above to view their brands')
          else if (brands.isEmpty)
            _emptyState(Icons.medication_outlined, 'No brands found for selected member')
          else
            ...brands.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildBrandCard(
                    b,
                    readOnly: true,
                    targetUserId: _selectedSubId,
                  ),
                )),
        ],
      ),
    );
  }

  // ── Dr. Summary Tab ───────────────────────────────────────────────────────────

  Widget _buildSummaryTab() {
    return Column(
      children: [
        // Speciality filter chips
        if (_doctorSummary.isNotEmpty && _summarySpecialities.length > 1)
          Container(
            height: 46,
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              children: _summarySpecialities.map((sp) {
                final sel = _summarySpecialityFilter == sp;
                return Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: GestureDetector(
                    onTap: () => setState(() => _summarySpecialityFilter = sp),
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
        // Content
        Expanded(
          child: _isLoadingSummary
              ? const Center(child: CircularProgressIndicator())
              : _doctorSummary.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _loadDoctorSummary,
                      child: ListView(children: [
                        const SizedBox(height: 80),
                        _emptyState(Icons.people_outline, 'No data yet.\nTag doctors to brands first.'),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDoctorSummary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                        itemCount: _filteredSummary.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          if (i == 0) return _buildSummaryHeader();
                          return _buildDoctorSummaryCard(_filteredSummary[i - 1]);
                        },
                      ),
                    ),
        ),
      ],
    );
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
      child: Row(children: [
        Icon(Icons.bar_chart_rounded, color: _purple, size: 18),
        const SizedBox(width: 8),
        Text('${_filteredSummary.length} doctors',
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: _purple)),
        const Spacer(),
        Text(
          _summarySpecialityFilter == 'All'
              ? 'All specialities'
              : _summarySpecialityFilter,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ]),
    );
  }

  Widget _buildDoctorSummaryCard(Map<String, dynamic> doctor) {
    final name = doctor['doctor_name']?.toString() ?? '';
    final speciality = doctor['speciality']?.toString() ?? '';
    final brandCount = int.tryParse(doctor['brand_count']?.toString() ?? '0') ?? 0;
    final brands = (doctor['brands'] as List?)?.map((e) => e.toString()).toList() ?? [];

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
              offset: const Offset(0, 1))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _purple.withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: _purple,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dr. $name',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                if (speciality.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(speciality,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
                if (brands.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    brands.join(' · '),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Text('$brandCount',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: _purple)),
              Text('Brand${brandCount == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 9, color: Colors.purple.shade400)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitSection() {
    if (_myApprovalStatus == 'approved') {
      return _statusBanner(
        icon: Icons.verified,
        color: Colors.green,
        title: 'List Approved!',
        subtitle: 'Your brands list has been approved by your manager.',
      );
    }
    if (_myApprovalStatus == 'pending') {
      return _statusBanner(
        icon: Icons.hourglass_empty,
        color: Colors.blue,
        title: 'Pending Approval',
        subtitle: 'Your brands list is submitted and awaiting manager review.',
      );
    }
    if (_myApprovalStatus == 'rejected') {
      return Column(children: [
        _statusBanner(
          icon: Icons.cancel,
          color: Colors.red,
          title: 'List Rejected',
          subtitle: (_myRejectionReason != null && _myRejectionReason!.isNotEmpty)
              ? 'Reason: $_myRejectionReason'
              : 'Please update your brands and re-submit.',
        ),
        if (_allBrandQuotasComplete) ...[
          const SizedBox(height: 8),
          _submitButton(label: 'Re-submit brands list for approval'),
        ],
      ]);
    }
    if (_allBrandQuotasComplete) {
      return Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('All brand quotas completed. Ready to submit.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
          ]),
        ),
        const SizedBox(height: 8),
        _submitButton(label: 'Submit brands list for approval'),
      ]);
    }
    return const SizedBox.shrink();
  }

  Widget _submitButton({required String label}) {
    return SizedBox(
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
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_outlined, size: 18),
        label: Text(_isSubmitting ? 'Submitting...' : label,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }

  Widget _buildSubordinatePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedSubId,
          hint: const Text('Select team member'),
          isExpanded: true,
          items: _subordinates.map((s) {
            final id = int.tryParse(s['id']?.toString() ?? '0') ?? 0;
            final name = s['name']?.toString() ?? 'Unknown';
            return DropdownMenuItem(value: id, child: Text(name));
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            setState(() => _selectedSubId = id);
            _loadTeamBrands(id);
          },
        ),
      ),
    );
  }

  Widget _buildSubApprovalBanner() {
    if (_subApprovalStatus == null) {
      return _statusBanner(
        icon: Icons.info_outline,
        color: Colors.orange,
        title: 'Not Submitted',
        subtitle: 'This team member has not submitted brands for approval yet.',
      );
    }
    switch (_subApprovalStatus) {
      case 'approved':
        return _statusBanner(
          icon: Icons.verified,
          color: Colors.green,
          title: 'List Approved',
          subtitle: 'This brands list has been approved.',
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
          subtitle: (_subRejectionReason != null && _subRejectionReason!.isNotEmpty)
              ? 'Reason: $_subRejectionReason'
              : 'This brands list was rejected.',
        );
    }
  }

  Widget _buildApprovalButtons() {
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isApproving || _isRejecting ? null : _approveBrandList,
          icon: _isApproving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline, size: 18),
          label: Text(_isApproving ? 'Approving...' : 'Approve',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isApproving || _isRejecting ? null : _showRejectDialog,
          icon: _isRejecting
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.cancel_outlined, size: 18),
          label: Text(_isRejecting ? 'Rejecting...' : 'Reject',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
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

  String? _readApprovalStatus(List<Map<String, dynamic>> brands) {
    if (brands.isEmpty) return null;
    final raw = brands.first['approval_status'] ??
        brands.first['brand_approval_status'] ??
        brands.first['status'];
    final status = raw?.toString().toLowerCase();
    if (status == 'submitted') return 'pending';
    if (status == 'pending' || status == 'approved' || status == 'rejected') return status;
    return null;
  }

  String? _readRejectionReason(List<Map<String, dynamic>> brands) {
    if (brands.isEmpty) return null;
    return (brands.first['rejection_reason'] ?? brands.first['reject_reason'])?.toString();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  List<String> _parsePreferredSpecialities(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    if (raw is String && raw.isNotEmpty) {
      return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  Color _brandColor(String name) {
    const colors = [
      Colors.purple, Colors.teal, Colors.blue, Colors.orange,
      Colors.red, Colors.green, Colors.indigo, Colors.pink,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Widget _emptyState(IconData icon, String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(msg,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, height: 1.5)),
      ],
    ),
  );
}
