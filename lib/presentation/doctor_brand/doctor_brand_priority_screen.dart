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
  String _activeFilter = 'all'; // all | mapped | unmapped | pathfinder
  String _activeSpeciality = 'All';
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
        _activeSpeciality = 'All';
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
      // 1. Fetch brands
      final brandRes = await ApiService().getDoctorBrandPriorityBrands();
      final brandData = brandRes['data'] as Map<String, dynamic>? ?? {};
      final brandsList = (brandData['brands'] as List? ?? [])
          .map((b) => BrandPriorityBrand.fromJson(Map<String, dynamic>.from(b)))
          .toList();
      final minBrands = brandData['min_required_brands'] as int? ?? 8;

      // 2. Fetch doctors
      final docRes = await ApiService().getDoctorBrandPriorityDoctors();
      final docData = docRes['data'] as Map<String, dynamic>? ?? {};

      final doctorsList = (docData['doctors'] as List? ?? [])
          .map((d) => MclDoctorPriority.fromJson(Map<String, dynamic>.from(d)))
          .toList();

      final summary = docData['summary'] is Map<String, dynamic>
          ? PrioritySummary.fromJson(docData['summary'])
          : null;

      final emp = docData['employee'] is Map<String, dynamic>
          ? PriorityEmployeeInfo.fromJson(docData['employee'])
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
      // 1. Fetch brands with userId
      final brandRes = await ApiService().getDoctorBrandPriorityBrands(userId: subId);
      final brandData = brandRes['data'] as Map<String, dynamic>? ?? {};
      final brandsList = (brandData['brands'] as List? ?? [])
          .map((b) => BrandPriorityBrand.fromJson(Map<String, dynamic>.from(b)))
          .toList();
      final minBrands = brandData['min_required_brands'] as int? ?? 8;

      // 2. Fetch doctors with userId
      final docRes = await ApiService().getDoctorBrandPriorityDoctors(userId: subId);
      final docData = docRes['data'] as Map<String, dynamic>? ?? {};

      final doctorsList = (docData['doctors'] as List? ?? [])
          .map((d) => MclDoctorPriority.fromJson(Map<String, dynamic>.from(d)))
          .toList();

      final summary = docData['summary'] is Map<String, dynamic>
          ? PrioritySummary.fromJson(docData['summary'])
          : null;

      final emp = docData['employee'] is Map<String, dynamic>
          ? PriorityEmployeeInfo.fromJson(docData['employee'])
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
      if (_activeFilter == 'pathfinder' && doc.pathfinderBrandCount <= 0 && doc.pathfinderBrands.isEmpty) {
        return false;
      }

      if (_activeSpeciality != 'All' &&
          doc.speciality.toLowerCase() != _activeSpeciality.toLowerCase()) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final nameMatch = doc.doctorName.toLowerCase().contains(_searchQuery);
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

  List<String> _getSpecialitiesList({required bool isTeam}) {
    final list = isTeam ? _teamDoctors : _myDoctors;
    final set = <String>{'All'};
    for (final doc in list) {
      if (doc.speciality.trim().isNotEmpty) {
        set.add(doc.speciality.trim());
      }
    }
    return set.toList();
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
            'Cannot submit: $remaining MCL doctor(s) are not prioritized yet. All active approved MCL doctors must be prioritized before submission.',
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
          'You have prioritized all ${summary.totalMclDoctors} MCL doctors.\n\nAre you sure you want to submit your brand priorities to your Line Manager for review and approval?',
          style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Submit Now',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final res = await ApiService().submitDoctorBrandPriority();
      final msg = res['message']?.toString() ?? 'Doctor brand priorities submitted successfully!';
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
            Text(
              'Approve Priorities',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Approve all pending doctor brand priorities for $subName?',
          style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
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
            child: Text('Approve', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
          SnackBar(content: Text(msg, style: GoogleFonts.poppins()), backgroundColor: Colors.green),
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
            Text(
              'Reject Priorities',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a remark / reason for rejecting the priorities for $subName:',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
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
                    content: Text('Please enter a rejection reason.', style: GoogleFonts.poppins()),
                    backgroundColor: Colors.orange.shade800,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text('Reject', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
          SnackBar(content: Text(msg, style: GoogleFonts.poppins()), backgroundColor: Colors.orange.shade800),
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

  Widget _statPill(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 13),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 9.5,
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
            expandedHeight: hasSubordinates ? 165 : 125,
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
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
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
                      padding: EdgeInsets.fromLTRB(16, 44, 16, hasSubordinates ? 52 : 12),
                      child: Row(
                        children: [
                          _statPill(
                            Icons.people_outline,
                            '${activeSummary?.totalMclDoctors ?? 0}',
                            'Total MCL',
                          ),
                          const SizedBox(width: 6),
                          _statPill(
                            Icons.check_circle_outline,
                            '${activeSummary?.prioritizedDoctors ?? 0}',
                            'Prioritised',
                          ),
                          const SizedBox(width: 6),
                          _statPill(
                            Icons.pending_actions_outlined,
                            '${activeSummary?.pendingDoctors ?? 0}',
                            'Pending',
                          ),
                          const SizedBox(width: 6),
                          _statPill(
                            Icons.verified_outlined,
                            '${activeSummary?.approvedDoctors ?? 0}',
                            'Approved',
                          ),
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
                    unselectedLabelColor: Colors.white60,
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
      final pendingCount = _teamSummary?.pendingDoctors ??
          _teamDoctors.where((d) => d.isPending).length;

      if (pendingCount > 0 || _teamDoctors.any((d) => d.isPrioritized && !d.isApproved)) {
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                offset: const Offset(0, -2),
                blurRadius: 6,
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSubmitting ? null : _rejectSubordinatePriorities,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(
                        'Reject',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: _isSubmitting ? null : _approveSubordinatePriorities,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                      label: Text(
                        'Approve All',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.green.shade50,
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified, color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'All MCL doctor brand priorities are approved!',
                style: GoogleFonts.poppins(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (hasPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.blue.shade50,
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'Submitted for approval. Awaiting Line Manager review.',
                style: GoogleFonts.poppins(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
              backgroundColor: allPrioritized ? _purple : Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: allPrioritized ? 2 : 0,
            ),
            onPressed: allPrioritized && !_isSubmitting ? _submitForApproval : null,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    allPrioritized ? Icons.send_rounded : Icons.lock_outline,
                    size: 18,
                    color: Colors.white,
                  ),
            label: Text(
              allPrioritized
                  ? 'Submit All (${summary?.totalMclDoctors}) for Approval'
                  : 'Prioritise All Doctors to Submit (${summary?.prioritizedDoctors ?? 0}/${summary?.totalMclDoctors ?? 0})',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorPrioritiesTab({required bool isTeam}) {
    final isLoading = isTeam ? _isLoadingTeam : _isLoadingMy;
    final error = isTeam ? _teamError : _myError;
    final summary = isTeam ? _teamSummary : _mySummary;
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
        // Subordinate Picker Banner (if in Team Tab)
        if (isTeam) _buildSubordinateSelectorBanner(),

        // Search & Filter Bar
        _buildSearchAndFilterBar(isTeam: isTeam),

        // Doctor List
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _purple),
                )
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
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                            itemCount: filteredDocs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, idx) {
                              final doc = filteredDocs[idx];
                              return _buildDoctorCard(
                                doctor: doc,
                                availableBrands: availableBrands,
                                minRequiredBrands: minRequired,
                                isTeam: isTeam,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.white,
      child: InkWell(
        onTap: _openSubordinatePicker,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE7F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _purple.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _purple,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                        [desig, hq].where((s) => s.isNotEmpty).join(' • '),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down_rounded, color: _purple, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar({required bool isTeam}) {
    final specialities = _getSpecialitiesList(isTeam: isTeam);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        children: [
          // Search Field
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search doctor, speciality, route, brand...',
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
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
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: const Color(0xFFF0F2F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All'),
                const SizedBox(width: 6),
                _buildFilterChip('mapped', 'Prioritised'),
                const SizedBox(width: 6),
                _buildFilterChip('unmapped', 'Unmapped'),
                const SizedBox(width: 6),
                _buildFilterChip('pathfinder', 'Pathfinder'),
                if (specialities.length > 2) ...[
                  const SizedBox(width: 8),
                  Container(height: 18, width: 1, color: Colors.grey.shade300),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _activeSpeciality,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, size: 18, color: _purple),
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _purple,
                    ),
                    items: specialities.map((sp) {
                      return DropdownMenuItem<String>(
                        value: sp,
                        child: Text(sp),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _activeSpeciality = val);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _purple : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _purple : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
    final initial = doctor.doctorName.isNotEmpty ? doctor.doctorName[0].toUpperCase() : 'D';

    return InkWell(
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: doctor.isRejected
                ? Colors.red.shade200
                : doctor.isApproved
                    ? Colors.green.shade200
                    : Colors.grey.shade200,
            width: doctor.isRejected || doctor.isApproved ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Doctor Name + Pathfinder Badge + Status Chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFEDE7F6),
                  child: Text(
                    initial,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _purple,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Pathfinder Badge BEFORE Doctor Name
                          if (doctor.pathfinderBrandCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bolt, size: 12, color: Colors.deepOrange),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${doctor.pathfinderBrandCount} PF',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.deepOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              doctor.doctorName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (doctor.speciality.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE7F6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                doctor.speciality,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: _purple,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (doctor.qualification != null && doctor.qualification!.isNotEmpty) ...[
                            Text(
                              doctor.qualification!,
                              style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (doctor.routeName != null && doctor.routeName!.isNotEmpty)
                            Expanded(
                              child: Text(
                                doctor.routeName!,
                                style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey.shade500),
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
                _buildStatusChip(doctor),
              ],
            ),
            const SizedBox(height: 8),

            // Mandatory Pathfinder Brands (if any)
            if (doctor.pathfinderBrands.isNotEmpty) ...[
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      'Mandatory PF:',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepOrange.shade800,
                      ),
                    ),
                  ),
                  ...doctor.pathfinderBrands.map((b) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          b,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepOrange,
                          ),
                        ),
                      )),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Priority Pills (P1..Pn)
            if (doctor.priorities.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: doctor.priorities.take(6).map((p) {
                    final isPf = doctor.pathfinderBrands.any((pf) =>
                        pf.trim().toLowerCase() == p.brandCluster.trim().toLowerCase());

                    return Container(
                      margin: const EdgeInsets.only(right: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isPf ? Colors.orange.shade50 : const Color(0xFFEDE7F6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isPf ? Colors.orange.shade200 : const Color(0xFFCE93D8),
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
                  }).toList()
                    ..addAll(
                      doctor.priorities.length > 6
                          ? [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+${doctor.priorities.length - 6} more',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ]
                          : [],
                    ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Not prioritised yet (Min. $minRequiredBrands brands required)',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Rejection reason banner
            if (doctor.isRejected && doctor.rejectionReason != null && doctor.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cancel, size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reason: ${doctor.rejectionReason!}',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 6),
            // Bottom Chevron Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  isEditable ? 'Tap to edit priorities' : 'Tap to view priorities',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isEditable ? _purple : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
                  color: isEditable ? _purple : Colors.grey.shade500,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(MclDoctorPriority doctor) {
    Color bg;
    Color border;
    Color fg;
    String label;

    if (doctor.isApproved) {
      bg = Colors.green.shade50;
      border = Colors.green.shade200;
      fg = Colors.green.shade800;
      label = 'APPROVED';
    } else if (doctor.isPending) {
      bg = Colors.blue.shade50;
      border = Colors.blue.shade200;
      fg = Colors.blue.shade800;
      label = 'PENDING';
    } else if (doctor.isRejected) {
      bg = Colors.red.shade50;
      border = Colors.red.shade200;
      fg = Colors.red.shade800;
      label = 'REJECTED';
    } else if (doctor.isPrioritized) {
      bg = const Color(0xFFEDE7F6);
      border = const Color(0xFFCE93D8);
      fg = _purple;
      label = 'DRAFT';
    } else {
      bg = Colors.grey.shade100;
      border = Colors.grey.shade300;
      fg = Colors.grey.shade700;
      label = 'UNMAPPED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildErrorView(String error, {required bool isTeam}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Unable to load doctor brand priorities',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (isTeam) {
                  if (_selectedSubId != null) _loadTeamData(_selectedSubId!);
                } else {
                  _loadMyData();
                }
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: Text('Retry', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12.5)),
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
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No doctors found matching your search.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search query.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
