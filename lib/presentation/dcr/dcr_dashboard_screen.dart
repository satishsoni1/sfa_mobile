import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/dcr_models.dart';
import '../../providers/dcr_provider.dart';
import 'dcr_doctor_visit_screen.dart';
import 'dcr_chemist_visit_screen.dart';

class DcrDashboardScreen extends StatefulWidget {
  const DcrDashboardScreen({super.key});

  @override
  State<DcrDashboardScreen> createState() => _DcrDashboardScreenState();
}

class _DcrDashboardScreenState extends State<DcrDashboardScreen> {
  static const _purple = Color(0xFF4A148C);
  static const _teal = Color(0xFF00695C);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DcrProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Call Report',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            Text(DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () => context.read<DcrProvider>().loadTodaySummary(),
          ),
        ],
      ),
      body: Consumer<DcrProvider>(
        builder: (context, prov, _) {
          if (prov.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () => prov.loadTodaySummary(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                _buildStatRow(prov),
                const SizedBox(height: 20),
                _buildSectionHeader('Doctor Visits', Icons.person_outline,
                    _purple, prov.todaySummary.doctorVisits.length),
                const SizedBox(height: 8),
                if (prov.todaySummary.doctorVisits.isEmpty)
                  _buildEmptyCard('No doctor visits recorded today',
                      Icons.person_add_outlined)
                else
                  ...prov.todaySummary.doctorVisits
                      .map((v) => _buildDoctorVisitCard(context, v, prov)),
                const SizedBox(height: 20),
                _buildSectionHeader('Chemist Visits', Icons.store_outlined,
                    _teal, prov.todaySummary.chemistVisits.length),
                const SizedBox(height: 8),
                if (prov.todaySummary.chemistVisits.isEmpty)
                  _buildEmptyCard('No chemist visits recorded today',
                      Icons.store_mall_directory_outlined)
                else
                  ...prov.todaySummary.chemistVisits
                      .map((v) => _buildChemistVisitCard(context, v, prov)),
                const SizedBox(height: 20),
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
      const SizedBox(width: 10),
      _statCard('Chemist\nVisits', '${s.chemistVisits.length}', _teal,
          Icons.store_outlined),
      const SizedBox(width: 10),
      _statCard('Samples\nGiven', '${s.totalSamples}',
          const Color(0xFFE65100), Icons.medication_outlined),
    ]);
  }

  Widget _statCard(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  height: 1.3)),
        ]),
      ),
    );
  }

  // ─── Section Header ───────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
      String title, IconData icon, Color color, int count) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(title,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 15,
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
        Text(msg,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
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
            CircleAvatar(
              radius: 20,
              backgroundColor: _purple.withValues(alpha: 0.1),
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
                    Text(
                      '${_fmtTime(visit.visitStartTime)}${visit.visitEndTime != null ? ' – ${_fmtTime(visit.visitEndTime!)}' : ''}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ]),
            ),
            _statusBadge(isDraft),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  size: 18, color: Colors.grey.shade400),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child:
                        Text('Delete', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (v) async {
                if (v == 'edit') {
                  _openDoctorVisit(context, existingVisit: visit);
                } else if (v == 'delete') {
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
            CircleAvatar(
              radius: 20,
              backgroundColor: _teal.withValues(alpha: 0.1),
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
                      Text(_fmtTime(visit.visitStartTime),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                      if (visit.productAvailable) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle_outline,
                            size: 12, color: Colors.green),
                        const SizedBox(width: 2),
                        const Text('Available',
                            style: TextStyle(
                                fontSize: 10, color: Colors.green)),
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
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  size: 18, color: Colors.grey.shade400),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child:
                        Text('Delete', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (v) async {
                if (v == 'edit') {
                  _openChemistVisit(context, existing: visit);
                } else if (v == 'delete') {
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
    final canSubmit = s.allSubmitted;
    final draftCount = s.draftCount;
    return Column(children: [
      if (draftCount > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline,
                  size: 14, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Text(
                '$draftCount visit${draftCount > 1 ? 's' : ''} still in draft. Submit all before final DCR submission.',
                style: TextStyle(
                    fontSize: 12, color: Colors.orange.shade700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
                    : 'Complete All Visits to Submit',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: canSubmit ? _purple : Colors.grey.shade300,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDraft
            ? Colors.orange.withValues(alpha: 0.12)
            : Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isDraft ? 'Draft' : 'Submitted',
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
          content:
              const Text('This visit and all its data will be deleted.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white),
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

  void _openChemistVisit(BuildContext context,
      {DcrChemistVisit? existing}) {
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
        title: Text('Submit DCR',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: const Text(
            'Are you sure you want to submit today\'s Daily Call Report? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _purple, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'DCR submitted successfully! Pending sync.'),
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
