import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/clm_models.dart';
import '../../providers/clm_provider.dart';
import 'clm_checkin_screen.dart';

class ClmPreCallScreen extends StatefulWidget {
  final ClmDoctor doctor;
  const ClmPreCallScreen({super.key, required this.doctor});

  @override
  State<ClmPreCallScreen> createState() => _ClmPreCallScreenState();
}

class _ClmPreCallScreenState extends State<ClmPreCallScreen> {
  static const _purple = Color(0xFF4A148C);

  AiDoctorInsight? _insight;
  ClmCallReport? _lastReport;
  List<ClmBrand> _brands = [];
  bool _loading = true;
  bool _briefExpanded = true;
  bool _lastCallExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final prov = context.read<ClmProvider>();
    try {
      final results = await Future.wait([
        prov.getAiInsightForDoctor(widget.doctor),
        prov.getCallReportsForDoctor(widget.doctor.id),
        prov.getBrandsForDoctor(widget.doctor),
      ]);
      if (!mounted) return;
      setState(() {
        _insight = results[0] as AiDoctorInsight;
        final reports = results[1] as List<ClmCallReport>;
        _lastReport = reports.isNotEmpty ? reports.first : null;
        _brands = results[2] as List<ClmBrand>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text('Pre-Call Brief',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildDoctorHeader(),
          Expanded(
            child: _loading
                ? _buildLoading()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                    child: Column(children: [
                      _buildAiBrief(),
                      const SizedBox(height: 12),
                      _buildLastCallCard(),
                      const SizedBox(height: 12),
                      _buildDoctorStats(),
                    ]),
                  ),
          ),
          _buildCheckInBar(),
        ],
      ),
    );
  }

  // ─── Doctor Header ────────────────────────────────────────────────────────────

  Widget _buildDoctorHeader() {
    final d = widget.doctor;
    final catColor = _catColor(d.category);
    return Container(
      color: _purple,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: Text(d.initials,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 2),
            Text('${d.speciality}  ·  Cat ${d.category}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (d.hospital != null && d.hospital!.isNotEmpty)
              Text(d.hospital!,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20)),
          child: Text('Cat ${d.category}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ]),
    );
  }

  // ─── Loading ──────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(color: _purple, strokeWidth: 3),
        const SizedBox(height: 16),
        Text('Preparing AI Brief…',
            style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14)),
      ]),
    );
  }

  // ─── AI Brief Card ────────────────────────────────────────────────────────────

  Widget _buildAiBrief() {
    if (_insight == null) {
      return _infoCard(
        icon: Icons.auto_awesome_rounded,
        iconColor: Colors.blue.shade600,
        title: 'AI Pre-Call Brief',
        child: Text('AI analysis not available.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      );
    }

    final insight = _insight!;
    return _expandableCard(
      icon: Icons.auto_awesome_rounded,
      iconColor: const Color(0xFF0277BD),
      title: 'AI Pre-Call Brief',
      subtitle: 'Engagement: ${insight.engagementScore}/100 · ${insight.engagementLevel}',
      subtitleColor: _engagementColor(insight.engagementLevel),
      expanded: _briefExpanded,
      onToggle: () => setState(() => _briefExpanded = !_briefExpanded),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Engagement score badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _engagementColor(insight.engagementLevel).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _engagementColor(insight.engagementLevel).withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bar_chart_rounded,
                size: 14, color: _engagementColor(insight.engagementLevel)),
            const SizedBox(width: 5),
            Text(
              '${insight.engagementScore}/100 · ${insight.engagementLevel}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _engagementColor(insight.engagementLevel)),
            ),
          ]),
        ),
        if (insight.preCallSummary.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(insight.preCallSummary,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade800, height: 1.5)),
        ],
        if (insight.highlights.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...insight.highlights.take(4).map((h) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h.label,
                      style: GoogleFonts.poppins(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                  Text(h.detail,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ]),
              ),
            ]),
          )),
        ],
        // Recommended brands
        if (insight.brandRecs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Recommended Brands',
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: insight.brandRecs.take(4).map((rec) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _purple.withValues(alpha: 0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.medication_outlined, size: 12, color: _purple),
                const SizedBox(width: 4),
                Text(rec.brand.name,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: _purple)),
                const SizedBox(width: 4),
                Text('${rec.score}%',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ]),
            )).toList(),
          ),
        ],
        // Script tips
        if (insight.scriptTips.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Talking Points',
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          ...insight.scriptTips.take(3).map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.arrow_right_rounded, size: 16, color: Colors.blue.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(tip,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ),
            ]),
          )),
        ],
      ]),
    );
  }

  // ─── Last Call Card ───────────────────────────────────────────────────────────

  Widget _buildLastCallCard() {
    if (_lastReport == null) {
      return _infoCard(
        icon: Icons.history_rounded,
        iconColor: Colors.grey.shade400,
        title: 'Last Call Analysis',
        child: Row(children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text('No previous calls recorded for this doctor.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ]),
      );
    }

    final r = _lastReport!;
    final daysAgo = DateTime.now().difference(r.createdAt).inDays;
    final dateStr = DateFormat('d MMM yyyy').format(r.createdAt);

    return _expandableCard(
      icon: Icons.history_rounded,
      iconColor: Colors.teal.shade600,
      title: 'Last Call Analysis',
      subtitle: '$dateStr  (${daysAgo == 0 ? "today" : "${daysAgo}d ago"})',
      subtitleColor: Colors.teal.shade600,
      expanded: _lastCallExpanded,
      onToggle: () => setState(() => _lastCallExpanded = !_lastCallExpanded),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Reaction
        Row(children: [
          Text(r.reaction.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.reaction.label,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14,
                    color: _reactionColor(r.reaction))),
            Text('Doctor reaction last call',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ]),
        ]),
        // Brands discussed
        if (r.brandsDiscussed.isNotEmpty) ...[
          const SizedBox(height: 12),
          _miniLabel('Brands Discussed'),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6, runSpacing: 4,
            children: r.brandsDiscussed.map((bId) {
              final b = _brands.where((x) => x.id == bId).firstOrNull;
              return _tag(b?.name ?? 'Brand #$bId',
                  Colors.teal.shade50, Colors.teal.shade200, Colors.teal.shade700);
            }).toList(),
          ),
        ],
        // Key messages
        if (r.keyMessagesDelivered.isNotEmpty) ...[
          const SizedBox(height: 12),
          _miniLabel('Key Messages Delivered'),
          const SizedBox(height: 5),
          ...r.keyMessagesDelivered.take(3).map((msg) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check_circle_outline, size: 13, color: Colors.green.shade400),
              const SizedBox(width: 5),
              Expanded(
                child: Text(msg,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ),
            ]),
          )),
        ],
        // Notes
        if (r.callNotes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _miniLabel('Call Notes'),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(r.callNotes,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                maxLines: 4, overflow: TextOverflow.ellipsis),
          ),
        ],
        // Competitor
        if (r.competitorMentions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade600),
              const SizedBox(width: 6),
              Text('Competitor mentioned: ${r.competitorMentions}',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
            ]),
          ),
        ],
        // Next call plan
        if (r.nextCallPlan.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.event_note_outlined, size: 14, color: Colors.blue.shade400),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Action: ${r.nextCallPlan}',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
            ),
          ]),
        ],
      ]),
    );
  }

  // ─── Doctor Stats ─────────────────────────────────────────────────────────────

  Widget _buildDoctorStats() {
    final d = widget.doctor;
    return _infoCard(
      icon: Icons.analytics_outlined,
      iconColor: Colors.indigo,
      title: 'Doctor Stats',
      child: Row(children: [
        _statChip('Visits', '${d.totalSessions}', Colors.indigo),
        const SizedBox(width: 8),
        _statChip('Target/Month', '${d.callFrequencyTarget}', Colors.teal),
        const SizedBox(width: 8),
        _statChip(
          'Priority',
          d.priority == 1 ? 'High' : d.priority == 2 ? 'Medium' : 'Low',
          d.priority == 1 ? Colors.red : d.priority == 2 ? Colors.orange : Colors.blue,
        ),
      ]),
    );
  }

  // ─── Check In Bar ─────────────────────────────────────────────────────────────

  Widget _buildCheckInBar() {
    return Consumer<ClmProvider>(
      builder: (_, prov, _) {
        final sameDocActive = prov.isSameDocCheckedIn(widget.doctor.id);
        final conflicting = prov.hasConflictingSession(widget.doctor.id);
        final activeSession = prov.activeSession;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, -3))
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Auto-checkout warning banner
            if (conflicting && activeSession != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Active session for ${activeSession.doctorName} will be '
                      'auto-checked out when you check in here.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.orange.shade800),
                    ),
                  ),
                ]),
              ),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: sameDocActive
                  ? ElevatedButton.icon(
                      onPressed: _goToCheckIn,
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: Text('Resume Detailing',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _goToCheckIn,
                      icon: const Icon(
                          Icons.check_circle_outline_rounded, size: 22),
                      label: Text('Check In & Start Detailing',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
            ),
          ]),
        );
      },
    );
  }

  void _goToCheckIn() {
    final prov = context.read<ClmProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: ClmCheckInScreen(doctor: widget.doctor),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  Color _catColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'A': return Colors.red.shade600;
      case 'B': return Colors.orange.shade600;
      default: return Colors.blue.shade600;
    }
  }

  Color _engagementColor(String level) {
    switch (level.toLowerCase()) {
      case 'high': return Colors.green.shade600;
      case 'medium': return Colors.orange.shade600;
      case 'low': return Colors.red.shade500;
      default: return Colors.grey.shade600;
    }
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

  Widget _miniLabel(String text) => Text(text,
      style: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600));

  Widget _tag(String label, Color bg, Color border, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border)),
    child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
  );

  Widget _statChip(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        Text(label,
            style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8)),
            textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _expandableCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? subtitleColor,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 13,
                          color: Colors.black87)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 10,
                            color: subtitleColor ?? Colors.grey.shade500,
                            fontWeight: FontWeight.w600)),
                ]),
              ),
              Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey.shade400),
            ]),
          ),
        ),
        if (expanded) ...[
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ],
      ]),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
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
              blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87)),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}
