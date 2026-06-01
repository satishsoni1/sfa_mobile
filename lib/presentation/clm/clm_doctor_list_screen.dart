import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/models/clm_models.dart';
import '../../providers/clm_provider.dart';
import 'clm_checkin_screen.dart';
import 'clm_doctor_locations_screen.dart';
import 'clm_doctor_profile_screen.dart';

class ClmDoctorListScreen extends StatefulWidget {
  const ClmDoctorListScreen({super.key});

  @override
  State<ClmDoctorListScreen> createState() => _ClmDoctorListScreenState();
}

class _ClmDoctorListScreenState extends State<ClmDoctorListScreen>
    with SingleTickerProviderStateMixin {
  static const _purple = Color(0xFF4A148C);

  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;

  List<String> _specialities = [];
  bool _filterLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFilters());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final prov = context.read<ClmProvider>();
    final specs = await prov.getDistinctSpecialities();
    if (!mounted) return;
    setState(() {
      _specialities = specs;
      _filterLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          _buildTabBar(),
          Expanded(child: _buildTabBarView()),
        ],
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('Select Doctor',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      backgroundColor: _purple,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        Consumer<ClmProvider>(
          builder: (_, prov, child) {
            final hasFilter = prov.filterSpeciality.isNotEmpty ||
                prov.filterCategory.isNotEmpty ||
                prov.searchQuery.isNotEmpty;
            return hasFilter
                ? TextButton.icon(
                    onPressed: () {
                      prov.clearFilters();
                      _searchCtrl.clear();
                    },
                    icon: const Icon(Icons.filter_alt_off,
                        size: 16, color: Colors.white70),
                    label: const Text('Clear',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  )
                : const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  // ─── Search ───────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: _purple,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => context.read<ClmProvider>().setSearchQuery(v),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by name, speciality, hospital…',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    _searchCtrl.clear();
                    context.read<ClmProvider>().setSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  // ─── Filter Chips ─────────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _categoryChip('A', Colors.red.shade600),
            const SizedBox(width: 6),
            _categoryChip('B', Colors.orange.shade600),
            const SizedBox(width: 6),
            _categoryChip('C', Colors.blue.shade600),
            const SizedBox(width: 6),
            if (_filterLoaded) ...[
              const VerticalDivider(width: 20),
              ..._specialities.take(5).map((s) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _specialityChip(s),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String cat, Color color) {
    return Consumer<ClmProvider>(
      builder: (_, prov, child) {
        final selected = prov.filterCategory == cat;
        return GestureDetector(
          onTap: () => prov.setFilterCategory(selected ? '' : cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text('Cat $cat',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : color)),
          ),
        );
      },
    );
  }

  Widget _specialityChip(String spec) {
    return Consumer<ClmProvider>(
      builder: (_, prov, child) {
        final selected = prov.filterSpeciality == spec;
        return GestureDetector(
          onTap: () => prov.setFilterSpeciality(selected ? '' : spec),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? _purple : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? _purple : Colors.grey.shade300),
            ),
            child: Text(spec,
                style: TextStyle(
                    fontSize: 11,
                    color: selected ? Colors.white : Colors.grey.shade700)),
          ),
        );
      },
    );
  }

  // ─── Tabs ─────────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: _purple,
        unselectedLabelColor: Colors.grey.shade500,
        indicatorColor: _purple,
        labelStyle: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'All Doctors'),
          Tab(text: 'Planned Today'),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _DoctorListView(showPlannedOnly: false),
        _DoctorListView(showPlannedOnly: true),
      ],
    );
  }
}

// ─── Doctor List View ─────────────────────────────────────────────────────────

class _DoctorListView extends StatelessWidget {
  final bool showPlannedOnly;
  const _DoctorListView({required this.showPlannedOnly});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClmProvider>(
      builder: (_, prov, child) {
        if (prov.isLoadingDoctors) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = prov.filteredDoctors;
        if (showPlannedOnly) docs = docs.where((d) => d.isPlanned).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search,
                    size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                    showPlannedOnly
                        ? 'No planned doctors for today'
                        : 'No doctors found',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 14)),
                const SizedBox(height: 6),
                Text('Try adjusting filters or sync master data',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => prov.loadDoctors(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _DoctorCard(doctor: docs[i]),
          ),
        );
      },
    );
  }
}

// ─── Doctor Card ──────────────────────────────────────────────────────────────

class _DoctorCard extends StatelessWidget {
  final ClmDoctor doctor;
  const _DoctorCard({required this.doctor});

  static const _purple = Color(0xFF4A148C);

  Color get _catColor {
    switch (doctor.category.toUpperCase()) {
      case 'A':
        return Colors.red.shade600;
      case 'B':
        return Colors.orange.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBirthday = doctor.hasBirthdaySoon();
    final hasAnniversary = doctor.hasAnniversarySoon();

    return GestureDetector(
      onTap: () => _openCart(context),
      onLongPress: () => _openProfile(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: (hasBirthday || hasAnniversary)
              ? Border.all(color: Colors.pink.shade200, width: 1.5)
              : null,
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
            // Birthday / anniversary banner
            if (hasBirthday || hasAnniversary)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Text(hasBirthday ? '🎂' : '💍',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(
                    hasBirthday
                        ? 'Birthday soon – ${doctor.birthdayLabel}'
                        : 'Anniversary soon – ${doctor.anniversaryLabel}',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.pink.shade600,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _purple.withValues(alpha: 0.1),
                      child: Text(doctor.initials,
                          style: TextStyle(
                              color: _purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                    if (doctor.priority == 1)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: Colors.amber.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(doctor.name,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.black87),
                              overflow: TextOverflow.ellipsis),
                        ),
                        _catBadge(),
                      ]),
                      const SizedBox(height: 2),
                      Text(doctor.speciality,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                      if (doctor.hospital != null && doctor.hospital!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(doctor.hospital!,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.access_time,
                            size: 11, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Text(doctor.daysSinceLabel,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500)),
                        const SizedBox(width: 10),
                        if (doctor.assignedBrandIds.isNotEmpty) ...[
                          Icon(Icons.medication_outlined,
                              size: 11, color: Colors.grey.shade400),
                          const SizedBox(width: 3),
                          Text('${doctor.assignedBrandIds.length} brands',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500)),
                        ],
                        if (doctor.nextCallDate != null) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.event_outlined,
                              size: 11, color: Colors.blue.shade400),
                          const SizedBox(width: 3),
                          Text(
                            _daysUntilLabel(doctor.nextCallDate!),
                            style: TextStyle(
                                fontSize: 10, color: Colors.blue.shade500),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),

                // Info / Location / Play buttons
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _openProfile(context),
                      child: Container(
                        width: 32,
                        height: 28,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6)),
                        child: Icon(Icons.info_outline,
                            color: Colors.grey.shade500, size: 16),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _openLocations(context),
                      child: Container(
                        width: 32,
                        height: 28,
                        decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(6)),
                        child: Icon(Icons.location_on_outlined,
                            color: Colors.teal.shade600, size: 16),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _openCart(context),
                      child: Container(
                        width: 32,
                        height: 28,
                        decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6)),
                        child: Icon(Icons.play_arrow_rounded,
                            color: _purple, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _daysUntilLabel(DateTime date) {
    final diff = date.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Call today';
    if (diff == 1) return 'Call tomorrow';
    return 'Call in ${diff}d';
  }

  Widget _catBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: _catColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text('Cat ${doctor.category}',
          style: TextStyle(
              fontSize: 9,
              color: _catColor,
              fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _openLocations(BuildContext context) async {
    final prov = context.read<ClmProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: ClmDoctorLocationsScreen(doctor: doctor),
        ),
      ),
    );
  }

  Future<void> _openCart(BuildContext context) async {
    final prov = context.read<ClmProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: ClmCheckInScreen(doctor: doctor),
        ),
      ),
    );
  }

  Future<void> _openProfile(BuildContext context) async {
    final prov = context.read<ClmProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: ClmDoctorProfileScreen(doctor: doctor),
        ),
      ),
    );
  }
}
