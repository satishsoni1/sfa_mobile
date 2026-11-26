import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/doctor_brand_priority_models.dart';
import '../../data/services/api_service.dart';
import 'doctor_priority_editor_screen.dart';
import 'doctor_priority_subordinate_sheet.dart';

class DoctorBrandPriorityScreen extends StatefulWidget {
  final int? initialSubordinateId;

  const DoctorBrandPriorityScreen({
    super.key,
    this.initialSubordinateId,
  });

  @override
  State<DoctorBrandPriorityScreen> createState() =>
      _DoctorBrandPriorityScreenState();
}

class _DoctorBrandPriorityScreenState extends State<DoctorBrandPriorityScreen>
    with SingleTickerProviderStateMixin {
  static const Color _purple = Color(0xFF4A148C);
  static const Color _plum = Color(0xFF6A1B9A);

  TabController? _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  // Subordinates / Team
  List<dynamic> _subordinates = [];
  int? _selectedSubId;
  Map<String, dynamic>? _selectedSubordinate;

  // "My Priorities" State
  bool _isLoadingMy = true;
  String? _myError;
  List<BrandPriorityBrand> _myBrands = [];
  int _myMinRequiredBrands = 8;
  List<MclDoctorPriority> _myDoctors = [];
  PrioritySummary? _mySummary;
  PriorityEmployeeInfo? _myEmployee;

  // "Team Priorities" State
  bool _isLoadingTeam = false;
  String? _teamError;
  List<BrandPriorityBrand> _teamBrands = [];
  int _teamMinRequiredBrands = 8;
  List<MclDoctorPriority> _teamDoctors = [];
  PrioritySummary? _teamSummary;
  PriorityEmployeeInfo? _teamEmployee;

  // Filter & Search
  String _activeFilter = 'all';
  String _searchQuery = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedSubId = widget.initialSubordinateId;
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadSubordinates(),
      _loadMyData(),
    ]);
  }

  Future<void> _loadSubordinates() async {
    try {
      final now = DateTime.now();
      final list = await ApiService().getSubordinates(month: now.month, year: now.year);
      if (mounted) {
        setState(() {
          _subordinates = list;
          if (_subordinates.isNotEmpty && _tabController == null) {
            _tabController = TabController(
              length: 2,
              vsync: this,
              initialIndex: widget.initialSubordinateId != null ? 1 : 0,
            );
            _tabController!.addListener(_handleTabChange);
          }
          if (_selectedSubId != null) {
            _selectedSubordinate = _subordinates.firstWhere(
              (s) => (s['id'] ?? s['user_id'] ?? s['employee_id']) == _selectedSubId,
              orElse: () => null,
            );
          } else if (_subordinates.isNotEmpty && widget.initialSubordinateId != null) {
            _selectedSubId = _subordinates.first['id'] ??
                _subordinates.first['user_id'] ??
                _subordinates.first['employee_id'];
            _selectedSubordinate = _subordinates.first;
          }
        });

        if (_selectedSubId != null) {
          _loadTeamData(_selectedSubId!);
        }
      }
    } catch (_) {
      // Subordinates API might not be available or user is not a manager
    }
  }

  void _handleTabChange() {
    if (_tabController != null && !_tabController!.indexIsChanging) {
      setState(() {
        _searchCtrl.clear();
        _searchQuery = '';
        _activeFilter = 'all';
      });
      if (_tabController!.index == 1 && _selectedSubId != null && _teamDoctors.isEmpty) {
        _loadTeamData(_selectedSubId!);
      }
    }
  }

  Future<void> _loadMyData() async {
    setState(() {
      _isLoadingMy = true;
      _myError = null;
    });

    try {
      final brandRes = await ApiService().getDoctorBrandPriorityBrands();
      final brandData = (brandRes['data'] is Map)
          ? Map<String, dynamic>.from(brandRes['data'] as Map)
          : <String, dynamic>{};
      final rawBrands = brandData['brands'];
      final brandsList = (rawBrands is List ? rawBrands : [])
          .whereType<Map>()
          .map((b) => BrandPriorityBrand.fromJson(Map<String, dynamic>.from(b)))
          .toList();
      final minBrands = (brandData['min_required_brands'] is num)
          ? (brandData['min_required_brands'] as num).toInt()
          : (int.tryParse(brandData['min_required_brands']?.toString() ?? '') ?? 8);

      final docRes = await ApiService().getDoctorBrandPriorityDoctors();
      final docData = (docRes['data'] is Map)
          ? Map<String, dynamic>.from(docRes['data'] as Map)
          : <String, dynamic>{};
      final rawDocs = docData['doctors'];
      final doctorsList = (rawDocs is List ? rawDocs : [])
          .whereType<Map>()
          .map((d) => MclDoctorPriority.fromJson(Map<String, dynamic>.from(d)))
          .toList();

      final summary = docData['summary'] is Map
          ? PrioritySummary.fromJson(Map<String, dynamic>.from(docData['summary'] as Map))
          : null;

      final emp = docData['employee'] is Map
          ? PriorityEmployeeInfo.fromJson(Map<String, dynamic>.from(docData['employee'] as Map))
          : null;

      if (mounted) {
        setState(() {
          _myBrands = brandsList;
          _myMinRequiredBrands = minBrands;
          _myDoctors = doctorsList;
          _mySummary = summary;
          _myEmployee = emp;
          _isLoadingMy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _myError = e.toString().replaceAll('Exception:', '').trim();
          _isLoadingMy = false;
        });
      }
    }
  }

  Future<void> _loadTeamData(int subId) async {
    setState(() {
      _isLoadingTeam = true;
      _teamError = null;
    });

    try {
      final brandRes = await ApiService().getDoctorBrandPriorityBrands(userId: subId);
      final brandData = (brandRes['data'] is Map)
          ? Map<String, dynamic>.from(brandRes['data'] as Map)
          : <String, dynamic>{};
      final rawBrands = brandData['brands'];
      final brandsList = (rawBrands is List ? rawBrands : [])
          .whereType<Map>()
          .map((b) => BrandPriorityBrand.fromJson(Map<String, dynamic>.from(b)))
          .toList();
      final minBrands = (brandData['min_required_brands'] is num)
          ? (brandData['min_required_brands'] as num).toInt()
          : (int.tryParse(brandData['min_required_brands']?.toString() ?? '') ?? 8);

      final docRes = await ApiService().getDoctorBrandPriorityDoctors(userId: subId);
      final docData = (docRes['data'] is Map)
          ? Map<String, dynamic>.from(docRes['data'] as Map)
          : <String, dynamic>{};
      final rawDocs = docData['doctors'];
      final doctorsList = (rawDocs is List ? rawDocs : [])
          .whereType<Map>()
          .map((d) => MclDoctorPriority.fromJson(Map<String, dynamic>.from(d)))
          .toList();

      final summary = docData['summary'] is Map
          ? PrioritySummary.fromJson(Map<String, dynamic>.from(docData['summary'] as Map))
          : null;

      final emp = docData['employee'] is Map
          ? PriorityEmployeeInfo.fromJson(Map<String, dynamic>.from(docData['employee'] as Map))
          : null;

      if (mounted) {
        setState(() {
          _teamBrands = brandsList;
          _teamMinRequiredBrands = minBrands;
          _teamDoctors = doctorsList;
          _teamSummary = summary;
          _teamEmployee = emp;
          _isLoadingTeam = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _teamError = e.toString().replaceAll('Exception:', '').trim();
          _isLoadingTeam = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = val.trim().toLowerCase());
      }
    });
  }

  List<MclDoctorPriority> _getFilteredDoctors({required bool isTeam}) {
    final list = isTeam ? _teamDoctors : _myDoctors;
    return list.where((doc) {
      if (_activeFilter == 'mapped' && !doc.isPrioritized) return false;
      if (_activeFilter == 'unmapped' && doc.isPrioritized) return false;
      if (_activeFilter == 'pathfinder' &&
          doc.pathfinderBrandCount <= 0 &&
          doc.pathfinderBrands.isEmpty) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final nameMatch = doc.doctorName.toLowerCase().contains(_searchQuery) ||
            doc.formattedDoctorName.toLowerCase().contains(_searchQuery);
        final specMatch = doc.speciality.toLowerCase().contains(_searchQuery);
        final routeMatch = (doc.routeName ?? '').toLowerCase().contains(_searchQuery);
        final brandMatch = doc.priorities.any((p) =>
            p.brandCluster.toLowerCase().contains(_searchQuery) ||
            (p.brandName ?? '').toLowerCase().contains(_searchQuery));
        if (!nameMatch && !specMatch && !routeMatch && !brandMatch) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _submitForApproval() async {
    final summary = _mySummary;
    if (summary == null) return;

    if (summary.totalMclDoctors == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No MCL doctors found to submit.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    if (summary.prioritizedDoctors < summary.totalMclDoctors) {
      final remaining = summary.totalMclDoctors - summary.prioritizedDoctors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot submit: $remaining MCL doctor(s) are not prioritized yet.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.send_rounded, color: _purple),
            const SizedBox(width: 10),
            Text(
              'Submit for Approval',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'You have prioritized all ${summary.totalMclDoctors} MCL doctors.\n\nSubmit brand priorities to your Line Manager for review?',
          style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Submit Now',
                style:
                    GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final res = await ApiService().submitDoctorBrandPriority();
      final msg =
          res['message']?.toString() ?? 'Doctor brand priorities submitted successfully!';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
          ),
        );
        _loadMyData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to submit: ${e.toString().replaceAll("Exception:", "").trim()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _approveSubordinatePriorities() async {
    if (_selectedSubId == null) return;
    final subName = _selectedSubordinate?['name'] ??
        _selectedSubordinate?['full_name'] ??
        'this employee';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green),
            const SizedBox(width: 10),
            Text('Approve Priorities',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
        content: Text(
          'Approve all pending doctor brand priorities for $subName?',
          style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Approve',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final res = await ApiService().approveDoctorBrandPriority(_selectedSubId!);
      final msg = res['message']?.toString() ?? 'Brand priorities approved successfully!';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(msg, style: GoogleFonts.poppins()),
              backgroundColor: Colors.green),
        );
        _loadTeamData(_selectedSubId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to approve: ${e.toString().replaceAll("Exception:", "").trim()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _rejectSubordinatePriorities() async {
    if (_selectedSubId == null) return;
    final subName = _selectedSubordinate?['name'] ??
        _selectedSubordinate?['full_name'] ??
        'this employee';
    final reasonCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text('Reject Priorities',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provide a reason for rejecting priorities for $subName:',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter reason for rejection...',
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Please enter a rejection reason.', style: GoogleFonts.poppins()),
                    backgroundColor: Colors.orange.shade800,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text('Reject',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final res = await ApiService().rejectDoctorBrandPriority(
        _selectedSubId!,
        reason: reasonCtrl.text.trim(),
      );
      final msg = res['message']?.toString() ?? 'Brand priorities rejected.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(msg, style: GoogleFonts.poppins()),
              backgroundColor: Colors.orange.shade800),
        );
        _loadTeamData(_selectedSubId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to reject: ${e.toString().replaceAll("Exception:", "").trim()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openSubordinatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DoctorPrioritySubordinateSheet(
        subordinates: _subordinates,
        selectedSubId: _selectedSubId,
        primaryColor: _purple,
        onSelect: (id) {
          setState(() {
            _selectedSubId = id;
            _selectedSubordinate = _subordinates.firstWhere(
              (s) => (s['id'] ?? s['user_id'] ?? s['employee_id']) == id,
              orElse: () => null,
            );
          });
          _loadTeamData(id);
        },
      ),
    );
  }

  // ─── Stat pill for the header ────────────────────────────────────────────────
  Widget _statPill(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(height: 3),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white60,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSubordinates = _subordinates.isNotEmpty;
    final isTeam = _tabController != null && _tabController!.index == 1;
    final activeSummary = isTeam ? _teamSummary : _mySummary;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: hasSubordinates ? 170 : 130,
            pinned: true,
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(
              'Dr Brand Prioritisation',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                tooltip: 'Refresh',
                onPressed: () {
                  if (hasSubordinates && _tabController?.index == 1) {
                    if (_selectedSubId != null) _loadTeamData(_selectedSubId!);
                  } else {
                    _loadMyData();
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_purple, _plum],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          16, 0, 16, hasSubordinates ? 54 : 14),
                      child: Row(
                        children: [
                          _statPill(
                              '${activeSummary?.totalMclDoctors ?? 0}',
                              'Total MCL',
                              Icons.people_alt_outlined),
                          const SizedBox(width: 8),
                          _statPill(
                              '${activeSummary?.prioritizedDoctors ?? 0}',
                              'Prioritised',
                              Icons.format_list_numbered_rounded),
                          const SizedBox(width: 8),
                          _statPill(
                              '${activeSummary?.pendingDoctors ?? 0}',
                              'Pending',
                              Icons.hourglass_empty_rounded),
                          const SizedBox(width: 8),
                          _statPill(
                              '${activeSummary?.approvedDoctors ?? 0}',
                              'Approved',
                              Icons.verified_outlined),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            bottom: hasSubordinates && _tabController != null
                ? TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelStyle:
                        GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle:
                        GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 13),
                    tabs: const [
                      Tab(text: 'My Doctors'),
                      Tab(text: 'Team Doctors'),
                    ],
                  )
                : null,
          ),
        ],
        body: hasSubordinates && _tabController != null
            ? TabBarView(
                controller: _tabController,
                children: [
                  _buildDoctorPrioritiesTab(isTeam: false),
                  _buildDoctorPrioritiesTab(isTeam: true),
                ],
              )
            : _buildDoctorPrioritiesTab(isTeam: false),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget? _buildBottomBar() {
    final isTeam = _tabController != null && _tabController!.index == 1;

    if (isTeam) {
      if (_isLoadingTeam || _teamDoctors.isEmpty) return null;
      final pendingCount =
          _teamSummary?.pendingDoctors ?? _teamDoctors.where((d) => d.isPending).length;

      if (pendingCount > 0 || _teamDoctors.any((d) => d.isPrioritized && !d.isApproved)) {
        return _BottomActionBar(
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade700, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting ? null : _rejectSubordinatePriorities,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text('Reject',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      elevation: 0,
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting ? null : _approveSubordinatePriorities,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded,
                            size: 18, color: Colors.white),
                    label: Text('Approve All',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return null;
    }

    // "My Doctors" submit button
    if (_isLoadingMy || _myDoctors.isEmpty) return null;
    final summary = _mySummary;
    final allPrioritized = summary != null &&
        summary.totalMclDoctors > 0 &&
        summary.prioritizedDoctors >= summary.totalMclDoctors;
    final hasPending = summary != null && summary.pendingDoctors > 0;
    final allApproved = summary != null &&
        summary.totalMclDoctors > 0 &&
        summary.approvedDoctors >= summary.totalMclDoctors;

    if (allApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: Colors.green.shade50,
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_rounded, color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'All MCL doctor brand priorities are approved!',
                  style: GoogleFonts.poppins(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (hasPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: Colors.blue.shade50,
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty_rounded, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Submitted for approval. Awaiting Line Manager review.',
                  style: GoogleFonts.poppins(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _BottomActionBar(
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: allPrioritized ? _purple : Colors.grey.shade400,
            elevation: allPrioritized ? 1 : 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: allPrioritized && !_isSubmitting ? _submitForApproval : null,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(
                  allPrioritized ? Icons.send_rounded : Icons.lock_outline_rounded,
                  size: 18,
                  color: Colors.white,
                ),
          label: Text(
            allPrioritized
                ? 'Submit All (${summary?.totalMclDoctors}) for Approval'
                : 'Prioritise All Doctors First (${summary?.prioritizedDoctors ?? 0}/${summary?.totalMclDoctors ?? 0})',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorPrioritiesTab({required bool isTeam}) {
    final isLoading = isTeam ? _isLoadingTeam : _isLoadingMy;
    final error = isTeam ? _teamError : _myError;
    final availableBrands = isTeam ? _teamBrands : _myBrands;
    final minRequired = isTeam ? _teamMinRequiredBrands : _myMinRequiredBrands;
    final filteredDocs = _getFilteredDoctors(isTeam: isTeam);

    if (isTeam && _subordinates.isEmpty) {
      return Center(
        child: Text(
          'No subordinates found under your hierarchy.',
          style: GoogleFonts.poppins(color: Colors.grey.shade600),
        ),
      );
    }

    return Column(
      children: [
        if (isTeam) _buildSubordinateSelectorBanner(),
        _buildSearchAndFilterBar(),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: _purple))
              : error != null
                  ? _buildErrorView(error, isTeam: isTeam)
                  : filteredDocs.isEmpty
                      ? _buildEmptyView()
                      : RefreshIndicator(
                          color: _purple,
                          onRefresh: () async {
                            if (isTeam) {
                              if (_selectedSubId != null) {
                                await _loadTeamData(_selectedSubId!);
                              }
                            } else {
                              await _loadMyData();
                            }
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
                            itemCount: filteredDocs.length,
                            itemBuilder: (ctx, idx) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildDoctorCard(
                                  doctor: filteredDocs[idx],
                                  availableBrands: availableBrands,
                                  minRequiredBrands: minRequired,
                                  isTeam: isTeam,
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildSubordinateSelectorBanner() {
    final name = _selectedSubordinate?['name'] ??
        _selectedSubordinate?['full_name'] ??
        'Select Subordinate';
    final desig = _selectedSubordinate?['designation'] ?? '';
    final hq = _selectedSubordinate?['head_qtr'] ?? '';

    return Material(
      color: Colors.white,
      elevation: 0,
      child: InkWell(
        onTap: _openSubordinatePicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _purple,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: _purple,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (desig.isNotEmpty || hq.isNotEmpty)
                      Text(
                        [desig, hq].where((s) => s.isNotEmpty).join(' · '),
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(Icons.unfold_more_rounded, color: _purple, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search doctor, speciality, route, brand...',
                  hintStyle:
                      GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.search, size: 18, color: _purple),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  filled: true,
                  fillColor: const Color(0xFFF0F2F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('all', 'All'),
                  const SizedBox(width: 6),
                  _filterChip('mapped', 'Prioritised'),
                  const SizedBox(width: 6),
                  _filterChip('unmapped', 'Unmapped'),
                  const SizedBox(width: 6),
                  _filterChip('pathfinder', '⚡ Pathfinder'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _purple : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorCard({
    required MclDoctorPriority doctor,
    required List<BrandPriorityBrand> availableBrands,
    required int minRequiredBrands,
    required bool isTeam,
  }) {
    final isEditable = !isTeam && !doctor.isApproved;
    final cleanCoreName = doctor.cleanNameWithoutPrefix;
    final displayName = doctor.formattedDoctorName;
    final initial =
        cleanCoreName.isNotEmpty ? cleanCoreName[0].toUpperCase() : 'D';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: doctor.isRejected
              ? Colors.red.shade200
              : doctor.isApproved
                  ? Colors.green.shade200
                  : Colors.grey.shade200,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorPriorityEditorScreen(
                  doctor: doctor,
                  availableBrands: availableBrands,
                  minRequiredBrands: minRequiredBrands,
                  isReadOnly: !isEditable,
                ),
              ),
            );
            if (result == true) {
              if (isTeam && _selectedSubId != null) {
                _loadTeamData(_selectedSubId!);
              } else {
                _loadMyData();
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Doctor Header Row ────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE7F6),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: _purple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name + PF Badge AFTER name ends + Status Chip
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: const Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (doctor.pathfinderBrandCount > 0) ...[
                                      const SizedBox(width: 6),
                                      _PfBadge(count: doctor.pathfinderBrandCount),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusChip(doctor),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Speciality + Qualification row
                          if (doctor.speciality.isNotEmpty ||
                              (doctor.qualification != null &&
                                  doctor.qualification!.isNotEmpty))
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (doctor.speciality.isNotEmpty)
                                  _SpecialityPill(label: doctor.speciality),
                                if (doctor.qualification != null &&
                                    doctor.qualification!.isNotEmpty)
                                  Text(
                                    doctor.qualification!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          // Route row
                          if (doctor.routeName != null &&
                              doctor.routeName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 13, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    doctor.routeName!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 10),

                // ─── Pathfinder mandatory brands ─────────────────────
                if (doctor.pathfinderBrands.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded,
                                size: 13, color: Colors.deepOrange),
                            const SizedBox(width: 4),
                            Text(
                              'Mandatory Pathfinder (${doctor.pathfinderBrands.length})',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.deepOrange.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: doctor.pathfinderBrands.map((b) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(5),
                                border:
                                    Border.all(color: Colors.orange.shade200),
                              ),
                              child: Text(
                                b,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.deepOrange.shade800,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // ─── Priority pills (P1..Pn) ─────────────────────────
                if (doctor.priorities.isNotEmpty) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...doctor.priorities.take(6).map((p) {
                          final isPf = doctor.pathfinderBrands.any((pf) =>
                              pf.trim().toLowerCase() ==
                              p.brandCluster.trim().toLowerCase());
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isPf
                                  ? Colors.orange.shade50
                                  : const Color(0xFFEDE7F6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isPf
                                    ? Colors.orange.shade200
                                    : const Color(0xFFCE93D8),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'P${p.priorityRank}: ${p.brandCluster}',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isPf ? Colors.deepOrange : _purple,
                              ),
                            ),
                          );
                        }),
                        if (doctor.priorities.length > 6)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${doctor.priorities.length - 6} more',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Not prioritised yet · Min. $minRequiredBrands brands required',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ─── Rejection reason banner ─────────────────────────
                if (doctor.isRejected &&
                    doctor.rejectionReason != null &&
                    doctor.rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.cancel_rounded,
                            size: 15, color: Colors.red.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Rejection: ${doctor.rejectionReason!}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ─── Bottom action hint ──────────────────────────────
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (doctor.priorities.isNotEmpty)
                      Text(
                        '${doctor.priorities.length} brands mapped',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isEditable
                              ? 'Tap to edit priorities'
                              : 'Tap to view priorities',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isEditable ? _purple : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 19,
                          color: isEditable ? _purple : Colors.grey.shade500,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(MclDoctorPriority doctor) {
    Color bg;
    Color fg;
    String label;

    if (doctor.isApproved) {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
      label = 'APPROVED';
    } else if (doctor.isPending) {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade700;
      label = 'PENDING';
    } else if (doctor.isRejected) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
      label = 'REJECTED';
    } else if (doctor.isPrioritized) {
      bg = const Color(0xFFEDE7F6);
      fg = _purple;
      label = 'DRAFT';
    } else {
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade600;
      label = 'UNMAPPED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildErrorView(String error, {required bool isTeam}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, size: 40, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load doctor brand priorities',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                if (isTeam) {
                  if (_selectedSubId != null) _loadTeamData(_selectedSubId!);
                } else {
                  _loadMyData();
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
              label: Text('Retry',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No doctors found',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search or filter.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared bottom action bar container ──────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  final Widget child;
  const _BottomActionBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _PfBadge extends StatelessWidget {
  final int count;
  const _PfBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 11, color: Colors.deepOrange),
          const SizedBox(width: 2),
          Text(
            '$count PF',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.deepOrange,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecialityPill extends StatelessWidget {
  final String label;
  const _SpecialityPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7F6),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: const Color(0xFF4A148C),
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
