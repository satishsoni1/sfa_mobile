import 'dart:async';
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

class DcrDoctorVisitScreen extends StatefulWidget {
  final DcrDoctorVisit? existingVisit;

  const DcrDoctorVisitScreen({
    super.key,
    this.existingVisit,
  });

  @override
  State<DcrDoctorVisitScreen> createState() => _DcrDoctorVisitScreenState();
}

class _DcrDoctorVisitScreenState extends State<DcrDoctorVisitScreen> {
  static const _purple = Color(0xFF4A148C);

  // ─── Form state ───────────────────────────────────────────────────────────────
  ClmDoctor? _selectedDoctor;
  late DateTime _startTime;
  DateTime? _endTime;
  final _ptsCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  List<DcrEmployee> _selectedEmployees = [];
  List<int> _featuredBrandIds = [];
  List<DcrSampleItem> _sampleItems = [];
  String? _signaturePath;

  // ─── Voice recording ──────────────────────────────────────────────────────────
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
    final v = widget.existingVisit;
    if (v != null) {
      _startTime = v.visitStartTime;
      _endTime = v.visitEndTime;
      _ptsCtrl.text = v.businessValuePts > 0 ? v.businessValuePts.toString() : '';
      _remarksCtrl.text = v.remarks;
      _featuredBrandIds = List.from(v.featuredBrandIds);
      _voiceNotePath = v.voiceNotePath;
      _voiceNoteTranscript = v.voiceNoteTranscript;
    } else {
      _startTime = DateTime.now();
      _endTime = DateTime.now();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingData());
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _buildDoctorPicker(prov),
          const SizedBox(height: 14),
          _buildVisitTimeCard(),
          const SizedBox(height: 14),
          _buildJointWorkingCard(prov),
          const SizedBox(height: 14),
          _buildVoiceNoteCard(),
          const SizedBox(height: 14),
          _buildSamplesCard(prov),
          const SizedBox(height: 14),
          _buildCommercialInsightsCard(prov),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── Doctor Picker ────────────────────────────────────────────────────────────

  Widget _buildDoctorPicker(DcrProvider prov) {
    return _card(
      title: 'Doctor',
      icon: Icons.person_outline,
      child: DropdownButtonFormField<ClmDoctor>(
        value: _selectedDoctor,
        isExpanded: true,
        hint: const Text('Select doctor'),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        items: prov.doctors
            .map((d) => DropdownMenuItem(
                  value: d,
                  child: Text('${d.name} (${d.speciality})',
                      overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (d) => setState(() => _selectedDoctor = d),
      ),
    );
  }

  // ─── Visit Time ───────────────────────────────────────────────────────────────

  Widget _buildVisitTimeCard() {
    return _card(
      title: 'Visit Time',
      icon: Icons.access_time_outlined,
      child: Row(children: [
        Expanded(
          child: _timeField(
              'Start', _startTime, (t) => setState(() => _startTime = t)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _timeField(
              'End', _endTime, (t) => setState(() => _endTime = t),
              optional: true),
        ),
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
          onPick(DateTime(now.year, now.month, now.day, picked.hour, picked.minute));
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

  // ─── Joint Working ────────────────────────────────────────────────────────────

  Widget _buildJointWorkingCard(DcrProvider prov) {
    return _card(
      title: 'Joint Working',
      icon: Icons.group_outlined,
      trailing: TextButton.icon(
        onPressed: () => _pickEmployees(prov),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add'),
        style: TextButton.styleFrom(
            foregroundColor: _purple,
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
                        label: Text(e.name, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => setState(() => _selectedEmployees.remove(e)),
                        backgroundColor: _purple.withValues(alpha: 0.08),
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
                              style: TextStyle(color: Colors.grey.shade500)),
                          onChanged: (v) => setModal(() {
                            if (v == true) {
                              selected.add(e);
                            } else {
                              selected.removeWhere((s) => s.id == e.id);
                            }
                          }),
                          activeColor: _purple,
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
                      backgroundColor: _purple, foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() => _selectedEmployees = selected.toList());
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

  // ─── Voice Note ───────────────────────────────────────────────────────────────

  Widget _buildVoiceNoteCard() {
    return _card(
      title: 'Voice Note (Optional)',
      icon: Icons.mic_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (!_recording && _voiceNotePath == null)
            ElevatedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.fiber_manual_record, size: 16, color: Colors.red),
              label: const Text('Record'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: const Color(0xFF1A1A2E),
                  elevation: 0),
            ),
          if (_recording) ...[
            ElevatedButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop, size: 16),
              label: Text('Stop  ${_fmt(_recordSeconds)}'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
          ],
          if (!_recording && _voiceNotePath != null) ...[
            IconButton(
              onPressed: _togglePlay,
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow, color: _purple),
              tooltip: _playing ? 'Pause' : 'Play',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text('Voice note recorded',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
            IconButton(
              onPressed: () => setState(() => _voiceNotePath = null),
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            ),
          ],
        ]),
        if (_voiceNoteTranscript != null && _voiceNoteTranscript!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_voiceNoteTranscript!,
                style: const TextStyle(fontSize: 12, height: 1.4)),
          ),
        ],
      ]),
    );
  }

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
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      if (!mounted) return;
      _voiceNotePath = path;
      _recordSeconds = 0;
      _recordTimer = Timer.periodic(
          const Duration(seconds: 1), (_) { if (mounted) setState(() => _recordSeconds++); });
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
    try {
      await _recorder.stop();
    } catch (_) {}
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

  // ─── Sample Distribution (includes signature) ─────────────────────────────────

  Widget _buildSamplesCard(DcrProvider prov) {
    final totalUnits = _sampleItems.fold<int>(0, (sum, i) => sum + i.quantity);
    final productCount = _sampleItems.where((i) => i.quantity > 0).length;
    return _card(
      title: 'Sample Distribution & Signature',
      icon: Icons.medication_outlined,
      child: Column(children: [
        if (_sampleItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              _pillStat('$productCount', 'products'),
              const SizedBox(width: 8),
              _pillStat('$totalUnits', 'total units'),
              const Spacer(),
              if (_signaturePath != null)
                Row(children: [
                  const Icon(Icons.verified_outlined, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('Signed',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600)),
                ]),
            ]),
          ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openSampleSheet(prov),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text(_sampleItems.isEmpty
                ? 'Manage Samples & Signature'
                : 'Edit Samples & Signature'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _purple,
              side: BorderSide(color: _purple.withValues(alpha: 0.4)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _pillStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF1A1A2E)),
          children: [
            TextSpan(
                text: value,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: _purple, fontSize: 14)),
            TextSpan(
                text: ' $label',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
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

  // ─── Commercial Insights ──────────────────────────────────────────────────────

  Widget _buildCommercialInsightsCard(DcrProvider prov) {
    return _card(
      title: 'Commercial Insights',
      icon: Icons.insights_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Featured Brands',
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: prov.brands.map((b) {
            final selected = _featuredBrandIds.contains(b.id);
            return FilterChip(
              label: Text(b.name, style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (v) => setState(() {
                if (v) {
                  _featuredBrandIds.add(b.id);
                } else {
                  _featuredBrandIds.remove(b.id);
                }
              }),
              selectedColor: _purple.withValues(alpha: 0.15),
              checkmarkColor: _purple,
              side: BorderSide(
                  color: selected
                      ? _purple.withValues(alpha: 0.4)
                      : Colors.grey.shade300),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _ptsCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Business Value (PTS)',
            hintText: 'e.g. 15000',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.currency_rupee, size: 18),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _remarksCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Remarks',
            hintText: 'General observations, follow-up notes...',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ]),
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
                foregroundColor: _purple,
                side: BorderSide(color: _purple),
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
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('Submit',
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a doctor.')));
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
        remarks: _remarksCtrl.text.trim(),
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

  // ─── Card shell ───────────────────────────────────────────────────────────────

  Widget _card({
    required String title,
    required IconData icon,
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
          Icon(icon, size: 16, color: _purple),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}
