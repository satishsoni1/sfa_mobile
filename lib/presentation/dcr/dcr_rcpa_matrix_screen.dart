import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/models/clm_models.dart';
import '../../data/models/dcr_models.dart';
import '../../providers/dcr_provider.dart';

class DcrRcpaMatrixScreen extends StatefulWidget {
  final int chemistVisitId;

  const DcrRcpaMatrixScreen({super.key, required this.chemistVisitId});

  @override
  State<DcrRcpaMatrixScreen> createState() => _DcrRcpaMatrixScreenState();
}

class _DcrRcpaMatrixScreenState extends State<DcrRcpaMatrixScreen> {
  static const _teal = Color(0xFF00695C);
  static const _purple = Color(0xFF4A148C);

  // doctorId → list of _RcpaBrandRow
  final Map<int, List<_RcpaBrandRow>> _matrix = {};
  // Selected doctors
  final Set<int> _selectedDoctorIds = {};

  List<ClmDoctor> _doctors = [];
  List<ClmBrand> _brands = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final prov = context.read<DcrProvider>();
    _doctors = prov.doctors;
    _brands = prov.brands;

    // Load existing RCPA entries for this chemist visit
    final entries =
        await prov.getRcpaEntries(widget.chemistVisitId);

    for (final entry in entries) {
      _selectedDoctorIds.add(entry.doctorId);
      _matrix.putIfAbsent(entry.doctorId, () => []);
      final competitors =
          await prov.getRcpaCompetitors(entry.id!);
      _matrix[entry.doctorId]!.add(_RcpaBrandRow(
        entryId: entry.id,
        brand: _brands.firstWhere(
          (b) => b.id == entry.brandId,
          orElse: () => ClmBrand(
              id: entry.brandId ?? 0,
              name: entry.brandName,
              therapyArea: ''),
        ),
        rxQty: entry.rxQtyPerWeek,
        competitors: competitors
            .map((c) => _CompetitorRow(
                  id: c.id,
                  nameCtrl: TextEditingController(text: c.competitorName),
                  qty: c.salesQty,
                ))
            .toList(),
      ));
    }
    if (mounted) setState(() => _loading = false);
  }

  void _toggleDoctor(ClmDoctor doc) {
    setState(() {
      if (_selectedDoctorIds.contains(doc.id)) {
        _selectedDoctorIds.remove(doc.id);
        _matrix.remove(doc.id);
      } else {
        _selectedDoctorIds.add(doc.id);
        _matrix[doc.id] = [];
      }
    });
  }

  void _addBrand(int doctorId) {
    setState(() {
      _matrix[doctorId]!.add(_RcpaBrandRow(
        brand: _brands.isNotEmpty ? _brands.first : null,
        rxQty: 0,
        competitors: [],
      ));
    });
  }

  void _removeBrand(int doctorId, int index) {
    setState(() => _matrix[doctorId]!.removeAt(index));
  }

  void _addCompetitor(int doctorId, int brandIndex) {
    setState(() {
      _matrix[doctorId]![brandIndex].competitors.add(
        _CompetitorRow(
            nameCtrl: TextEditingController(), qty: 0),
      );
    });
  }

  void _removeCompetitor(int doctorId, int brandIndex, int compIndex) {
    setState(() =>
        _matrix[doctorId]![brandIndex].competitors.removeAt(compIndex));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prov = context.read<DcrProvider>();
    try {
      final entries = <RcpaEntryWithCompetitors>[];
      for (final doctorId in _selectedDoctorIds) {
        final doctor =
            _doctors.firstWhere((d) => d.id == doctorId);
        final rows = _matrix[doctorId] ?? [];
        for (final row in rows) {
          if (row.brand == null) continue;
          final entry = DcrRcpaEntry(
            chemistVisitId: widget.chemistVisitId,
            doctorId: doctorId,
            doctorName: doctor.name,
            brandId: row.brand!.id,
            brandName: row.brand!.name,
            rxQtyPerWeek: row.rxQty,
          );
          final comps = row.competitors
              .where((c) => c.nameCtrl.text.trim().isNotEmpty)
              .map((c) => DcrRcpaCompetitor(
                    rcpaEntryId: 0,
                    competitorName: c.nameCtrl.text.trim(),
                    salesQty: c.qty,
                  ))
              .toList();
          entries.add(RcpaEntryWithCompetitors(entry, comps));
        }
      }
      await prov.saveRcpaMatrix(
          chemistVisitId: widget.chemistVisitId, entries: entries);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('RCPA matrix saved.'),
                backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text('RCPA Matrix',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                _buildDoctorSelector(),
                const SizedBox(height: 16),
                if (_selectedDoctorIds.isEmpty)
                  _buildHint(
                      'Select doctors above to start entering RCPA data')
                else
                  ..._selectedDoctorIds
                      .map((id) => _doctors.firstWhere((d) => d.id == id))
                      .map((doc) => _buildDoctorMatrix(doc)),
              ],
            ),
      bottomNavigationBar: _selectedDoctorIds.isNotEmpty
          ? _buildBottomBar()
          : null,
    );
  }

  // ─── Doctor Selector ──────────────────────────────────────────────────────────

  Widget _buildDoctorSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.person_search_outlined, size: 16, color: _teal),
          const SizedBox(width: 8),
          Text('Select Doctors',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${_selectedDoctorIds.length} selected',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _doctors.map((doc) {
            final selected = _selectedDoctorIds.contains(doc.id);
            return FilterChip(
              label: Text(
                doc.name.split(' ').take(2).join(' '),
                style: const TextStyle(fontSize: 12),
              ),
              selected: selected,
              onSelected: (_) => _toggleDoctor(doc),
              selectedColor: _teal.withValues(alpha: 0.15),
              checkmarkColor: _teal,
              side: BorderSide(
                  color: selected
                      ? _teal.withValues(alpha: 0.5)
                      : Colors.grey.shade300),
              tooltip: '${doc.name} · ${doc.speciality}',
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ─── Doctor Matrix ────────────────────────────────────────────────────────────

  Widget _buildDoctorMatrix(ClmDoctor doc) {
    final rows = _matrix[doc.id] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _teal.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: _teal.withValues(alpha: 0.1),
            child: Text(doc.initials,
                style: TextStyle(
                    color: _teal,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
          title: Text(doc.name,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(doc.speciality,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${rows.length} brand${rows.length != 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more),
          ]),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: [
                ...List.generate(rows.length,
                    (i) => _buildBrandRow(doc.id, i, rows[i])),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _addBrand(doc.id),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Brand'),
                    style: TextButton.styleFrom(
                        foregroundColor: _teal),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Brand Row ────────────────────────────────────────────────────────────────

  Widget _buildBrandRow(int doctorId, int index, _RcpaBrandRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Brand + Rx qty row
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<ClmBrand>(
              value: _brands.contains(row.brand) ? row.brand : null,
              isExpanded: true,
              hint: const Text('Brand', style: TextStyle(fontSize: 12)),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              items: _brands
                  .map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(b.name,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (b) => setState(() => row.brand = b),
            ),
          ),
          const SizedBox(width: 10),
          // Rx qty stepper
          Column(children: [
            const Text('Rx/wk',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(children: [
              _miniBtn(
                  Icons.remove,
                  row.rxQty > 0
                      ? () => setState(() => row.rxQty--)
                      : null),
              SizedBox(
                width: 32,
                child: Text('${row.rxQty}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              _miniBtn(
                  Icons.add, () => setState(() => row.rxQty++)),
            ]),
          ]),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 16, color: Colors.red),
            onPressed: () => _removeBrand(doctorId, index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
        // Competitors
        if (row.competitors.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.compare_arrows,
                size: 12, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text('Competitors',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
          ]),
          const SizedBox(height: 6),
          ...List.generate(
              row.competitors.length,
              (ci) => _buildCompetitorRow(doctorId, index, ci,
                  row.competitors[ci])),
        ],
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _addCompetitor(doctorId, index),
          child: Row(children: [
            Icon(Icons.add_circle_outline,
                size: 14, color: _purple.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text('Add Competitor',
                style: TextStyle(
                    fontSize: 11,
                    color: _purple.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }

  // ─── Competitor Row ───────────────────────────────────────────────────────────

  Widget _buildCompetitorRow(int doctorId, int brandIndex,
      int compIndex, _CompetitorRow comp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const SizedBox(width: 4),
        Container(
          width: 3,
          height: 28,
          decoration: BoxDecoration(
            color: _purple.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: comp.nameCtrl,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Competitor brand name',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Row(children: [
          _miniBtn(
              Icons.remove,
              comp.qty > 0
                  ? () => setState(() => comp.qty--)
                  : null),
          SizedBox(
            width: 28,
            child: Text('${comp.qty}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          _miniBtn(Icons.add, () => setState(() => comp.qty++)),
        ]),
        IconButton(
          icon: const Icon(Icons.close, size: 14, color: Colors.red),
          onPressed: () =>
              _removeCompetitor(doctorId, brandIndex, compIndex),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback? onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14,
            color: onPressed != null
                ? Colors.grey.shade700
                : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildHint(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Icon(Icons.touch_app_outlined,
              size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  Widget _buildBottomBar() {
    final totalEntries = _matrix.values
        .fold<int>(0, (sum, rows) => sum + rows.length);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(
              'Save Matrix ($totalEntries entr${totalEntries != 1 ? 'ies' : 'y'})',
              style:
                  GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Local state helpers ──────────────────────────────────────────────────────

class _RcpaBrandRow {
  final int? entryId;
  ClmBrand? brand;
  int rxQty;
  final List<_CompetitorRow> competitors;

  _RcpaBrandRow({
    this.entryId,
    required this.brand,
    required this.rxQty,
    required this.competitors,
  });
}

class _CompetitorRow {
  final int? id;
  final TextEditingController nameCtrl;
  int qty;

  _CompetitorRow({this.id, required this.nameCtrl, required this.qty});
}
