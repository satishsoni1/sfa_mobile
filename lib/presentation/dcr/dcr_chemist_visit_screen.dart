import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/dcr_models.dart';
import '../../providers/dcr_provider.dart';
import 'dcr_rcpa_matrix_screen.dart';

class DcrChemistVisitScreen extends StatefulWidget {
  final DcrChemistVisit? existingVisit;

  const DcrChemistVisitScreen({super.key, this.existingVisit});

  @override
  State<DcrChemistVisitScreen> createState() => _DcrChemistVisitScreenState();
}

class _DcrChemistVisitScreenState extends State<DcrChemistVisitScreen> {
  static const _teal = Color(0xFF00695C);

  DcrChemist? _selectedChemist;
  late DateTime _startTime;
  DateTime? _endTime;
  bool _productAvailable = false;
  final _pobCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  List<DcrEmployee> _selectedEmployees = [];
  int _rcpaEntryCount = 0;
  int? _currentVisitId;

  bool _saving = false;
  bool _autoSaving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.existingVisit;
    if (v != null) {
      _startTime = v.visitStartTime;
      _endTime = v.visitEndTime;
      _productAvailable = v.productAvailable;
      _pobCtrl.text = v.pobUnits > 0 ? v.pobUnits.toString() : '';
      _remarksCtrl.text = v.remarks;
    } else {
      _startTime = DateTime.now();
      _endTime = DateTime.now();
    }
    _currentVisitId = widget.existingVisit?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingData());
  }

  @override
  void dispose() {
    _pobCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final prov = context.read<DcrProvider>();
    final v = widget.existingVisit;
    if (v != null) {
      _selectedChemist =
          prov.chemists.where((c) => c.id == v.chemistId).firstOrNull;
      if (v.id != null) {
        final emps = await prov.getChemistEmployees(v.id!);
        final entries = await prov.getRcpaEntries(v.id!);
        if (mounted) {
          setState(() {
            _selectedEmployees = emps
                .map((e) => DcrEmployee(
                      id: e.employeeId,
                      name: e.employeeName,
                      employeeCode: e.employeeCode,
                    ))
                .toList();
            _rcpaEntryCount = entries.length;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DcrProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text(
            widget.existingVisit != null
                ? 'Edit Chemist Visit'
                : 'New Chemist Visit',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _buildChemistPicker(prov),
          const SizedBox(height: 14),
          _buildVisitTimeCard(),
          const SizedBox(height: 14),
          _buildJointWorkingCard(prov),
          const SizedBox(height: 14),
          _buildProductStatusCard(),
          const SizedBox(height: 14),
          _buildRcpaCard(prov),
          const SizedBox(height: 14),
          _buildRemarksCard(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── Chemist Picker ───────────────────────────────────────────────────────────

  Widget _buildChemistPicker(DcrProvider prov) {
    return _card(
      title: 'Chemist',
      icon: Icons.store_outlined,
      color: _teal,
      trailing: TextButton.icon(
        onPressed: () => _addNewChemist(prov),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('New'),
        style: TextButton.styleFrom(
            foregroundColor: _teal,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
      child: DropdownButtonFormField<DcrChemist>(
        value: _selectedChemist,
        isExpanded: true,
        hint: const Text('Select chemist'),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        items: prov.chemists
            .map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('${c.name} (${c.area})',
                      overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (c) => setState(() => _selectedChemist = c),
      ),
    );
  }

  Future<void> _addNewChemist(DcrProvider prov) async {
    final nameCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add New Chemist',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Chemist Name *',
                border: OutlineInputBorder(),
                isDense: true),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: areaCtrl,
            decoration: const InputDecoration(
                labelText: 'Area',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: mobileCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Mobile',
                border: OutlineInputBorder(),
                isDense: true),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty && mounted) {
      final chemist = await prov.addChemist(DcrChemist(
        name: nameCtrl.text.trim(),
        area: areaCtrl.text.trim(),
        mobile: mobileCtrl.text.trim().isEmpty
            ? null
            : mobileCtrl.text.trim(),
      ));
      setState(() => _selectedChemist = chemist);
    }
  }

  // ─── Visit Time ───────────────────────────────────────────────────────────────

  Widget _buildVisitTimeCard() {
    return _card(
      title: 'Visit Time',
      icon: Icons.access_time_outlined,
      color: _teal,
      child: Row(children: [
        Expanded(
            child: _timeField('Start', _startTime,
                (t) => setState(() => _startTime = t))),
        const SizedBox(width: 12),
        Expanded(
            child: _timeField('End', _endTime,
                (t) => setState(() => _endTime = t),
                optional: true)),
      ]),
    );
  }

  Widget _timeField(String label, DateTime? value, ValueChanged<DateTime> onPick,
      {bool optional = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final now = value ?? DateTime.now();
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(now),
        );
        if (picked != null) {
          onPick(DateTime(now.year, now.month, now.day,
              picked.hour, picked.minute));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.schedule, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            Text(
              value != null
                  ? DateFormat('hh:mm a').format(value)
                  : optional ? 'Tap to set' : '--:-- --',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: value != null
                      ? const Color(0xFF1A1A2E)
                      : Colors.grey.shade400),
            ),
          ]),
        ]),
      ),
    );
  }

  // ─── Joint Working ────────────────────────────────────────────────────────────

  Widget _buildJointWorkingCard(DcrProvider prov) {
    return _card(
      title: 'Joint Working',
      icon: Icons.group_outlined,
      color: _teal,
      trailing: TextButton.icon(
        onPressed: () => _pickEmployees(prov),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add'),
        style: TextButton.styleFrom(
            foregroundColor: _teal,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
      child: _selectedEmployees.isEmpty
          ? Text('No co-workers added',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500))
          : Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _selectedEmployees
                  .map((e) => Chip(
                        label: Text(e.name,
                            style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => setState(
                            () => _selectedEmployees.remove(e)),
                        backgroundColor: _teal.withValues(alpha: 0.08),
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
    );
  }

  Future<void> _pickEmployees(DcrProvider prov) async {
    final selected = Set<DcrEmployee>.from(_selectedEmployees);
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text('Select Co-workers',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            Expanded(
              child: ListView(
                children: prov.employees
                    .map((e) => CheckboxListTile(
                          value: selected.any((s) => s.id == e.id),
                          title: Text(e.name),
                          subtitle: Text(e.designation,
                              style: TextStyle(
                                  color: Colors.grey.shade500)),
                          onChanged: (v) => setModal(() {
                            if (v == true) {
                              selected.add(e);
                            } else {
                              selected.removeWhere((s) => s.id == e.id);
                            }
                          }),
                          activeColor: _teal,
                        ))
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() =>
                        _selectedEmployees = selected.toList());
                    Navigator.pop(ctx);
                  },
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Product Status & POB ─────────────────────────────────────────────────────

  Widget _buildProductStatusCard() {
    return _card(
      title: 'Product Status & POB',
      icon: Icons.inventory_2_outlined,
      color: _teal,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Product Availability',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text('Is our product available at this chemist?',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ),
          Switch(
            value: _productAvailable,
            onChanged: (v) => setState(() => _productAvailable = v),
            activeColor: _teal,
          ),
        ]),
        const Divider(height: 20),
        TextField(
          controller: _pobCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'POB Units (Personal Order Booking)',
            hintText: 'Number of units sold/ordered',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.shopping_cart_outlined, size: 18),
            isDense: true,
          ),
        ),
      ]),
    );
  }

  // ─── RCPA Matrix ──────────────────────────────────────────────────────────────

  Widget _buildRcpaCard(DcrProvider prov) {
    return _card(
      title: 'RCPA Matrix',
      icon: Icons.grid_view_outlined,
      color: _teal,
      child: Column(children: [
        if (_rcpaEntryCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Icon(Icons.check_circle_outline, size: 16, color: _teal),
              const SizedBox(width: 6),
              Text(
                  '$_rcpaEntryCount brand entr${_rcpaEntryCount > 1 ? 'ies' : 'y'} recorded',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
          ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (_saving || _autoSaving)
                ? null
                : () => _autoSaveAndOpenRcpa(prov),
            icon: _autoSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.edit_outlined, size: 16),
            label: Text(_autoSaving
                ? 'Saving…'
                : _rcpaEntryCount == 0
                    ? 'Open RCPA Matrix'
                    : 'Edit RCPA Matrix'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _teal,
              side: BorderSide(color: _teal.withValues(alpha: 0.4)),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _autoSaveAndOpenRcpa(DcrProvider prov) async {
    int? visitId = _currentVisitId;
    if (visitId == null) {
      if (_selectedChemist == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select a chemist first.')));
        return;
      }
      setState(() => _autoSaving = true);
      try {
        final now = DateTime.now();
        final visit = DcrChemistVisit(
          id: null,
          chemistId: _selectedChemist!.id!,
          chemistName: _selectedChemist!.name,
          visitDate: DateFormat('yyyy-MM-dd').format(now),
          visitStartTime: _startTime,
          visitEndTime: _endTime,
          status: DcrVisitStatus.draft,
          productAvailable: _productAvailable,
          pobUnits: int.tryParse(_pobCtrl.text.trim()) ?? 0,
          remarks: _remarksCtrl.text.trim(),
          createdAt: now,
        );
        visitId = await prov.saveChemistVisit(visit);
        await prov.setChemistEmployees(visitId, _selectedEmployees);
        if (mounted) setState(() => _currentVisitId = visitId);
      } catch (e) {
        if (mounted) {
          setState(() => _autoSaving = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Auto-save failed: $e')));
        }
        return;
      } finally {
        if (mounted) setState(() => _autoSaving = false);
      }
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: DcrRcpaMatrixScreen(chemistVisitId: visitId!),
        ),
      ),
    );
    final entries = await prov.getRcpaEntries(visitId);
    if (mounted) setState(() => _rcpaEntryCount = entries.length);
  }

  // ─── Remarks ──────────────────────────────────────────────────────────────────

  Widget _buildRemarksCard() {
    return _card(
      title: 'Remarks',
      icon: Icons.notes_outlined,
      color: _teal,
      child: TextField(
        controller: _remarksCtrl,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'General observations, shelf share, promotions...',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  // ─── Bottom Bar ───────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
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
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => _save(DcrVisitStatus.draft),
              style: OutlinedButton.styleFrom(
                foregroundColor: _teal,
                side: BorderSide(color: _teal),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Save Draft',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed:
                  _saving ? null : () => _save(DcrVisitStatus.submitted),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('Submit',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save(DcrVisitStatus status) async {
    if (_selectedChemist == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a chemist.')));
      return;
    }
    setState(() => _saving = true);
    final prov = context.read<DcrProvider>();
    try {
      final now = DateTime.now();
      final visit = DcrChemistVisit(
        id: widget.existingVisit?.id,
        chemistId: _selectedChemist!.id!,
        chemistName: _selectedChemist!.name,
        visitDate: DateFormat('yyyy-MM-dd').format(now),
        visitStartTime: _startTime,
        visitEndTime: _endTime,
        status: status,
        productAvailable: _productAvailable,
        pobUnits: int.tryParse(_pobCtrl.text.trim()) ?? 0,
        remarks: _remarksCtrl.text.trim(),
        createdAt: widget.existingVisit?.createdAt ?? now,
      );
      final visitId = await prov.saveChemistVisit(visit);
      await prov.setChemistEmployees(visitId, _selectedEmployees);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Card shell ───────────────────────────────────────────────────────────────

  Widget _card({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    Widget? trailing,
  }) {
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
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          ?trailing,
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}
