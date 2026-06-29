import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/models/ai_hub_models.dart';
import '../../providers/ai_hub_provider.dart';

class AiEmployeeReportsScreen extends StatefulWidget {
  const AiEmployeeReportsScreen({super.key});

  @override
  State<AiEmployeeReportsScreen> createState() =>
      _AiEmployeeReportsScreenState();
}

class _AiEmployeeReportsScreenState extends State<AiEmployeeReportsScreen>
    with SingleTickerProviderStateMixin {
  static const _red = Color(0xFFBF360C);
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiHubProvider>().loadEmployeePerformance();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.groups, size: 18),
          const SizedBox(width: 8),
          Text('Employee Reports',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: _red,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<AiHubProvider>(
            builder: (ctx, prov, child) => IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () =>
                  prov.loadEmployeePerformance(forceRefresh: true),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Rankings'),
            Tab(text: 'Coaching'),
          ],
        ),
      ),
      body: Consumer<AiHubProvider>(
        builder: (ctx, prov, child) {
          if (prov.employeeState == AiHubLoadState.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = prov.employeeData;
          if (data == null || data.employees.isEmpty) {
            return _buildEmpty('No employee data available');
          }
          return TabBarView(
            controller: _tab,
            children: [
              _buildRankingsTab(data),
              _buildCoachingTab(data),
            ],
          );
        },
      ),
    );
  }

  // ─── Rankings Tab ─────────────────────────────────────────────────────────────

  Widget _buildRankingsTab(AiEmployeeData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary
        Row(children: [
          _chip('${data.total}', 'Total Reps', _red),
          const SizedBox(width: 10),
          _chip('${data.topPerformers}', 'Top Performers',
              const Color(0xFF1B5E20)),
          const SizedBox(width: 10),
          _chip('${data.avgScore.toStringAsFixed(0)}%', 'Avg Score',
              Colors.blueAccent),
          const SizedBox(width: 10),
          _chip('${data.targetMet}', 'Target Met', const Color(0xFF6A1B9A)),
        ]),
        const SizedBox(height: 14),
        if (data.observation != null)
          _aiCard('AI Observation', data.observation!.text,
              Icons.insights, _red),
        const SizedBox(height: 16),
        _sectionHead('Performance Rankings',
            'Sorted by performance score — target achievement'),
        const SizedBox(height: 10),
        ...data.employees.asMap().entries.map((e) =>
            _buildEmployeeCard(e.value, rank: e.key + 1)),
        const SizedBox(height: 16),
        if (data.regions.isNotEmpty) _buildRegionCard(data),
      ]),
    );
  }

  Widget _chip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 5,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildEmployeeCard(AiEmployeePerformance e, {required int rank}) {
    final color = e.rankColor;
    final isTop = e.rankLabel == 'Top Performer';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isTop
            ? Border.all(color: Colors.green.withValues(alpha: 0.35))
            : e.coachingFlag
                ? Border.all(color: Colors.redAccent.withValues(alpha: 0.35))
                : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Rank badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: rank <= 3
                    ? Colors.amber.withValues(alpha: 0.15)
                    : Colors.grey.shade100,
                shape: BoxShape.circle),
            child: Center(
              child: Text('#$rank',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3 ? Colors.amber.shade700 : Colors.grey)),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(e.initials,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.employeeName,
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text(e.region,
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(e.targetAchievement,
                style: TextStyle(
                    fontSize: 13,
                    color: e.targetMet
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    fontWeight: FontWeight.bold)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(e.rankLabel,
                  style: TextStyle(
                      fontSize: 9,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('Performance',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const Spacer(),
          Text('${e.performanceScore}%',
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: e.performanceScore / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.location_pin, size: 11, color: Colors.grey.shade500),
          const SizedBox(width: 2),
          Text(e.region,
              style:
                  TextStyle(fontSize: 9, color: Colors.grey.shade500)),
          const SizedBox(width: 10),
          Icon(Icons.people_outline, size: 11, color: Colors.grey.shade500),
          const SizedBox(width: 2),
          Text('${e.totalVisits} visits',
              style:
                  TextStyle(fontSize: 9, color: Colors.grey.shade500)),
          const SizedBox(width: 10),
          Icon(Icons.play_circle_outline, size: 11, color: Colors.grey.shade500),
          const SizedBox(width: 2),
          Text('${e.totalSessions} sessions',
              style:
                  TextStyle(fontSize: 9, color: Colors.grey.shade500)),
        ]),
      ]),
    );
  }

  Widget _buildRegionCard(AiEmployeeData data) {
    final maxScore = data.regions.fold(
        0.0, (a, b) => (b['avg_score'] as num? ?? 0) > a
            ? (b['avg_score'] as num).toDouble()
            : a);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.map_outlined, color: _red, size: 18),
          const SizedBox(width: 8),
          Text('Region Performance',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ]),
        const SizedBox(height: 14),
        ...data.regions.map((r) {
          final avg = (r['avg_score'] as num? ?? 0).toDouble();
          final frac = maxScore > 0 ? avg / maxScore : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(
                width: 70,
                child: Text(r['region']?.toString() ?? '',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade700)),
              ),
              Expanded(
                child: Stack(children: [
                  Container(
                      height: 8,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4))),
                  FractionallySizedBox(
                    widthFactor: frac,
                    child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4))),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Text('${avg.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _red)),
              const SizedBox(width: 6),
              Text('${r['count'] ?? 0} reps',
                  style: TextStyle(
                      fontSize: 9, color: Colors.grey.shade500)),
            ]),
          );
        }),
      ]),
    );
  }

  // ─── Coaching Tab ─────────────────────────────────────────────────────────────

  Widget _buildCoachingTab(AiEmployeeData data) {
    final needsCoaching =
        data.employees.where((e) => e.coachingFlag).toList();
    final onTrack = data.employees
        .where((e) => !e.coachingFlag && !e.targetMet)
        .toList();
    final topPerformers =
        data.employees.where((e) => e.rankLabel == 'Top Performer').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Coaching alert
        if (needsCoaching.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.school, color: Colors.redAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      '${needsCoaching.length} reps flagged for coaching',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.redAccent)),
                  Text(
                      'Below target for 3+ months. Immediate intervention recommended.',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          height: 1.4)),
                ]),
              ),
            ]),
          ),
        // Needs coaching
        if (needsCoaching.isNotEmpty) ...[
          _sectionHead('Needs Coaching', 'Below performance threshold'),
          const SizedBox(height: 8),
          ...needsCoaching.map((e) => _buildCoachingCard(e, urgent: true)),
          const SizedBox(height: 16),
        ],
        // On track
        if (onTrack.isNotEmpty) ...[
          _sectionHead('On Track', 'Meeting activity targets — watch closely'),
          const SizedBox(height: 8),
          ...onTrack.map((e) => _buildCoachingCard(e)),
          const SizedBox(height: 16),
        ],
        // Top performers
        if (topPerformers.isNotEmpty) ...[
          _sectionHead('Top Performers', 'Exceeding targets — share best practices'),
          const SizedBox(height: 8),
          ...topPerformers
              .map((e) => _buildCoachingCard(e, highlight: true)),
        ],
      ]),
    );
  }

  Widget _buildCoachingCard(AiEmployeePerformance e,
      {bool urgent = false, bool highlight = false}) {
    final borderColor = urgent
        ? Colors.redAccent
        : highlight
            ? Colors.green
            : Colors.grey.shade300;
    final badgeColor = urgent
        ? Colors.redAccent
        : highlight
            ? Colors.green
            : Colors.orange;
    final badge = urgent
        ? 'Needs Coaching'
        : highlight
            ? 'Top Performer'
            : 'On Track';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: badgeColor.withValues(alpha: 0.12),
          child: Text(e.initials,
              style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.employeeName,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${e.region} • ${e.totalVisits} visits',
                style:
                    TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(e.targetAchievement,
              style: TextStyle(
                  fontSize: 13,
                  color: e.targetMet
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                  fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text(badge,
                style: TextStyle(
                    fontSize: 9,
                    color: badgeColor,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      ]),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  Widget _aiCard(String title, String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [color, color.withValues(alpha: 0.85)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(text,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 11, height: 1.4)),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionHead(String title, String sub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
      Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]);
  }

  Widget _buildEmpty(String msg) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: Colors.grey.shade600)),
        ]),
      );
}
