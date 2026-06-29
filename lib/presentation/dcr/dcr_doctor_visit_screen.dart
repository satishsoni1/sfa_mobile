import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../data/models/clm_models.dart';
import '../../data/models/dcr_models.dart';
import '../../providers/dcr_provider.dart';
import 'dcr_sample_sheet_screen.dart';

// ─── Visit Type ───────────────────────────────────────────────────────────────

enum _VisitType { solo, jointWork, managerAccompanied, trainingVisit }

extension _VisitTypeX on _VisitType {
  String get label {
    switch (this) {
      case _VisitType.solo: return 'Solo Visit';
      case _VisitType.jointWork: return 'Joint Working';
      case _VisitType.managerAccompanied: return 'Manager Accompanied';
      case _VisitType.trainingVisit: return 'Training Visit';
    }
  }
  String get key {
    switch (this) {
      case _VisitType.solo: return 'solo';
      case _VisitType.jointWork: return 'joint_work';
      case _VisitType.managerAccompanied: return 'manager_accompanied';
      case _VisitType.trainingVisit: return 'training_visit';
    }
  }
  IconData get icon {
    switch (this) {
      case _VisitType.solo: return Icons.person_outlined;
      case _VisitType.jointWork: return Icons.group_outlined;
      case _VisitType.managerAccompanied: return Icons.supervisor_account_outlined;
      case _VisitType.trainingVisit: return Icons.school_outlined;
    }
  }
  static _VisitType fromKey(String k) => _VisitType.values
      .firstWhere((v) => v.key == k, orElse: () => _VisitType.solo);
}

// ─── Call Objective ───────────────────────────────────────────────────────────

enum _CallObjective { planned, routine, followUp, targetCall }

extension _CallObjectiveX on _CallObjective {
  String get label {
    switch (this) {
      case _CallObjective.planned: return 'Planned';
      case _CallObjective.routine: return 'Routine';
      case _CallObjective.followUp: return 'Follow-Up';
      case _CallObjective.targetCall: return 'Target Call';
    }
  }
  String get key {
    switch (this) {
      case _CallObjective.planned: return 'planned';
      case _CallObjective.routine: return 'routine';
      case _CallObjective.followUp: return 'follow_up';
      case _CallObjective.targetCall: return 'target_call';
    }
  }
  static _CallObjective fromKey(String k) => _CallObjective.values
      .firstWhere((v) => v.key == k, orElse: () => _CallObjective.planned);
}

// ─── Doctor Availability ──────────────────────────────────────────────────────

enum _Availability { fullDetailing, partialDetailing, notAvailable }

extension _AvailabilityX on _Availability {
  String get label {
    switch (this) {
      case _Availability.fullDetailing: return 'Full Detailing';
      case _Availability.partialDetailing: return 'Partial';
      case _Availability.notAvailable: return 'Not Available';
    }
  }
  String get key {
    switch (this) {
      case _Availability.fullDetailing: return 'full';
      case _Availability.partialDetailing: return 'partial';
      case _Availability.notAvailable: return 'not_available';
    }
  }
  Color get color {
    switch (this) {
      case _Availability.fullDetailing: return Colors.green;
      case _Availability.partialDetailing: return Colors.orange;
      case _Availability.notAvailable: return Colors.red;
    }
  }
  static _Availability fromKey(String k) => _Availability.values
      .firstWhere((v) => v.key == k, orElse: () => _Availability.fullDetailing);
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class DcrDoctorVisitScreen extends StatefulWidget {
  final DcrDoctorVisit? existingVisit;

  const DcrDoctorVisitScreen({super.key, this.existingVisit});

  @override
  State<DcrDoctorVisitScreen> createState() => _DcrDoctorVisitScreenState();
}

class _DcrDoctorVisitScreenState extends State<DcrDoctorVisitScreen> {
  static const _purple = Color(0xFF4A148C);
  static const _teal = Color(0xFF00695C);

  // ─── Core fields ──────────────────────────────────────────────────────────────
  ClmDoctor? _selectedDoctor;
  late DateTime _startTime;
  DateTime? _endTime;

  // ─── Visit Classification ─────────────────────────────────────────────────────
  _VisitType _visitType = _VisitType.solo;
  _CallObjective _callObjective = _CallObjective.planned;
  List<DcrEmployee> _selectedEmployees = [];

  // ─── Call Quality ─────────────────────────────────────────────────────────────
  _Availability _availability = _Availability.fullDetailing;
  int _patientCount = 0;
  bool _detailingDone = true;

  // ─── Brands & POB ─────────────────────────────────────────────────────────────
  List<int> _featuredBrandIds = [];
  bool _pobCommitted = false;
  int _pobQty = 0;

  // ─── Samples ──────────────────────────────────────────────────────────────────
  List<DcrSampleItem> _sampleItems = [];
  String? _signaturePath;

  // ─── Additional ──────────────────────────────────────────────────────────────
  final _literatureCtrl = TextEditingController();
  final _doctorActionCtrl = TextEditingController();
  final _ptsCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  DateTime? _followUpDate;

  // ─── Voice note ───────────────────────────────────────────────────────────────
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _recording = false;
  bool _playing = false;
  String? _voiceNotePath;
  String? _voiceNoteTranscript;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _endTime = DateTime.now();

    final v = widget.existingVisit;
    if (v != null) {
      _startTime = v.visitStartTime;
      _endTime = v.visitEndTime;
      _ptsCtrl.text = v.businessValuePts > 0 ? v.businessValuePts.toString() : '';
      _featuredBrandIds = List.from(v.featuredBrandIds);
      _voiceNotePath = v.voiceNotePath;
      _voiceNoteTranscript = v.voiceNoteTranscript;
      // Parse extras from remarks JSON
      _parseExtras(v.remarks);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingData());
  }

  void _parseExtras(String raw) {
    if (raw.isEmpty) return;
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      _visitType = _VisitTypeX.fromKey(data['visitType'] ?? 'solo');
      _callObjective = _CallObjectiveX.fromKey(data['callObjective'] ?? 'planned');
      _availability = _AvailabilityX.fromKey(data['availability'] ?? 'full');
      _patientCount = data['patientCount'] ?? 0;
      _detailingDone = data['detailingDone'] ?? true;
      _pobCommitted = data['pobCommitted'] ?? false;
      _pobQty = data['pobQty'] ?? 0;
      _literatureCtrl.text = data['literature'] ?? '';
      _doctorActionCtrl.text = data['doctorAction'] ?? '';
      _remarksCtrl.text = data['remarks'] ?? '';
      if (data['followUpDate'] != null) {
        _followUpDate = DateTime.tryParse(data['followUpDate']);
      }
    } catch (_) {
      _remarksCtrl.text = raw;
    }
  }

  String _encodeExtras() => json.encode({
        'visitType': _visitType.key,
        'callObjective': _callObjective.key,
        'availability': _availability.key,
        'patientCount': _patientCount,
        'detailingDone': _detailingDone,
        'pobCommitted': _pobCommitted,
        'pobQty': _pobQty,
        'literature': _literatureCtrl.text.trim(),
        'doctorAction': _doctorActionCtrl.text.trim(),
        'remarks': _remarksCtrl.text.trim(),
        if (_followUpDate != null) 'followUpDate': _followUpDate!.toIso8601String(),
      });

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    _literatureCtrl.dispose();
    _doctorActionCtrl.dispose();
    _ptsCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final prov = context.read<DcrProvider>();
    final v = widget.existingVisit;
    if (v != null) {
      _selectedDoctor = prov.doctors.where((d) => d.id == v.doctorId).firstOrNull;
    }
    if (v?.id != null) {
      final emps = await prov.getVisitEmployees(v!.id!);
      final samples = await prov.getSampleItems(v.id!);
      final sig = await prov.getSignature(v.id!);
      if (mounted) {
        setState(() {
          _selectedEmployees = emps
              .map((e) => DcrEmployee(
                    id: e.employeeId,
                    name: e.employeeName,
                    employeeCode: e.employeeCode,
                  ))
              .toList();
          _sampleItems = samples;
          _signaturePath = sig?.signaturePath;
        });
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DcrProvider>();
    final isEdit = widget.existingVisit?.id != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Doctor Visit' : 'New Doctor Visit',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
        children: [
          // 1 – Doctor Selection
          _buildDoctorSection(prov),
          const SizedBox(height: 12),

          // 2 – Visit Classification
          _buildVisitClassificationSection(prov),
          const SizedBox(height: 12),

          // 3 – Time
          _buildTimeSection(),
          const SizedBox(height: 12),

          // 4 – Call Quality
          _buildCallQualitySection(),
          const SizedBox(height: 12),

          // 5 – Brands & POB
          _buildBrandsPobSection(prov),
          const SizedBox(height: 12),

          // 6 – Sample Distribution
          _buildSamplesSection(prov),
          const SizedBox(height: 12),

          // 7 – Field Activity
          _buildFieldActivitySection(),
          const SizedBox(height: 12),

          // 8 – Voice Note
          _buildVoiceNoteSection(),
          const SizedBox(height: 12),

          // 9 – Remarks
          _buildRemarksSection(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── 1. Doctor Section ────────────────────────────────────────────────────────

  Widget _buildDoctorSection(DcrProvider prov) {
    return _section(
      icon: Icons.person_outlined,
      color: _purple,
      title: 'Doctor',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<ClmDoctor>(
          initialValue: _selectedDoctor,
          isExpanded: true,
          hint: const Text('Select doctor'),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          items: prov.doctors
              .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text('${d.name} · ${d.speciality}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (d) => setState(() => _selectedDoctor = d),
        ),
        if (_selectedDoctor != null) ...[
          const SizedBox(height: 10),
          _buildDoctorInfoStrip(_selectedDoctor!),
        ],
      ]),
    );
  }

  Widget _buildDoctorInfoStrip(ClmDoctor d) {
    final catColor = d.category == 'A'
        ? Colors.red.shade600
        : d.category == 'B'
            ? Colors.orange.shade600
            : Colors.blue.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _purple.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: _purple.withValues(alpha: 0.12),
          child: Text(d.initials,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _purple)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.speciality,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            if (d.hospital != null && d.hospital!.isNotEmpty)
              Text(d.hospital!,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        _infoChip('Cat ${d.category}', catColor),
        const SizedBox(width: 6),
        _infoChip(d.territory, Colors.teal.shade600),
      ]),
    );
  }

  // ─── 2. Visit Classification ──────────────────────────────────────────────────

  Widget _buildVisitClassificationSection(DcrProvider prov) {
    return _section(
      icon: Icons.category_outlined,
      color: Colors.indigo,
      title: 'Visit Classification',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Visit Type dropdown
        _fieldLabel('Visit Type'),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_VisitType>(
              value: _visitType,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              borderRadius: BorderRadius.circular(10),
              items: _VisitType.values
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Row(children: [
                          Icon(v.icon, size: 16, color: _purple),
                          const SizedBox(width: 8),
                          Text(v.label, style: const TextStyle(fontSize: 13)),
                        ]),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _visitType = v!),
            ),
          ),
        ),

        // Joint employees (only when not solo)
        if (_visitType != _VisitType.solo) ...[
          const SizedBox(height: 12),
          _fieldLabel('Co-worker / Accompanying Manager'),
          const SizedBox(height: 6),
          _buildJointEmployeeRow(prov),
        ],

        const SizedBox(height: 12),

        // Call Objective
        _fieldLabel('Call Objective'),
        const SizedBox(height: 6),
        Row(
          children: _CallObjective.values.map((obj) {
            final selected = _callObjective == obj;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _callObjective = obj),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? _purple.withValues(alpha: 0.12)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: selected ? _purple : Colors.grey.shade200,
                        width: selected ? 1.5 : 1),
                  ),
                  child: Text(obj.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: selected ? _purple : Colors.grey.shade500)),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _buildJointEmployeeRow(DcrProvider prov) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_selectedEmployees.isNotEmpty) ...[
        Wrap(
          spacing: 8, runSpacing: 6,
          children: _selectedEmployees.map((e) => Chip(
                label: Text(e.name, style: const TextStyle(fontSize: 12)),
                avatar: Icon(Icons.person, size: 14, color: _purple),
                deleteIcon: const Icon(Icons.close, size: 13),
                onDeleted: () => setState(() => _selectedEmployees.remove(e)),
                backgroundColor: _purple.withValues(alpha: 0.07),
                side: BorderSide(color: _purple.withValues(alpha: 0.2)),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
        ),
        const SizedBox(height: 8),
      ],
      OutlinedButton.icon(
        onPressed: () => _pickEmployees(prov),
        icon: const Icon(Icons.person_add_outlined, size: 16),
        label: Text(
            _selectedEmployees.isEmpty ? 'Select Co-worker / Manager' : 'Add More',
            style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _purple,
          side: BorderSide(color: _purple.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]);
  }

  Future<void> _pickEmployees(DcrProvider prov) async {
    final selected = Set<DcrEmployee>.from(_selectedEmployees);
    String searchQuery = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filtered = searchQuery.isEmpty
              ? prov.employees
              : prov.employees
                  .where((e) =>
                      e.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                      e.designation.toLowerCase().contains(searchQuery.toLowerCase()))
                  .toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (_, scroll) => Column(children: [
              const SizedBox(height: 10),
              Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: Text('Select Co-workers',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    Text('${selected.length} selected',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: false,
                    onChanged: (v) => setModal(() => searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search name or designation…',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.person_off_outlined,
                              size: 40, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text('No employees found',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ]),
                      )
                    : ListView.separated(
                        controller: scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (_, i) {
                          final e = filtered[i];
                          final isSelected = selected.any((s) => s.id == e.id);
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: isSelected
                                  ? _purple.withValues(alpha: 0.15)
                                  : Colors.grey.shade100,
                              child: Icon(
                                isSelected ? Icons.check : Icons.person_outlined,
                                size: 16,
                                color: isSelected ? _purple : Colors.grey.shade400,
                              ),
                            ),
                            title: Text(e.name,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Row(children: [
                              if (e.designation.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(e.designation,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue.shade700)),
                                ),
                              if (e.employeeCode.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(e.employeeCode,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500)),
                              ],
                            ]),
                            onTap: () => setModal(() {
                              if (isSelected) {
                                selected.removeWhere((s) => s.id == e.id);
                              } else {
                                selected.add(e);
                              }
                            }),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      setState(() => _selectedEmployees = selected.toList());
                      Navigator.pop(ctx);
                    },
                    child: Text(
                        'Confirm (${selected.length} selected)',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ─── 3. Time Section ──────────────────────────────────────────────────────────

  Widget _buildTimeSection() {
    return _section(
      icon: Icons.schedule_outlined,
      color: Colors.teal,
      title: 'Visit Time',
      child: Row(children: [
        Expanded(
            child: _timeField('In', _startTime,
                (t) => setState(() => _startTime = t))),
        const SizedBox(width: 12),
        Expanded(
            child: _timeField('Out', _endTime,
                (t) => setState(() => _endTime = t),
                optional: true)),
        if (_endTime != null) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatDuration(_startTime, _endTime!),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _teal),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _timeField(String label, DateTime? value, ValueChanged<DateTime> onPick,
      {bool optional = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final now = value ?? DateTime.now();
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(now),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.light(primary: _purple)),
            child: child!,
          ),
        );
        if (picked != null) {
          onPick(DateTime(now.year, now.month, now.day, picked.hour, picked.minute));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.access_time_rounded,
              size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
            Text(
              value != null
                  ? DateFormat('hh:mm a').format(value)
                  : optional
                      ? 'Tap to set'
                      : '--:-- --',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: value != null ? const Color(0xFF1A1A2E) : Colors.grey.shade400),
            ),
          ]),
        ]),
      ),
    );
  }

  String _formatDuration(DateTime from, DateTime to) {
    final diff = to.difference(from);
    if (diff.isNegative) return '–';
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  // ─── 4. Call Quality ──────────────────────────────────────────────────────────

  Widget _buildCallQualitySection() {
    return _section(
      icon: Icons.assessment_outlined,
      color: Colors.orange,
      title: 'Call Quality & Outcome',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Doctor Availability
        _fieldLabel('Doctor Availability'),
        const SizedBox(height: 6),
        Row(
          children: _Availability.values.map((a) {
            final sel = _availability == a;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _availability = a),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: sel
                        ? a.color.withValues(alpha: 0.12)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel ? a.color : Colors.grey.shade200,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Text(a.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: sel ? a.color : Colors.grey.shade500)),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        // Detailing Done
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Detailing Done?',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text('CLM presentation was completed',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ]),
          ),
          Switch.adaptive(
            value: _detailingDone,
            activeThumbColor: _purple,
            onChanged: (v) => setState(() => _detailingDone = v),
          ),
        ]),

        const SizedBox(height: 14),

        // Patient Count
        _fieldLabel('Patients Seen in Clinic'),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.people_outline_rounded,
              size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text('No. of patients at clinic during visit',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const Spacer(),
          _stepperBtn(Icons.remove_rounded, () {
            if (_patientCount > 0) setState(() => _patientCount--);
          }),
          SizedBox(
            width: 40,
            child: Text('$_patientCount',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _stepperBtn(Icons.add_rounded, () => setState(() => _patientCount++)),
        ]),
      ]),
    );
  }

  // ─── 5. Brands & POB ──────────────────────────────────────────────────────────

  Widget _buildBrandsPobSection(DcrProvider prov) {
    return _section(
      icon: Icons.medication_outlined,
      color: Colors.deepPurple,
      title: 'Brands Detailed & POB',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Featured Brands
        _fieldLabel('Brands Detailed in This Visit'),
        const SizedBox(height: 8),
        prov.brands.isEmpty
            ? Text('No brands available',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade400))
            : Wrap(
                spacing: 8, runSpacing: 8,
                children: prov.brands.map((b) {
                  final sel = _featuredBrandIds.contains(b.id);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (sel) { _featuredBrandIds.remove(b.id); }
                      else { _featuredBrandIds.add(b.id); }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel
                            ? Colors.deepPurple.withValues(alpha: 0.12)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? Colors.deepPurple
                              : Colors.grey.shade300,
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (sel)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.check_circle,
                                size: 13, color: Colors.deepPurple),
                          ),
                        Text(b.name,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: sel
                                    ? Colors.deepPurple
                                    : Colors.grey.shade700)),
                      ]),
                    ),
                  );
                }).toList(),
              ),

        const Divider(height: 24),

        // POB
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('POB – Prescription Committed',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text('Doctor committed to prescribe your brands',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ]),
          ),
          Switch.adaptive(
            value: _pobCommitted,
            activeThumbColor: Colors.green,
            onChanged: (v) => setState(() => _pobCommitted = v),
          ),
        ]),
        if (_pobCommitted) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.format_list_numbered_outlined,
                size: 18, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text('Prescription units committed',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Spacer(),
            _stepperBtn(Icons.remove_rounded, () {
              if (_pobQty > 0) setState(() => _pobQty--);
            }),
            SizedBox(
              width: 40,
              child: Text('$_pobQty',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 16,
                      color: Colors.green.shade700)),
            ),
            _stepperBtn(Icons.add_rounded, () => setState(() => _pobQty++),
                color: Colors.green),
          ]),
        ],

        const Divider(height: 24),

        // Business Value PTS
        TextField(
          controller: _ptsCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Business Value (PTS)',
            hintText: 'e.g. 15,000',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon:
                const Icon(Icons.currency_rupee, size: 18),
            isDense: true,
          ),
        ),
      ]),
    );
  }

  // ─── 6. Sample Distribution ───────────────────────────────────────────────────

  Widget _buildSamplesSection(DcrProvider prov) {
    final totalUnits = _sampleItems.fold<int>(0, (s, i) => s + i.quantity);
    final productCount = _sampleItems.where((i) => i.quantity > 0).length;

    return _section(
      icon: Icons.science_outlined,
      color: const Color(0xFFE65100),
      title: 'Sample Distribution & Signature',
      child: Column(children: [
        // Summary row
        if (_sampleItems.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE65100).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFE65100).withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.medication_outlined,
                  size: 20, color: const Color(0xFFE65100)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('$productCount product${productCount != 1 ? 's' : ''} · $totalUnits unit${totalUnits != 1 ? 's' : ''} distributed',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13,
                          color: Color(0xFFE65100))),
                  // Inline product list
                  ..._sampleItems
                      .where((i) => i.quantity > 0)
                      .map((i) => Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                                '• ${i.productName}  ×${i.quantity}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700)),
                          )),
                ]),
              ),
              if (_signaturePath != null)
                Column(children: [
                  const Icon(Icons.verified_outlined,
                      size: 18, color: Colors.green),
                  const SizedBox(height: 2),
                  Text('Signed',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600)),
                ]),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openSampleSheet(prov),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text(
              _sampleItems.isEmpty
                  ? 'Add Products & Get Signature'
                  : 'Edit Samples & Signature',
              style: const TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE65100),
              side: BorderSide(
                  color: const Color(0xFFE65100).withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _openSampleSheet(DcrProvider prov) async {
    final result = await Navigator.push<DcrSampleSheetResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: DcrSampleSheetScreen(
            initialItems: _sampleItems,
            initialSignaturePath: _signaturePath,
            visitId: widget.existingVisit?.id,
          ),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _sampleItems = result.items;
        _signaturePath = result.signaturePath;
      });
    }
  }

  // ─── 7. Field Activity ────────────────────────────────────────────────────────

  Widget _buildFieldActivitySection() {
    return _section(
      icon: Icons.task_alt_outlined,
      color: Colors.teal,
      title: 'Field Activity & Follow-up',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Literature / Gifts
        TextField(
          controller: _literatureCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Literature / Promotional Material Given',
            hintText: 'e.g. CardioMax visual aid, GlucoShield brochure',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.book_outlined, size: 18),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),

        // Doctor Action Committed
        TextField(
          controller: _doctorActionCtrl,
          style: const TextStyle(fontSize: 13),
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Doctor Action / Commitment',
            hintText: 'What did the doctor commit to? (e.g. will start NeuroVite next week)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.handshake_outlined, size: 18),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),

        // Follow-up Date
        _fieldLabel('Next Follow-up Date'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickFollowUpDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _followUpDate != null
                  ? Colors.blue.shade50
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _followUpDate != null
                    ? Colors.blue.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(children: [
              Icon(Icons.event_outlined,
                  size: 18,
                  color: _followUpDate != null
                      ? Colors.blue.shade600
                      : Colors.grey.shade400),
              const SizedBox(width: 10),
              Text(
                _followUpDate != null
                    ? DateFormat('EEEE, d MMM yyyy').format(_followUpDate!)
                    : 'Schedule next follow-up',
                style: TextStyle(
                    fontSize: 13,
                    color: _followUpDate != null
                        ? Colors.blue.shade700
                        : Colors.grey.shade500),
              ),
              if (_followUpDate != null) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _followUpDate = null),
                  child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _pickFollowUpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _followUpDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _purple)),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _followUpDate = picked);
  }

  // ─── 8. Voice Note ────────────────────────────────────────────────────────────

  Widget _buildVoiceNoteSection() {
    return _section(
      icon: Icons.mic_outlined,
      color: Colors.blueGrey,
      title: 'Voice Note (Optional)',
      child: Row(children: [
        if (!_recording && _voiceNotePath == null)
          ElevatedButton.icon(
            onPressed: _startRecording,
            icon: const Icon(Icons.fiber_manual_record,
                size: 14, color: Colors.red),
            label: const Text('Record'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: const Color(0xFF1A1A2E),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        if (_recording) ...[
          ElevatedButton.icon(
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop, size: 14),
            label: Text('Stop  ${_fmt(_recordSeconds)}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
        if (!_recording && _voiceNotePath != null) ...[
          IconButton(
            onPressed: _togglePlay,
            icon: Icon(
                _playing ? Icons.pause_circle : Icons.play_circle,
                color: _purple, size: 32),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Voice note recorded',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          IconButton(
            onPressed: () => setState(() => _voiceNotePath = null),
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            padding: EdgeInsets.zero,
          ),
        ],
      ]),
    );
  }

  // ─── 9. Remarks ───────────────────────────────────────────────────────────────

  Widget _buildRemarksSection() {
    return _section(
      icon: Icons.notes_outlined,
      color: Colors.grey.shade600,
      title: 'Remarks',
      child: TextField(
        controller: _remarksCtrl,
        maxLines: 4,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'General observations, objections, competitor activity…',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  // ─── Bottom Bar ───────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
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
                foregroundColor: Colors.orange.shade700,
                side: BorderSide(color: Colors.orange.shade300),
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
              onPressed: _saving ? null : () => _save(DcrVisitStatus.submitted),
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('Submit Visit',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save(DcrVisitStatus status) async {
    if (_selectedDoctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a doctor first.')));
      return;
    }
    setState(() => _saving = true);
    final prov = context.read<DcrProvider>();
    try {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);

      final visit = DcrDoctorVisit(
        id: widget.existingVisit?.id,
        sessionId: widget.existingVisit?.sessionId,
        doctorId: _selectedDoctor!.id,
        doctorName: _selectedDoctor!.name,
        visitDate: dateKey,
        visitStartTime: _startTime,
        visitEndTime: _endTime,
        status: status,
        voiceNotePath: _voiceNotePath,
        voiceNoteTranscript: _voiceNoteTranscript,
        attachedLetterPath: null,
        businessValuePts: double.tryParse(_ptsCtrl.text.trim()) ?? 0,
        featuredBrandIds: _featuredBrandIds,
        remarks: _encodeExtras(), // packs all extra fields as JSON
        createdAt: widget.existingVisit?.createdAt ?? now,
      );

      final visitId = await prov.saveDoctorVisit(visit);
      await prov.setVisitEmployees(visitId, _selectedEmployees);
      await prov.saveSampleItems(visitId, _sampleItems);
      if (_signaturePath != null) {
        await prov.saveSignature(DcrVisitSignature(
          visitId: visitId,
          signaturePath: _signaturePath!,
          capturedAt: DateTime.now(),
        ));
      }
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

  // ─── Voice helpers ────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      final granted = await _recorder.hasPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Microphone permission required.')));
        }
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'dcr', 'voice',
          'dcr_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await Directory(p.dirname(path)).create(recursive: true);
      await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      if (!mounted) return;
      _voiceNotePath = path;
      _recordSeconds = 0;
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
      setState(() => _recording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Recording failed: $e')));
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try { await _recorder.stop(); } catch (_) {}
    setState(() => _recording = false);
  }

  Future<void> _togglePlay() async {
    if (_voiceNotePath == null) return;
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _player.play(DeviceFileSource(_voiceNotePath!));
      setState(() => _playing = true);
      _player.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _playing = false);
      });
    }
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─── Widget helpers ───────────────────────────────────────────────────────────

  Widget _section({
    required IconData icon,
    required Color color,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _fieldLabel(String label) => Text(label,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600));

  Widget _infoChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8)),
    child: Text(label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );

  Widget _stepperBtn(IconData icon, VoidCallback? onTap, {Color? color}) {
    final c = color ?? _purple;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: c, size: 16),
      ),
    );
  }
}
