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
  bool _isLoadingBrands = true;
  bool _isLoadingSummary = false;

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

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _doctorSummary.isEmpty && !_isLoadingSummary) {
        _loadDoctorSummary();
      }
      setState(() {});
    });
    _searchCtrl.addListener(() => setState(() {}));
    _loadBrands();
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
      final brands = await ApiService().getBrands();
      if (mounted) setState(() => _brands = brands);
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
              tabs: const [Tab(text: 'Brands'), Tab(text: 'Dr. Summary')],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildBrandsTab(), _buildSummaryTab()],
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

  Widget _buildBrandCard(Map<String, dynamic> brand) {
    final name = brand['name']?.toString() ?? '';
    final division = brand['division']?.toString() ?? '';
    final count = int.tryParse(brand['doctor_count']?.toString() ?? '0') ?? 0;
    final preferredSps = _parsePreferredSpecialities(brand['preferred_specialities']);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _brandColor(name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => BrandDoctorScreen(brand: brand)));
          _loadBrands();
          if (_tabController.index == 1) _loadDoctorSummary();
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
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(children: [
                      Text('$count',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: color)),
                      Text('Drs',
                          style: TextStyle(fontSize: 9, color: color)),
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
