import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/api_service.dart';
import 'brand_dr_mapping_doctor_screen.dart';


class BrandDrMappingScreen extends StatefulWidget {
  final int? initialEmployeeId;
  const BrandDrMappingScreen({super.key, this.initialEmployeeId});

  @override
  State<BrandDrMappingScreen> createState() => _BrandDrMappingScreenState();
}

class _BrandDrMappingScreenState extends State<BrandDrMappingScreen>
    with SingleTickerProviderStateMixin {
  static const _purple = Color(0xFF4A148C);

  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _doctorSummary = [];
  String? _summaryError; // set when the summary API returns an error (e.g. 403)
  List<Map<String, dynamic>> _teamBrands = [];
  List<dynamic> _subordinates = [];
  int? _selectedSubId;
  bool _isLoadingBrands = true;
  bool _isLoadingSummary = false;
  bool _isLoadingTeamBrands = false;
  int? _submittingBrandId;
  int? _approvingBrandId;
  int? _rejectingBrandId;

  String _summarySpecialityFilter = 'All';

  List<Map<String, dynamic>> get _filteredBrands {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _brands;
    return _brands.where((b) =>
        (_brandDisplayName(b)).toLowerCase().contains(q) ||
        (b['division'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  List<String> get _summarySpecialities {
    final set = <String>{'All'};
    for (final d in _doctorSummary) {
      final sp = (d['specialty_practice_type'] ?? d['speciality'])?.toString() ?? '';
      if (sp.isNotEmpty) set.add(sp);
    }
    return set.toList();
  }

  List<Map<String, dynamic>> get _filteredSummary {
    if (_summarySpecialityFilter == 'All') return _doctorSummary;
    return _doctorSummary.where((d) {
      final sp = (d['specialty_practice_type'] ?? d['speciality'])?.toString() ?? '';
      return sp == _summarySpecialityFilter;
    }).toList();
  }

  int get _totalTagCount =>
      _brands.fold(0, (s, b) => s + (int.tryParse(b['doctor_count']?.toString() ?? '0') ?? 0));

  /// Reads brand name from 'brand' field first (dr-brand-map response), falls
  /// back to 'name' so both API shapes are handled gracefully.
  String _brandDisplayName(Map<String, dynamic> b) =>
      (b['brand'] ?? b['name'])?.toString() ?? '';

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

    if (widget.initialEmployeeId != null) {
      _tabController.index = 2;
    }

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
      final brands = await ApiService().getDrBrandMapBrands(userId: user?.employeeId);
      if (mounted) {
        setState(() {
          _brands = brands;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingBrands = false);
  }

  Future<void> _loadDoctorSummary() async {
    setState(() {
      _isLoadingSummary = true;
      _summaryError = null;
    });
    try {
      final data = await ApiService().getDrBrandMapSummary();
      if (!mounted) return;
      // Check if the API returned an error sentinel
      if (data.length == 1 && data.first['__error__'] == true) {
        setState(() {
          _summaryError = data.first['message']?.toString() ?? 'Failed to load summary';
          _doctorSummary = [];
        });
      } else {
        setState(() {
          _doctorSummary = data;
          _summaryError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _summaryError = 'Failed to load summary. Please try again.');
    }
    if (mounted) setState(() => _isLoadingSummary = false);
  }

  Future<void> _loadSubordinates() async {
    try {
      final list = await ApiService().getSubordinates();

      if (widget.initialEmployeeId != null) {
        try {
          final matched = list.firstWhere((sub) => sub['id'] == widget.initialEmployeeId);
          _selectedSubId = matched['id'];
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _subordinates = list);
        if (_selectedSubId != null) {
          _loadTeamBrands(_selectedSubId!);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadTeamBrands(int userId) async {
    setState(() {
      _isLoadingTeamBrands = true;
    });
    try {
      final brands = await ApiService().getDrBrandMapBrands(userId: userId);
      if (mounted) {
        setState(() {
          _teamBrands = brands;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _teamBrands = []);
    }
    if (mounted) setState(() => _isLoadingTeamBrands = false);
  }

  String? _getBrandStatus(Map<String, dynamic> brand) {
    final raw = brand['approval_status'] ??
        brand['brand_approval_status'] ??
        brand['status'];
    final s = raw?.toString().toLowerCase().trim();
    if (s == 'submitted') return 'pending';
    if (s == 'pending' || s == 'approved' || s == 'rejected') return s;
    return null;
  }

  String? _getBrandRejectionReason(Map<String, dynamic> brand) {
    return (brand['rejection_reason'] ?? brand['reject_reason'])?.toString();
  }

  Future<void> _submitBrand(Map<String, dynamic> brand) async {
    final int brandId = int.tryParse(brand['id']?.toString() ?? '0') ?? 0;
    if (brandId <= 0) return;
    final brandName = _brandDisplayName(brand);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.send_outlined, color: _purple),
          const SizedBox(width: 10),
          Expanded(child: Text('Submit $brandName?',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
        content: Text(
          'Submit doctor mapping for "$brandName" for manager approval?',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _submittingBrandId = brandId);
    try {
      await ApiService().submitDrBrandMapApproval(brandId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$brandName submitted for approval!'),
          backgroundColor: Colors.green,
        ));
        await _loadBrands();
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString().replaceFirst('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $err'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _submittingBrandId = null);
    }
  }

  Future<void> _approveSingleBrand(int userId, Map<String, dynamic> brand) async {
    final int brandId = int.tryParse(brand['id']?.toString() ?? '0') ?? 0;
    if (brandId <= 0) return;
    final brandName = _brandDisplayName(brand);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.green),
          SizedBox(width: 10),
          Text('Approve Brand',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          'Approve doctor mapping for "$brandName"?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _approvingBrandId = brandId);
    try {
      await ApiService().approveDrBrandMap(userId, brandId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$brandName approved!'),
          backgroundColor: Colors.green,
        ));
        await _loadTeamBrands(userId);
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString().replaceFirst('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $err'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _approvingBrandId = null);
    }
  }

  Future<void> _rejectSingleBrand(int userId, Map<String, dynamic> brand) async {
    final int brandId = int.tryParse(brand['id']?.toString() ?? '0') ?? 0;
    if (brandId <= 0) return;
    final brandName = _brandDisplayName(brand);

    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.cancel_outlined, color: Colors.red.shade600),
          const SizedBox(width: 10),
          Expanded(child: Text('Reject $brandName',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide a reason for rejecting "$brandName":',
                style: const TextStyle(fontSize: 13)),
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
    if (reason == null || reason.isEmpty) return;

    setState(() => _rejectingBrandId = brandId);
    try {
      await ApiService().rejectDrBrandMap(userId, brandId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$brandName rejected.'),
          backgroundColor: Colors.orange,
        ));
        await _loadTeamBrands(userId);
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString().replaceFirst('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $err'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _rejectingBrandId = null);
    }
  }


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
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Zorberry Tab Daily Rxn List',
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
              tabs: const [Tab(text: 'Dr List'), Tab(text: 'Dr. Summary'), Tab(text: 'Team View')],
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
        Expanded(
          child: _isLoadingBrands
              ? const Center(child: CircularProgressIndicator())
              : _filteredBrands.isEmpty
                  ? _emptyState(Icons.medication_outlined, 'No brands found')
                  : RefreshIndicator(
                      onRefresh: _loadBrands,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
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
    final name = _brandDisplayName(brand);
    final division = brand['division']?.toString() ?? '';
    final count = int.tryParse(brand['doctor_count']?.toString() ?? '0') ?? 0;
    final quota = int.tryParse(brand['quota']?.toString() ?? '0') ?? 0;
    final quotaMet = quota > 0 && count >= quota;
    final preferredSps = _parsePreferredSpecialities(brand['preferred_specialities']);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _brandColor(name);

    return Container(
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
          // Tappable Card Body (Opens Doctor List)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              onTap: () => _openDoctorScreen(brand, readOnly: readOnly, targetUserId: targetUserId),
              child: Padding(
                padding: const EdgeInsets.all(14),
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
                        // Doctor count badge
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
          ),
          // Divider & Action / Status Section
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: _buildBrandCardActions(brand, readOnly: readOnly, targetUserId: targetUserId),
          ),
        ],
      ),
    );
  }

  Future<void> _openDoctorScreen(
    Map<String, dynamic> brand, {
    bool readOnly = false,
    int? targetUserId,
  }) async {
    final brandStatus = _getBrandStatus(brand);
    final isBrandLocked = readOnly || brandStatus == 'pending' || brandStatus == 'approved';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrandDrMappingDoctorScreen(
          brand: brand,
          targetUserId: targetUserId,
          readOnly: readOnly,
          isDoctorListLocked: isBrandLocked,
        ),
      ),
    );

    if (targetUserId == null) {
      _loadBrands();
      _loadDoctorSummary();
    } else {
      _loadTeamBrands(targetUserId);
    }
  }

  Widget _buildBrandCardActions(
    Map<String, dynamic> brand, {
    bool readOnly = false,
    int? targetUserId,
  }) {
    final brandId = int.tryParse(brand['id']?.toString() ?? '0') ?? 0;
    final count = int.tryParse(brand['doctor_count']?.toString() ?? '0') ?? 0;
    final quota = int.tryParse(brand['quota']?.toString() ?? '0') ?? 0;
    final status = _getBrandStatus(brand);
    final rejectionReason = _getBrandRejectionReason(brand);

    if (readOnly && targetUserId != null) {
      // ── Manager Team View actions ──
      final isApproving = _approvingBrandId == brandId;
      final isRejecting = _rejectingBrandId == brandId;
      final isBusy = isApproving || isRejecting;

      if (status == 'approved') {
        return _brandStatusBadge(
          icon: Icons.verified,
          color: Colors.green,
          label: 'Approved',
        );
      }
      if (status == 'rejected') {
        return _brandStatusBadge(
          icon: Icons.cancel,
          color: Colors.red,
          label: rejectionReason != null && rejectionReason.isNotEmpty
              ? 'Rejected: $rejectionReason'
              : 'Rejected',
        );
      }
      if (status == 'pending') {
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: isBusy ? null : () => _approveSingleBrand(targetUserId, brand),
                  icon: isApproving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(
                    isApproving ? 'Approving...' : 'Approve',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: isBusy ? null : () => _rejectSingleBrand(targetUserId, brand),
                  icon: isRejecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cancel_outlined, size: 16),
                  label: Text(
                    isRejecting ? 'Rejecting...' : 'Reject',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        );
      }

      // Not submitted yet
      return _brandStatusBadge(
        icon: Icons.info_outline,
        color: Colors.grey,
        label: 'Not submitted for approval yet ($count/$quota tagged)',
      );
    }

    // ── User My List actions ──
    final isSubmitting = _submittingBrandId == brandId;
    final bool isExactQuota = quota > 0 && count == quota;

    if (status == 'approved') {
      return _brandStatusBadge(
        icon: Icons.verified,
        color: Colors.green,
        label: 'Approved by Manager',
      );
    }

    if (status == 'pending') {
      return _brandStatusBadge(
        icon: Icons.hourglass_empty,
        color: Colors.blue,
        label: 'Pending Manager Approval',
      );
    }

    if (status == 'rejected') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _brandStatusBadge(
            icon: Icons.cancel,
            color: Colors.red,
            label: rejectionReason != null && rejectionReason.isNotEmpty
                ? 'Rejected: $rejectionReason'
                : 'Rejected — Update list and re-submit',
          ),
          const SizedBox(height: 8),
          if (isExactQuota)
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 1,
                ),
                onPressed: isSubmitting ? null : () => _submitBrand(brand),
                icon: isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_outlined, size: 15),
                label: Text(
                  isSubmitting ? 'Submitting...' : 'Re-submit for Approval',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            )
          else
            _brandQuotaHint(count: count, quota: quota),
        ],
      );
    }

    // status is unsubmitted (null)
    if (isExactQuota) {
      return SizedBox(
        width: double.infinity,
        height: 36,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 1,
          ),
          onPressed: isSubmitting ? null : () => _submitBrand(brand),
          icon: isSubmitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_outlined, size: 15),
          label: Text(
            isSubmitting ? 'Submitting...' : 'Submit for Approval',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      );
    }

    return _brandQuotaHint(count: count, quota: quota);
  }

  Widget _brandStatusBadge({
    required IconData icon,
    required MaterialColor color,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.shade700, size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandQuotaHint({required int count, required int quota}) {
    if (quota <= 0) {
      return const SizedBox.shrink();
    }
    final isShort = count < quota;
    final diff = (quota - count).abs();
    final message = isShort
        ? 'Tag $diff more doctor${diff == 1 ? '' : 's'} to submit (Target: $quota)'
        : 'Remove $diff doctor${diff == 1 ? '' : 's'} to meet exact quota ($quota)';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isShort ? Colors.orange.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isShort ? Colors.orange.shade200 : Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            isShort ? Icons.info_outline : Icons.warning_amber_rounded,
            color: isShort ? Colors.orange.shade700 : Colors.red.shade700,
            size: 15,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isShort ? Colors.orange.shade800 : Colors.red.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTab() {
    final brands = _teamBrands.where((b) {
      final q = _searchCtrl.text.toLowerCase();
      if (q.isEmpty) return true;
      return _brandDisplayName(b).toLowerCase().contains(q) ||
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


  Widget _buildSummaryTab() {
    return Column(
      children: [
        //  Error banner from API (e.g. 403 "Brand list is not approved.") 
        if (_summaryError != null)
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDoctorSummary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
                children: [
                  Container(
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
                          _summaryError!,
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
                ],
              ),
            ),
          )
        else ...[
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
    // Handle both 'specialty_practice_type' and 'speciality' field names
    final speciality = (doctor['specialty_practice_type'] ?? doctor['speciality'])?.toString() ?? '';
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
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: brands.map((brand) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        brand,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList(),
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

  // â”€â”€ Submit Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
