import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/api_service.dart';

class BrandDoctorScreen extends StatefulWidget {
  final Map<String, dynamic> brand;
  final int? targetUserId;
  final bool readOnly;
  const BrandDoctorScreen({
    super.key,
    required this.brand,
    this.targetUserId,
    this.readOnly = false,
  });

  @override
  State<BrandDoctorScreen> createState() => _BrandDoctorScreenState();
}

class _BrandDoctorScreenState extends State<BrandDoctorScreen> {
  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = true;
  String _selectedSpeciality = 'All';

  int get _brandId => int.tryParse(widget.brand['id']?.toString() ?? '0') ?? 0;
  String get _brandName => widget.brand['name']?.toString() ?? '';
  int get _quota => int.tryParse(widget.brand['quota']?.toString() ?? '0') ?? 0;
  bool get _isQuotaFull => _quota > 0 && _doctors.length >= _quota;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().getBrandDoctors(_brandId, userId: widget.targetUserId);
      if (mounted) {
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
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
    if (widget.readOnly) return;
    try {
      await ApiService().removeDoctorFromBrand(_brandId, doctorId);
      setState(() => _doctors.removeWhere(
          (d) => int.tryParse(d['id']?.toString() ?? '0') == doctorId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _openAddSheet() async {
    // Brand quota validation: once the backend quota is filled, no more doctors can be added.
    if (_isQuotaFull) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Quota already fulfilled for $_brandName ($_quota/$_quota).'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddDoctorSheet(
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
        title: Text(_brandName,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${_doctors.length} Drs',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddSheet,
              backgroundColor: const Color(0xFF4A148C),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Add Doctor',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_quota > 0)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isQuotaFull ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isQuotaFull ? Colors.green.shade200 : Colors.orange.shade200,
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        _isQuotaFull ? Icons.check_circle_outline : Icons.track_changes,
                        color: _isQuotaFull ? Colors.green.shade700 : Colors.orange.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isQuotaFull
                              ? 'Brand quota fulfilled ($_quota/$_quota)'
                              : '${_doctors.length}/$_quota doctors added',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isQuotaFull ? Colors.green.shade800 : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ]),
                  ),
                // Speciality filter chips
                if (_specialities.length > 1)
                  Container(
                    height: 48,
                    color: Colors.white,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      children: _specialities.map((sp) {
                        final sel = _selectedSpeciality == sp;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedSpeciality = sp),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: sel
                                    ? const Color(0xFF4A148C)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: sel
                                        ? const Color(0xFF4A148C)
                                        : Colors.grey.shade300),
                              ),
                              child: Text(sp,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: sel
                                          ? Colors.white
                                          : Colors.grey.shade700)),
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
                              Icon(Icons.person_search,
                                  size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                _doctors.isEmpty
                                    ? 'No doctors added yet'
                                    : 'No doctors in this speciality',
                                style:
                                    TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                            itemCount: _filtered.length + 1,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              if (i == _filtered.length) {
                                return _buildSummaryCard();
                              }
                              return _buildDoctorCard(_filtered[i]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    final name = doctor['doctor_name']?.toString() ?? '';
    final sp = doctor['specialty_practice_type']?.toString() ?? '';
    final area = doctor['area']?.toString() ?? '';
    final id = int.tryParse(doctor['id']?.toString() ?? '0') ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person, color: Color(0xFF4A148C), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (sp.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE7F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(sp,
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF4A148C),
                                fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (area.isNotEmpty)
                      Text(area,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),
          if (!widget.readOnly)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: Colors.red, size: 20),
              onPressed: () => _confirmRemove(id, name),
              tooltip: 'Remove',
            ),
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
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _removeDoctor(id);
            },
            child: const Text('Remove',
                style: TextStyle(color: Colors.white)),
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
                              color: Color(0xFF4A148C),
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
                      color: const Color(0xFF4A148C))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Add Doctor Bottom Sheet ──────────────────────────────────────────────────

class _AddDoctorSheet extends StatefulWidget {
  final int brandId;
  final int? quotaRemaining;
  final Set<int> alreadyAdded;
  const _AddDoctorSheet({
    required this.brandId,
    required this.alreadyAdded,
    required this.quotaRemaining,
  });

  @override
  State<_AddDoctorSheet> createState() => _AddDoctorSheetState();
}

class _AddDoctorSheetState extends State<_AddDoctorSheet> {
  List<Map<String, dynamic>> _allDoctors = [];
  List<Map<String, dynamic>> _filtered = [];
  final Set<int> _selected = {};
  bool _isLoading = true;
  bool _isSaving = false;
  final _searchCtrl = TextEditingController();

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
    try {
      final docs = await ApiService().getMyDoctorList();
      if (mounted) {
        setState(() {
          _allDoctors = docs
              .where((d) =>
                  !widget.alreadyAdded
                      .contains(int.tryParse(d['id']?.toString() ?? '0') ?? 0))
              .toList();
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
      _filtered = q.isEmpty
          ? _allDoctors
          : _allDoctors
              .where((d) =>
                  (d['doctor_name'] ?? '').toString().toLowerCase().contains(q) ||
                  (d['specialty_practice_type'] ?? '').toString().toLowerCase().contains(q) ||
                  (d['area'] ?? '').toString().toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _save() async {
    if (_selected.isEmpty) return;
    if (widget.quotaRemaining != null && _selected.length > widget.quotaRemaining!) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('You can add only ${widget.quotaRemaining} more doctor(s) to this brand.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ApiService().addDoctorsToBrand(widget.brandId, _selected.toList());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
                              color: Color(0xFF4A148C),
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
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name, speciality, area...',
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF4A148C)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF4A148C))),
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
                              style:
                                  TextStyle(color: Colors.grey.shade400)))
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: _filtered.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final doc = _filtered[i];
                            final id = int.tryParse(
                                    doc['id']?.toString() ?? '0') ??
                                0;
                            final name =
                                doc['doctor_name']?.toString() ?? '';
                            final sp =
                                doc['specialty_practice_type']
                                        ?.toString() ??
                                    '';
                            final area = doc['area']?.toString() ?? '';
                            final sel = _selected.contains(id);

                            return CheckboxListTile(
                              value: sel,
                              activeColor: const Color(0xFF4A148C),
                              onChanged: (v) {
                                // Prevent selecting more doctors than the remaining brand quota.
                                if (v == true &&
                                    widget.quotaRemaining != null &&
                                    _selected.length >= widget.quotaRemaining!) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('Brand quota allows only ${widget.quotaRemaining} more doctor(s).'),
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
                              title: Text(name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text('$sp${area.isNotEmpty ? ' • $area' : ''}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500)),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            );
                          },
                        ),
            ),
            // Save button
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected.isEmpty || _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A148C),
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
    );
  }
}
