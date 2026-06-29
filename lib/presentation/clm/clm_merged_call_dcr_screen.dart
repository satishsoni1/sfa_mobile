import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/clm_models.dart';
import '../../data/models/dcr_models.dart';
import '../../providers/clm_provider.dart';
import '../../providers/dcr_provider.dart';
import '../dcr/dcr_sample_sheet_screen.dart';

// ─── Visit Type ───────────────────────────────────────────────────────────────

enum _VisitType { solo, jointWork, managerAccompanied, trainingVisit }

extension _VisitTypeX on _VisitType {
  String get label {
    switch (this) {
      case _VisitType.solo: return 'Solo';
      case _VisitType.jointWork: return 'Joint Work';
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

// ─── Doctor Availability ──────────────────────────────────────────────────────

enum _DoctorAvailability { fullDetail, partialDetail, notAvailable }

extension _DoctorAvailabilityX on _DoctorAvailability {
  String get label {
    switch (this) {
      case _DoctorAvailability.fullDetail: return 'Full Detailing';
      case _DoctorAvailability.partialDetail: return 'Partial';
      case _DoctorAvailability.notAvailable: return 'Not Available';
    }
  }
  String get key {
    switch (this) {
      case _DoctorAvailability.fullDetail: return 'full_detail';
      case _DoctorAvailability.partialDetail: return 'partial_detail';
      case _DoctorAvailability.notAvailable: return 'not_available';
    }
  }
  Color get color {
    switch (this) {
      case _DoctorAvailability.fullDetail: return Colors.green;
      case _DoctorAvailability.partialDetail: return Colors.orange;
      case _DoctorAvailability.notAvailable: return Colors.red;
    }
  }
  static _DoctorAvailability fromKey(String k) => _DoctorAvailability.values
      .firstWhere((v) => v.key == k, orElse: () => _DoctorAvailability.fullDetail);
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ClmMergedCallDcrScreen extends StatefulWidget {
  final ClmDoctor doctor;
  final ClmSession? session;   // null when opened from DCR draft-resume
  final List<ClmBrand> brands;

  const ClmMergedCallDcrScreen({
    super.key,
    required this.doctor,
    this.session,
    this.brands = const [],
  });

  @override
  State<ClmMergedCallDcrScreen> createState() => _ClmMergedCallDcrScreenState();
}

class _ClmMergedCallDcrScreenState extends State<ClmMergedCallDcrScreen>
    with TickerProviderStateMixin {
  static const _purple = Color(0xFF4A148C);
  static const _draftKey = 'clm_draft_';

  // ─── Call Report fields ───────────────────────────────────────────────────────
  DoctorReaction _reaction = DoctorReaction.neutral;
  final Set<int> _brandsDiscussed = {};
  final Set<String> _keyMessages = {};
  final List<String> _topics = [];
  final _notesCtrl = TextEditingController();
  final _competitorCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _nextActionCtrl = TextEditingController();
  DateTime? _nextCallDate;

  // ─── DCR fields ───────────────────────────────────────────────────────────────
  _VisitType _visitType = _VisitType.solo;
  _DoctorAvailability _doctorAvailability = _DoctorAvailability.fullDetail;
  List<DcrEmployee> _selectedEmployees = [];
  int _patientCount = 0;
  bool _pobCommitted = false;
  int _pobQty = 0;
  final _promoMaterialCtrl = TextEditingController();
  List<DcrSampleItem> _sampleItems = [];
  String? _signaturePath;

  // ─── Local DcrProvider for employee/product access ────────────────────────────
  late final DcrProvider _dcrProv;

  // ─── Voice Note ───────────────────────────────────────────────────────────────
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _stt = SpeechToText();
  bool _recording = false;
  bool _hasRecording = false;
  bool _playing = false;
  bool _transcribing = false;
  String? _voiceNotePath;
  String _transcript = '';
  int _recordSeconds = 0;
  Timer? _recordTimer;
  late AnimationController _micPulseCtrl;

  // ─── State ────────────────────────────────────────────────────────────────────
  bool _saving = false;
  bool _savingDraft = false;
  bool _hasDraft = false;
  bool _lastCallExpanded = false;
  ClmCallReport? _lastCallReport;

  /// Brands loaded from ClmProvider when resuming a draft (session == null).
  List<ClmBrand> _loadedBrands = [];

  /// Returns passed-in brands for post-detailing mode, or brands loaded from
  /// the draft when resuming (draft-resume mode).
  List<ClmBrand> get _effectiveBrands =>
      widget.brands.isNotEmpty ? widget.brands : _loadedBrands;

  static const Map<String, List<String>> _brandMessages = {
    'CardioMax': ['24h BP control', 'No cough (unlike ACEi)', 'Renoprotective', 'CV death reduction'],
    'NeuroVite': ['Reduces burning & tingling', 'Improves nerve conduction', 'Safe long-term', '73% symptom improvement'],
    'GlucoShield': ['38% CV death reduction', 'Weight loss benefit', 'Once daily dosing', 'Renal protection'],
  };

  String get _draftPrefsKey => '$_draftKey${widget.doctor.id}';

  @override
  void initState() {
    super.initState();
    if (widget.session != null) {
      _brandsDiscussed.addAll(widget.session!.brandIds);
    }
    _micPulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    // Create a local DcrProvider to get employees and products
    _dcrProv = DcrProvider();
    _dcrProv.init();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDraftAndLastCall());
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _competitorCtrl.dispose();
    _topicCtrl.dispose();
    _nextActionCtrl.dispose();
    _promoMaterialCtrl.dispose();
    _recorder.dispose();
    _player.dispose();
    _recordTimer?.cancel();
    _micPulseCtrl.dispose();
    super.dispose();
  }

  // ─── Draft Load / Save ────────────────────────────────────────────────────────

  Future<void> _loadDraftAndLastCall() async {
    final prov = context.read<ClmProvider>();
    final prefs = await SharedPreferences.getInstance();

    final reports = await prov.getCallReportsForDoctor(widget.doctor.id);
    if (mounted && reports.isNotEmpty) {
      setState(() => _lastCallReport = reports.first);
    }

    final raw = prefs.getString(_draftPrefsKey);
    if (raw == null || !mounted) return;
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      setState(() {
        _hasDraft = true;
        _reaction = DoctorReactionX.fromKey(data['reaction'] ?? 'neutral');
        _brandsDiscussed.addAll(
            (data['brands'] as List? ?? []).map((e) => e as int));
        _keyMessages.addAll((data['keyMessages'] as List? ?? []).cast<String>());
        _topics.addAll((data['topics'] as List? ?? []).cast<String>());
        _notesCtrl.text = data['notes'] ?? '';
        _competitorCtrl.text = data['competitor'] ?? '';
        _nextActionCtrl.text = data['nextAction'] ?? '';
        _promoMaterialCtrl.text = data['promoMaterial'] ?? '';
        _patientCount = data['patientCount'] ?? 0;
        _pobCommitted = data['pobCommitted'] ?? false;
        _pobQty = data['pobQty'] ?? 0;
        _visitType = _VisitTypeX.fromKey(data['visitType'] ?? 'solo');
        _doctorAvailability = _DoctorAvailabilityX.fromKey(
            data['availability'] ?? 'full_detail');
        if (data['nextCallDate'] != null) {
          _nextCallDate = DateTime.tryParse(data['nextCallDate']);
        }
        // Restore employees from saved names
        final empList = (data['employees'] as List? ?? []);
        _selectedEmployees = empList.map((e) => DcrEmployee(
              name: e['name'] ?? '',
              employeeCode: e['code'] ?? '',
              designation: e['designation'] ?? '',
            )).toList();
      });

      // Load brand objects so "Brands Detailed" section shows them properly
      final brandIds = (data['brands'] as List? ?? [])
          .map((e) => (e as num).toInt())
          .toList();
      if (brandIds.isNotEmpty && mounted) {
        if (prov.allBrands.isEmpty) await prov.loadBrands();
        if (mounted) {
          setState(() {
            _loadedBrands = prov.allBrands
                .where((b) => brandIds.contains(b.id))
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    setState(() => _savingDraft = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftPrefsKey, json.encode(_buildDraftJson()));
      if (mounted) {
        setState(() => _hasDraft = true);
        _showSnack('Draft saved — resume anytime from DCR');
      }
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftPrefsKey);
    if (mounted) setState(() => _hasDraft = false);
  }

  Map<String, dynamic> _buildDraftJson() => {
        // Meta — enough for DCR dashboard to show and resume this draft
        'doctorId': widget.doctor.id,
        'doctorName': widget.doctor.name,
        'doctorSpeciality': widget.doctor.speciality,
        'sessionId': widget.session?.id,
        'savedAt': DateTime.now().toIso8601String(),
        // Call data
        'reaction': _reaction.key,
        'brands': _brandsDiscussed.toList(),
        'keyMessages': _keyMessages.toList(),
        'topics': _topics,
        'notes': _notesCtrl.text.trim(),
        'competitor': _competitorCtrl.text.trim(),
        'nextAction': _nextActionCtrl.text.trim(),
        'promoMaterial': _promoMaterialCtrl.text.trim(),
        'patientCount': _patientCount,
        'pobCommitted': _pobCommitted,
        'pobQty': _pobQty,
        'visitType': _visitType.key,
        'availability': _doctorAvailability.key,
        'employees': _selectedEmployees.map((e) => {
              'name': e.name,
              'code': e.employeeCode,
              'designation': e.designation,
            }).toList(),
        if (_nextCallDate != null) 'nextCallDate': _nextCallDate!.toIso8601String(),
      };

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final dMins = session != null ? session.durationSeconds ~/ 60 : 0;
    final dSecs = session != null ? session.durationSeconds % 60 : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text('Call Report & DCR',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_hasDraft)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('DRAFT',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: Column(children: [
        if (session != null) _buildSessionBar(dMins, dSecs),
        if (session == null) _buildDraftResumeBanner(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              if (_lastCallReport != null) ...[
                _buildLastCallAnalysis(),
                const SizedBox(height: 14),
              ],

              // ── Call Outcome ──────────────────────────────────────────────
              _sectionHeader('Call Outcome', Icons.how_to_vote_outlined, Colors.purple),
              const SizedBox(height: 8),
              _buildReactionPicker(),
              const SizedBox(height: 10),
              _buildAvailabilityRow(),
              const SizedBox(height: 14),

              // ── Detailing Info ────────────────────────────────────────────
              _sectionHeader('Detailing Info', Icons.medication_outlined, Colors.teal),
              const SizedBox(height: 8),
              _buildBrandsSection(),
              const SizedBox(height: 10),
              _buildKeyMessagesSection(),
              const SizedBox(height: 14),

              // ── DCR Details ───────────────────────────────────────────────
              _sectionHeader('DCR Details', Icons.assignment_outlined, Colors.orange),
              const SizedBox(height: 8),
              _buildVisitTypeSelector(),
              if (_visitType != _VisitType.solo) ...[
                const SizedBox(height: 10),
                _buildJointEmployeeSection(),
              ],
              const SizedBox(height: 10),
              _buildPatientCountRow(),
              const SizedBox(height: 10),
              _buildPobRow(),
              const SizedBox(height: 10),
              _buildPromoMaterialField(),
              const SizedBox(height: 14),

              // ── Sample Distribution ───────────────────────────────────────
              _sectionHeader('Sample Distribution & Signature',
                  Icons.science_outlined, const Color(0xFFE65100)),
              const SizedBox(height: 8),
              _buildSamplesSection(),
              const SizedBox(height: 14),

              // ── Notes ─────────────────────────────────────────────────────
              _sectionHeader('Notes & Follow-up', Icons.notes_outlined, Colors.blue),
              const SizedBox(height: 8),
              _buildVoiceNoteSection(),
              const SizedBox(height: 10),
              _buildNotesField(),
              const SizedBox(height: 10),
              _buildTopicsSection(),
              const SizedBox(height: 10),
              _buildTextField(_competitorCtrl, 'Competitor mentioned',
                  Icons.warning_amber_outlined),
              const SizedBox(height: 14),

              // ── Next Call ─────────────────────────────────────────────────
              _sectionHeader('Next Call Planning', Icons.event_note_outlined, Colors.indigo),
              const SizedBox(height: 8),
              _buildNextCallRow(),
              const SizedBox(height: 8),
              _buildTextField(_nextActionCtrl, 'Action item for next call',
                  Icons.checklist_rounded),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── Session Bar ──────────────────────────────────────────────────────────────

  Widget _buildSessionBar(int mins, int secs) {
    return Container(
      color: _purple,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: Text(widget.doctor.initials,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.doctor.name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            Text(widget.doctor.speciality,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
        _pillBadge(Icons.timer_outlined, '${mins}m ${secs}s'),
        const SizedBox(width: 6),
        _pillBadge(Icons.slideshow_outlined,
            '${_effectiveBrands.length} brand${_effectiveBrands.length != 1 ? 's' : ''}'),
      ]),
    );
  }

  Widget _buildDraftResumeBanner() {
    return Container(
      color: Colors.amber.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: Text(widget.doctor.initials,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text('${widget.doctor.name}  ·  Resuming Draft Report',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        const Icon(Icons.pending_actions, color: Colors.white, size: 18),
      ]),
    );
  }

  Widget _pillBadge(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20)),
    child: Row(children: [
      Icon(icon, color: Colors.white70, size: 12),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );

  // ─── Last Call Analysis ───────────────────────────────────────────────────────

  Widget _buildLastCallAnalysis() {
    final r = _lastCallReport!;
    final daysAgo = DateTime.now().difference(r.createdAt).inDays;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _lastCallExpanded = !_lastCallExpanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                    color: Colors.teal.shade50, shape: BoxShape.circle),
                child: Icon(Icons.history_rounded,
                    size: 15, color: Colors.teal.shade600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Last Call Analysis',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: Colors.teal.shade700)),
                  Text(
                      '${DateFormat("d MMM yyyy").format(r.createdAt)} · '
                      '${daysAgo == 0 ? "today" : "${daysAgo}d ago"} · '
                      '${r.reaction.emoji} ${r.reaction.label}',
                      style: TextStyle(fontSize: 10, color: Colors.teal.shade600)),
                ]),
              ),
              Icon(
                  _lastCallExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.teal.shade400, size: 18),
            ]),
          ),
        ),
        if (_lastCallExpanded) ...[
          Divider(height: 1, color: Colors.teal.shade50),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.callNotes.isNotEmpty)
                Text(r.callNotes,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              if (r.competitorMentions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('⚠ Competitor: ${r.competitorMentions}',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  // ─── Section Header ───────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(width: 3, height: 16,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 8),
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(title,
          style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
    ]);
  }

  // ─── Reaction Picker ──────────────────────────────────────────────────────────

  Widget _buildReactionPicker() {
    return _card(
      child: Row(
        children: DoctorReaction.values.map((r) {
          final selected = _reaction == r;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _reaction = r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? _reactionColor(r).withValues(alpha: 0.15)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? _reactionColor(r) : Colors.grey.shade200,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(children: [
                  Text(r.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 3),
                  Text(r.label,
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: selected ? _reactionColor(r) : Colors.grey.shade500),
                      textAlign: TextAlign.center),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _reactionColor(DoctorReaction r) {
    switch (r) {
      case DoctorReaction.positive: return Colors.green.shade600;
      case DoctorReaction.receptive: return Colors.blue.shade600;
      case DoctorReaction.neutral: return Colors.grey.shade600;
      case DoctorReaction.objection: return Colors.red.shade600;
      case DoctorReaction.notAvailable: return Colors.orange.shade600;
    }
  }

  // ─── Doctor Availability ──────────────────────────────────────────────────────

  Widget _buildAvailabilityRow() {
    return _card(
      label: 'Doctor Availability',
      child: Row(
        children: _DoctorAvailability.values.map((a) {
          final sel = _doctorAvailability == a;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _doctorAvailability = a),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? a.color.withValues(alpha: 0.12) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: sel ? a.color : Colors.grey.shade200,
                      width: sel ? 1.5 : 1),
                ),
                child: Text(a.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: sel ? a.color : Colors.grey.shade500)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Brands Detailed ──────────────────────────────────────────────────────────

  Widget _buildBrandsSection() {
    if (_effectiveBrands.isEmpty) return const SizedBox.shrink();
    return _card(
      label: 'Brands Detailed',
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: _effectiveBrands.map((b) {
          final selected = _brandsDiscussed.contains(b.id);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) { _brandsDiscussed.remove(b.id); }
              else { _brandsDiscussed.add(b.id); }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? _purple : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? _purple : Colors.grey.shade300),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.check_circle, size: 13, color: Colors.white),
                  ),
                Text(b.name,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.grey.shade700)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Key Messages ─────────────────────────────────────────────────────────────

  Widget _buildKeyMessagesSection() {
    final messages = <String>[];
    for (final b in _effectiveBrands) {
      messages.addAll(_brandMessages[b.name] ?? []);
    }
    if (messages.isEmpty) return const SizedBox.shrink();

    return _card(
      label: 'Key Messages Delivered',
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: messages.map((msg) {
          final selected = _keyMessages.contains(msg);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) { _keyMessages.remove(msg); }
              else { _keyMessages.add(msg); }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: selected ? Colors.green.shade400 : Colors.grey.shade300),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 13,
                  color: selected ? Colors.green.shade600 : Colors.grey.shade400,
                ),
                const SizedBox(width: 5),
                Text(msg,
                    style: TextStyle(
                        fontSize: 11,
                        color: selected ? Colors.green.shade700 : Colors.grey.shade700)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Visit Type Selector ──────────────────────────────────────────────────────

  Widget _buildVisitTypeSelector() {
    return _card(
      label: 'Visit Type',
      child: Container(
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
            items: _VisitType.values.map((v) => DropdownMenuItem(
                  value: v,
                  child: Row(children: [
                    Icon(v.icon, size: 16, color: _purple),
                    const SizedBox(width: 8),
                    Text(v.label, style: const TextStyle(fontSize: 13)),
                  ]),
                )).toList(),
            onChanged: (v) => setState(() => _visitType = v!),
          ),
        ),
      ),
    );
  }

  // ─── Joint Employee Section ───────────────────────────────────────────────────

  Widget _buildJointEmployeeSection() {
    return _card(
      label: 'Co-worker / Accompanying Manager',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          onPressed: _pickEmployees,
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: Text(
              _selectedEmployees.isEmpty
                  ? 'Select Co-worker / Manager'
                  : 'Add More',
              style: const TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _purple,
            side: BorderSide(color: _purple.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    );
  }

  Future<void> _pickEmployees() async {
    final employees = _dcrProv.employees;
    if (employees.isEmpty) {
      _showSnack('No co-workers available in the system.');
      return;
    }

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
              ? employees
              : employees
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
                    onChanged: (v) => setModal(() => searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search by name or designation…',
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
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
                          final isSel = selected.any((s) => s.id == e.id);
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: isSel
                                  ? _purple.withValues(alpha: 0.15)
                                  : Colors.grey.shade100,
                              child: Icon(
                                isSel ? Icons.check : Icons.person_outlined,
                                size: 16,
                                color: isSel ? _purple : Colors.grey.shade400,
                              ),
                            ),
                            title: Text(e.name,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: e.designation.isEmpty
                                ? null
                                : Row(children: [
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
                              if (isSel) {
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
                    child: Text('Confirm (${selected.length} selected)',
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

  // ─── Patient Count ────────────────────────────────────────────────────────────

  Widget _buildPatientCountRow() {
    return _card(
      label: 'Patients Seen in Clinic',
      child: Row(children: [
        Icon(Icons.people_outline_rounded, color: Colors.grey.shade400, size: 18),
        const SizedBox(width: 8),
        Text('Patient count during visit',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const Spacer(),
        _stepBtn(Icons.remove, () {
          if (_patientCount > 0) setState(() => _patientCount--);
        }),
        SizedBox(
          width: 40,
          child: Text('$_patientCount',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        _stepBtn(Icons.add, () => setState(() => _patientCount++)),
      ]),
    );
  }

  // ─── POB ──────────────────────────────────────────────────────────────────────

  Widget _buildPobRow() {
    return _card(
      label: 'POB – Prescription Commitment',
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Text('Doctor committed to prescribe?',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ),
          Switch.adaptive(
            value: _pobCommitted,
            activeThumbColor: Colors.green,
            onChanged: (v) => setState(() => _pobCommitted = v),
          ),
          Text(_pobCommitted ? 'Yes' : 'No',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: _pobCommitted ? Colors.green.shade600 : Colors.grey.shade500)),
        ]),
        if (_pobCommitted) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.format_list_numbered_outlined,
                size: 16, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text('Units committed',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Spacer(),
            _stepBtn(Icons.remove, () {
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
            _stepBtn(Icons.add, () => setState(() => _pobQty++),
                color: Colors.green),
          ]),
        ],
      ]),
    );
  }

  // ─── Promo Material ───────────────────────────────────────────────────────────

  Widget _buildPromoMaterialField() {
    return _card(
      child: TextField(
        controller: _promoMaterialCtrl,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Literature / Promotional material given',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          prefixIcon: const Icon(Icons.card_giftcard_outlined, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  // ─── Sample Distribution ──────────────────────────────────────────────────────

  Widget _buildSamplesSection() {
    final totalUnits = _sampleItems.fold<int>(0, (s, i) => s + i.quantity);
    final productCount = _sampleItems.where((i) => i.quantity > 0).length;

    return _card(
      child: Column(children: [
        // Summary
        if (_sampleItems.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE65100).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFE65100).withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.medication_outlined,
                    size: 18, color: const Color(0xFFE65100)),
                const SizedBox(width: 8),
                Text(
                  '$productCount product${productCount != 1 ? 's' : ''} · '
                  '$totalUnits unit${totalUnits != 1 ? 's' : ''} distributed',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13,
                      color: Color(0xFFE65100)),
                ),
                const Spacer(),
                if (_signaturePath != null) ...[
                  const Icon(Icons.verified_outlined,
                      size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('Signed',
                      style: TextStyle(
                          fontSize: 11, color: Colors.green.shade700,
                          fontWeight: FontWeight.w600)),
                ],
              ]),
              ..._sampleItems.where((i) => i.quantity > 0).map((i) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      Text('• ${i.productName}  ×${i.quantity}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700)),
                      if (i.batchNumber.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('Batch: ${i.batchNumber}',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ]),
                  )),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openSampleSheet,
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

  Future<void> _openSampleSheet() async {
    final result = await Navigator.push<DcrSampleSheetResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _dcrProv,
          child: DcrSampleSheetScreen(
            initialItems: _sampleItems,
            initialSignaturePath: _signaturePath,
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _sampleItems = result.items;
        _signaturePath = result.signaturePath;
      });
    }
  }

  // ─── Voice Note ───────────────────────────────────────────────────────────────

  Widget _buildVoiceNoteSection() {
    return _card(
      label: 'Voice Note',
      child: Column(children: [
        if (!_hasRecording) _buildRecordButton(),
        if (_hasRecording) _buildPlaybackRow(),
        if (_recording) ...[
          const SizedBox(height: 10),
          _buildWaveform(),
        ],
        if (_hasRecording && _transcript.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Transcript',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: Colors.blue.shade700)),
              const SizedBox(height: 4),
              Text(_transcript,
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildRecordButton() {
    return Row(children: [
      AnimatedBuilder(
        animation: _micPulseCtrl,
        builder: (_, child) => GestureDetector(
          onTap: _recording ? _stopRecording : _startRecording,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _recording ? 52 + _micPulseCtrl.value * 4 : 52,
            height: _recording ? 52 + _micPulseCtrl.value * 4 : 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _recording ? Colors.red.shade600 : _purple,
              boxShadow: _recording
                  ? [BoxShadow(
                      color: Colors.red.shade300.withValues(alpha: 0.5),
                      blurRadius: 10 + _micPulseCtrl.value * 8,
                      spreadRadius: 2)]
                  : [],
            ),
            child: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white, size: 24),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _recording
                ? 'Recording… ${_fmtTime(_recordSeconds)}'
                : 'Tap to record voice note',
            style: TextStyle(
                fontSize: 13,
                fontWeight: _recording ? FontWeight.w600 : FontWeight.normal,
                color: _recording ? Colors.red.shade700 : Colors.grey.shade700),
          ),
          if (!_recording)
            Text('Saved with the call report',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ]),
      ),
    ]);
  }

  Widget _buildPlaybackRow() {
    return Row(children: [
      GestureDetector(
        onTap: _togglePlayback,
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: _purple.withValues(alpha: 0.1)),
          child: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: _purple, size: 22),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Voice note recorded',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
          Text(_fmtTime(_recordSeconds),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      ),
      if (!_transcribing)
        TextButton.icon(
          onPressed: _transcribeVoice,
          icon: const Icon(Icons.text_snippet_outlined, size: 14),
          label: const Text('Transcribe', style: TextStyle(fontSize: 11)),
          style: TextButton.styleFrom(foregroundColor: Colors.blue.shade700),
        )
      else
        const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
      IconButton(
        onPressed: _deleteRecording,
        icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    ]);
  }

  Widget _buildWaveform() {
    return AnimatedBuilder(
      animation: _micPulseCtrl,
      builder: (_, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(16, (i) {
          final h = 8.0 + (i % 3 == 0
              ? _micPulseCtrl.value * 18
              : i % 2 == 0
                  ? (1 - _micPulseCtrl.value) * 12
                  : 8);
          return AnimatedContainer(
            duration: Duration(milliseconds: 100 + i * 20),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 3, height: h,
            decoration: BoxDecoration(
                color: Colors.red.shade400, borderRadius: BorderRadius.circular(2)),
          );
        }),
      ),
    );
  }

  // ─── Topics ───────────────────────────────────────────────────────────────────

  Widget _buildTopicsSection() {
    return _card(
      label: 'Discussion Topics',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_topics.isNotEmpty) ...[
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _topics.map((t) => Chip(
                  label: Text(t, style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 13),
                  onDeleted: () => setState(() => _topics.remove(t)),
                  backgroundColor: Colors.blue.shade50,
                  side: BorderSide(color: Colors.blue.shade200),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
          ),
          const SizedBox(height: 8),
        ],
        Row(children: [
          Expanded(
            child: TextField(
              controller: _topicCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Add topic (e.g. Renal dosing)',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              onSubmitted: _addTopic,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _addTopic(_topicCtrl.text),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: _purple, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
          ),
        ]),
      ]),
    );
  }

  void _addTopic(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() {
      if (!_topics.contains(t)) _topics.add(t);
      _topicCtrl.clear();
    });
  }

  // ─── Notes ────────────────────────────────────────────────────────────────────

  Widget _buildNotesField() {
    return _card(
      label: 'Call Notes',
      child: TextField(
        controller: _notesCtrl,
        maxLines: 4,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Key discussion points, outcomes, objections…',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding: const EdgeInsets.all(12),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon) {
    return _card(
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  // ─── Next Call ────────────────────────────────────────────────────────────────

  Widget _buildNextCallRow() {
    return _card(
      label: 'Next Call Date',
      child: GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _nextCallDate != null ? Colors.green.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _nextCallDate != null
                  ? Colors.green.shade300
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(children: [
            Icon(Icons.event_outlined,
                color: _nextCallDate != null
                    ? Colors.green.shade600
                    : Colors.grey.shade400,
                size: 18),
            const SizedBox(width: 10),
            Text(
              _nextCallDate != null
                  ? DateFormat('EEEE, d MMMM yyyy').format(_nextCallDate!)
                  : 'Tap to schedule next call',
              style: TextStyle(
                  fontSize: 13,
                  color: _nextCallDate != null
                      ? Colors.green.shade700
                      : Colors.grey.shade500),
            ),
            if (_nextCallDate != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _nextCallDate = null),
                child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextCallDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _purple)),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _nextCallDate = picked);
  }

  // ─── Bottom Bar ───────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, -2))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: Text(
                _saving ? 'Submitting…' : 'Submit Final Report & DCR',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _savingDraft ? null : _saveDraft,
            icon: _savingDraft
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined, size: 18),
            label: Text('Save as Draft (Resume from DCR Later)',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade700,
              side: BorderSide(color: Colors.orange.shade300),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  // ─── Submit ───────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _saving = true);
    final prov = context.read<ClmProvider>();
    try {
      if (_recording) await _stopRecording();

      final dcrExtras = json.encode({
        'visitType': _visitType.key,
        'doctorAvailability': _doctorAvailability.key,
        'employees': _selectedEmployees.map((e) => e.name).join(', '),
        'patientCount': _patientCount,
        'pobCommitted': _pobCommitted,
        'pobQty': _pobQty,
        'promoMaterial': _promoMaterialCtrl.text.trim(),
        'nextAction': _nextActionCtrl.text.trim(),
        'samples': _sampleItems
            .where((i) => i.quantity > 0)
            .map((i) => '${i.productName}×${i.quantity}')
            .join(', '),
      });

      final sessionId = widget.session?.id ?? const Uuid().v4();

      final report = ClmCallReport(
        id: const Uuid().v4(),
        sessionId: sessionId,
        doctorId: widget.doctor.id,
        createdAt: DateTime.now(),
        brandsDiscussed: _brandsDiscussed.toList(),
        reaction: _reaction,
        callNotes: _notesCtrl.text.trim(),
        topicsDiscussed: _topics,
        keyMessagesDelivered: _keyMessages.toList(),
        nextCallPlan: dcrExtras,
        nextCallDate: _nextCallDate,
        samplesGiven: _sampleItems.fold(0, (s, i) => s + i.quantity),
        competitorMentions: _competitorCtrl.text.trim(),
        voiceNotePath: _voiceNotePath,
        voiceNoteTranscript: _transcript.isNotEmpty ? _transcript : null,
      );

      await prov.saveCallReport(report);
      if (_nextCallDate != null) {
        await prov.updateDoctorNextCallDate(widget.doctor.id, _nextCallDate);
      }
      await _clearDraft();

      if (mounted) {
        _showSnack('Report & DCR submitted!');
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.pop(context, report);
      }
    } catch (e) {
      if (mounted) _showSnack('Submit failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Voice Helpers ────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      final granted = await _recorder.hasPermission();
      if (!granted) {
        _showSnack('Microphone permission required.', isError: true);
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'clm', 'voice',
          'note_${DateTime.now().millisecondsSinceEpoch}.m4a');
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
      _showSnack('Recording failed: $e', isError: true);
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordTimer?.cancel();
      await _recorder.stop();
      setState(() { _recording = false; _hasRecording = true; });
    } catch (_) {
      setState(() => _recording = false);
    }
  }

  Future<void> _togglePlayback() async {
    if (_voiceNotePath == null) return;
    try {
      if (_playing) {
        await _player.stop();
        setState(() => _playing = false);
      } else {
        _player.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playing = false);
        });
        await _player.play(DeviceFileSource(_voiceNotePath!));
        setState(() => _playing = true);
      }
    } catch (_) {
      setState(() => _playing = false);
    }
  }

  Future<void> _deleteRecording() async {
    await _player.stop();
    if (_voiceNotePath != null) {
      final f = File(_voiceNotePath!);
      if (await f.exists()) await f.delete();
    }
    setState(() {
      _recording = false;
      _hasRecording = false;
      _playing = false;
      _voiceNotePath = null;
      _transcript = '';
      _recordSeconds = 0;
    });
  }

  Future<void> _transcribeVoice() async {
    setState(() => _transcribing = true);
    try {
      final available = await _stt.initialize();
      if (!available) {
        if (mounted) {
          setState(() => _transcribing = false);
          _showSnack('Speech recognition not available.', isError: true);
        }
        return;
      }
      await _stt.listen(
        onResult: (r) {
          if (mounted) setState(() => _transcript = r.recognizedWords);
          if (r.finalResult) {
            _stt.stop();
            if (mounted) {
              setState(() => _transcribing = false);
              if (_transcript.isNotEmpty) {
                final existing = _notesCtrl.text.trim();
                _notesCtrl.text = existing.isEmpty
                    ? _transcript
                    : '$existing\n$_transcript';
              }
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _transcribing = false);
        _showSnack('Transcription error: $e', isError: true);
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  Widget _card({String? label, required Widget child}) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, label != null ? 10 : 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label != null) ...[
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _purple)),
          const SizedBox(height: 8),
        ],
        child,
      ]),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap, {Color? color}) {
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

  String _fmtTime(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: isError ? 4 : 2),
    ));
  }
}
