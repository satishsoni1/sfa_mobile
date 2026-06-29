import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/clm_models.dart';
import '../../data/models/dcr_models.dart';
import '../../providers/clm_provider.dart';
import '../../providers/dcr_provider.dart';
import '../clm/clm_merged_call_dcr_screen.dart';
import 'dcr_doctor_visit_screen.dart';
import 'dcr_chemist_visit_screen.dart';

// ─── Pending CLM draft (read from SharedPreferences) ─────────────────────────

class _ClmDraft {
  final int doctorId;
  final String doctorName;
  final String doctorSpeciality;
  final String prefsKey;
  final DateTime savedAt;
  final String reaction;
  final List<int> brandIds;

  const _ClmDraft({
    required this.doctorId,
    required this.doctorName,
    this.doctorSpeciality = '',
    required this.prefsKey,
    required this.savedAt,
    this.reaction = 'neutral',
    this.brandIds = const [],
  });

  /// Reconstruct a minimal ClmDoctor so we can open ClmMergedCallDcrScreen.
  ClmDoctor toMinimalDoctor() => ClmDoctor(
        id: doctorId,
        name: doctorName,
        speciality: doctorSpeciality,
        category: 'C',
        territory: '',
        area: '',
        mobile: '',
      );
}

class DcrDashboardScreen extends StatefulWidget {
  const DcrDashboardScreen({super.key});

  @override
  State<DcrDashboardScreen> createState() => _DcrDashboardScreenState();
}

class _DcrDashboardScreenState extends State<DcrDashboardScreen> {
  static const _purple = Color(0xFF4A148C);
  static const _teal = Color(0xFF00695C);

  List<_ClmDraft> _clmDrafts = [];
  bool _draftsLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DcrProvider>().init();
        _loadClmDrafts();
      }
    });
  }

  // ─── Load pending CLM drafts from SharedPreferences ────────────────────────

  Future<void> _loadClmDrafts() async {
    setState(() => _draftsLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('clm_draft_')).toList();
      final drafts = <_ClmDraft>[];

      for (final key in keys) {
        try {
          final raw = prefs.getString(key);
          if (raw == null) continue;
          final data = json.decode(raw) as Map<String, dynamic>;

          // Extract doctorId from key (clm_draft_{doctorId})
          final doctorId = int.tryParse(key.replaceFirst('clm_draft_', ''));
          if (doctorId == null) continue;

          // Get doctor name from CLM provider brands/visits or from draft data
          final savedAt = data['savedAt'] != null
              ? DateTime.tryParse(data['savedAt'].toString()) ?? DateTime.now()
              : DateTime.now();

          final brandIds = (data['brands'] as List? ?? [])
              .map((e) => (e as num).toInt())
              .toList();

          drafts.add(_ClmDraft(
            doctorId: doctorId,
            doctorName: data['doctorName']?.toString() ?? 'Doctor #$doctorId',
            doctorSpeciality: data['doctorSpeciality']?.toString() ?? '',
            prefsKey: key,
            savedAt: savedAt,
            reaction: data['reaction'] ?? 'neutral',
            brandIds: brandIds,
          ));
        } catch (_) {}
      }

      if (mounted) setState(() { _clmDrafts = drafts; _draftsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _draftsLoading = false);
    }
  }

  Future<void> _discardClmDraft(_ClmDraft draft) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Discard Draft',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: const Text(
            'This will permanently delete this pending call report draft.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(draft.prefsKey);
      _loadClmDrafts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Daily Call Report',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 16)),
          Text(DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () {
              context.read<DcrProvider>().loadTodaySummary();
              _loadClmDrafts();
            },
          ),
        ],
      ),
      body: Consumer<DcrProvider>(
        builder: (context, prov, _) {
          if (prov.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async {
              await prov.loadTodaySummary();
              await _loadClmDrafts();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
              children: [
                _buildStatRow(prov),
                const SizedBox(height: 18),

                // ── Pending CLM Drafts ─────────────────────────────────────
                if (!_draftsLoading && _clmDrafts.isNotEmpty) ...[
                  _buildSectionHeader(
                      'Pending Call Reports (CLM)',
                      Icons.pending_actions_outlined,
                      Colors.amber.shade700,
                      _clmDrafts.length),
                  const SizedBox(height: 8),
                  ..._clmDrafts.map((d) => _buildClmDraftCard(d)),
                  const SizedBox(height: 18),
                ],

                // ── Doctor Visits ──────────────────────────────────────────
                _buildSectionHeader('Doctor Visits', Icons.person_outline,
                    _purple, prov.todaySummary.doctorVisits.length),
                const SizedBox(height: 8),
                if (prov.todaySummary.doctorVisits.isEmpty)
                  _buildEmptyCard('No doctor visits recorded today',
                      Icons.person_add_outlined)
                else
                  ...prov.todaySummary.doctorVisits
                      .map((v) => _buildDoctorVisitCard(context, v, prov)),
                const SizedBox(height: 18),

                // ── Chemist Visits ─────────────────────────────────────────
                _buildSectionHeader('Chemist Visits', Icons.store_outlined,
                    _teal, prov.todaySummary.chemistVisits.length),
                const SizedBox(height: 8),
                if (prov.todaySummary.chemistVisits.isEmpty)
                  _buildEmptyCard('No chemist visits recorded today',
                      Icons.store_mall_directory_outlined)
                else
                  ...prov.todaySummary.chemistVisits
                      .map((v) => _buildChemistVisitCard(context, v, prov)),
                const SizedBox(height: 18),

                _buildSubmitButton(prov),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  // ─── Stat Row ─────────────────────────────────────────────────────────────────

  Widget _buildStatRow(DcrProvider prov) {
    final s = prov.todaySummary;
    return Row(children: [
      _statCard('Doctor\nVisits', '${s.doctorVisits.length}', _purple,
          Icons.medical_services_outlined),
      const SizedBox(width: 8),
      _statCard('Chemist\nVisits', '${s.chemistVisits.length}', _teal,
          Icons.store_outlined),
      const SizedBox(width: 8),
      _statCard('Samples\nGiven', '${s.totalSamples}',
          const Color(0xFFE65100), Icons.medication_outlined),
      const SizedBox(width: 8),
      _statCard('Drafts', '${s.draftCount + _clmDrafts.length}',
          Colors.amber.shade700, Icons.pending_actions_outlined),
    ]);
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 5),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 9, color: Colors.grey.shade600, height: 1.3)),
        ]),
      ),
    );
  }

  // ─── Section Header ───────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
      String title, IconData icon, Color color, int count) {
    return Row(children: [
      Container(
        width: 3, height: 16,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      ),
      const SizedBox(width: 8),
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 6),
      Text(title,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: 14,
              color: const Color(0xFF1A1A2E))),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  // ─── CLM Draft Card ───────────────────────────────────────────────────────────

  Widget _buildClmDraftCard(_ClmDraft draft) {
    final daysAgo = DateTime.now().difference(draft.savedAt).inDays;
    final timeLabel = daysAgo == 0
        ? 'Today, ${DateFormat('hh:mm a').format(draft.savedAt)}'
        : '$daysAgo day${daysAgo != 1 ? 's' : ''} ago';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade300, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _resumeClmDraft(draft),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.pending_actions_outlined,
                    color: Colors.amber.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(draft.doctorName,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  if (draft.doctorSpeciality.isNotEmpty)
                    Text(draft.doctorSpeciality,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  Text('CLM Draft  ·  $timeLabel',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade400)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('PENDING',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade800)),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _discardClmDraft(draft),
                  child: Icon(Icons.delete_outline,
                      size: 18, color: Colors.red.shade300),
                ),
              ]),
            ]),
            if (draft.brandIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6, runSpacing: 4,
                children: draft.brandIds.take(4).map((id) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text('Brand #$id',
                      style: TextStyle(
                          fontSize: 10, color: Colors.amber.shade800)),
                )).toList(),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _resumeClmDraft(draft),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('Resume & Fill Report',
                    style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _resumeClmDraft(_ClmDraft draft) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ClmProvider()..init(),
          child: ClmMergedCallDcrScreen(
            doctor: draft.toMinimalDoctor(),
            // session is null — draft-resume mode
          ),
        ),
      ),
    ).then((_) => _loadClmDrafts()); // refresh draft list after return
  }

  // ─── Empty Card ───────────────────────────────────────────────────────────────

  Widget _buildEmptyCard(String msg, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 20, color: Colors.grey.shade300),
        const SizedBox(width: 10),
        Text(msg, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      ]),
    );
  }

  // ─── Doctor Visit Card ────────────────────────────────────────────────────────

  Widget _buildDoctorVisitCard(
      BuildContext context, DcrDoctorVisit visit, DcrProvider prov) {
    final isDraft = visit.status.isDraft;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDraft
              ? Colors.orange.withValues(alpha: 0.4)
              : Colors.green.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDoctorVisit(context, existingVisit: visit),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_outline, color: _purple, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(visit.doctorName,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.access_time_outlined,
                      size: 11, color: Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Text(
                    '${_fmtTime(visit.visitStartTime)}'
                    '${visit.visitEndTime != null ? ' – ${_fmtTime(visit.visitEndTime!)}' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ]),
              ]),
            ),
            _statusBadge(isDraft),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade400),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (v) async {
                if (v == 'edit') {
                  _openDoctorVisit(context, existingVisit: visit);
                } else {
                  final ok = await _confirmDelete(context);
                  if (ok == true) await prov.deleteDoctorVisit(visit.id!);
                }
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ─── Chemist Visit Card ───────────────────────────────────────────────────────

  Widget _buildChemistVisitCard(
      BuildContext context, DcrChemistVisit visit, DcrProvider prov) {
    final isDraft = visit.status.isDraft;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDraft
              ? Colors.orange.withValues(alpha: 0.4)
              : Colors.green.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openChemistVisit(context, existing: visit),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.store_outlined, color: _teal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(visit.chemistName,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.access_time_outlined,
                      size: 11, color: Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Text(_fmtTime(visit.visitStartTime),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                  if (visit.productAvailable) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_outline,
                        size: 11, color: Colors.green),
                    const SizedBox(width: 2),
                    const Text('Available',
                        style: TextStyle(fontSize: 10, color: Colors.green)),
                  ],
                  if (visit.pobUnits > 0) ...[
                    const SizedBox(width: 8),
                    Text('POB: ${visit.pobUnits}',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFFE65100))),
                  ],
                ]),
              ]),
            ),
            _statusBadge(isDraft),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade400),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (v) async {
                if (v == 'edit') {
                  _openChemistVisit(context, existing: visit);
                } else {
                  final ok = await _confirmDelete(context);
                  if (ok == true) await prov.deleteChemistVisit(visit.id!);
                }
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ─── Submit Button ────────────────────────────────────────────────────────────

  Widget _buildSubmitButton(DcrProvider prov) {
    final s = prov.todaySummary;
    final canSubmit = s.allSubmitted && _clmDrafts.isEmpty;
    final totalDrafts = s.draftCount + _clmDrafts.length;

    return Column(children: [
      if (totalDrafts > 0)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$totalDrafts report${totalDrafts > 1 ? 's' : ''} pending. '
                'Complete all before final DCR submission.',
                style: TextStyle(
                    fontSize: 12, color: Colors.orange.shade800),
              ),
            ),
          ]),
        ),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: canSubmit ? () => _submitDcr(context) : null,
          icon: const Icon(Icons.send_outlined),
          label: Text(
            canSubmit
                ? 'Submit Today\'s DCR'
                : s.doctorVisits.isEmpty && s.chemistVisits.isEmpty
                    ? 'Add Visits to Submit DCR'
                    : 'Complete All Reports to Submit',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: canSubmit ? _purple : Colors.grey.shade300,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ]);
  }

  // ─── FAB ──────────────────────────────────────────────────────────────────────

  Widget _buildFab(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'fab_doctor',
          onPressed: () => _openDoctorVisit(context),
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add_outlined),
          label: Text('Doctor Visit',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          heroTag: 'fab_chemist',
          onPressed: () => _openChemistVisit(context),
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.store_outlined),
          label: Text('Chemist Visit',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  Widget _statusBadge(bool isDraft) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDraft
            ? Colors.orange.withValues(alpha: 0.12)
            : Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isDraft ? 'Draft' : 'Done',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDraft ? Colors.orange.shade700 : Colors.green.shade700,
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) => DateFormat('hh:mm a').format(dt);

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Delete Visit',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: const Text('This visit and all its data will be deleted.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

  void _openDoctorVisit(BuildContext context,
      {DcrDoctorVisit? existingVisit}) {
    final prov = context.read<DcrProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: DcrDoctorVisitScreen(existingVisit: existingVisit),
        ),
      ),
    ).then((_) => prov.loadTodaySummary());
  }

  void _openChemistVisit(BuildContext context, {DcrChemistVisit? existing}) {
    final prov = context.read<DcrProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: DcrChemistVisitScreen(existingVisit: existing),
        ),
      ),
    ).then((_) => prov.loadTodaySummary());
  }

  void _submitDcr(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.send_outlined, color: Color(0xFF4A148C)),
          const SizedBox(width: 10),
          Text('Submit DCR',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
            'Submit today\'s Daily Call Report? All visits will be marked as final.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _purple, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('DCR submitted successfully! Pending sync.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
