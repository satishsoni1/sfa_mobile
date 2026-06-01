import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AiEmployeeReportsScreen extends StatefulWidget {
  const AiEmployeeReportsScreen({super.key});

  @override
  State<AiEmployeeReportsScreen> createState() =>
      _AiEmployeeReportsScreenState();
}

class _AiEmployeeReportsScreenState extends State<AiEmployeeReportsScreen>
    with SingleTickerProviderStateMixin {
  static const _orange = Color(0xFFBF360C);
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ─── Static Demo Data ────────────────────────────────────────────────────────

  static const _employees = [
    _EmpRow('Suresh Nair', 'Bangalore', 158, 150, 98, 105, 1),
    _EmpRow('Rahul Sharma', 'Mumbai', 145, 150, 88, 96, 2),
    _EmpRow('Anita Desai', 'Pune', 132, 150, 82, 88, 3),
    _EmpRow('Kavita Rao', 'Delhi', 128, 150, 79, 85, 4),
    _EmpRow('Deepak Menon', 'Chennai', 119, 150, 74, 79, 5),
    _EmpRow('Meera Joshi', 'Hyderabad', 98, 150, 58, 65, 6),
  ];

  static const _kpis = [
    _KpiRow('Doctor Calls', 'Avg 128/150', 85, 0xFF1565C0),
    _KpiRow('CLM Sessions', 'Avg 112/130', 86, 0xFF2E7D32),
    _KpiRow('Reports Filed', 'Avg 98/100', 98, 0xFF6A1B9A),
    _KpiRow('Target Achievement', 'Avg 86%', 86, 0xFFBF360C),
    _KpiRow('New Doctors Added', 'Avg 4/5', 80, 0xFF00695C),
    _KpiRow('Expense Compliance', 'Avg 94%', 94, 0xFF795548),
  ];

  static const _coaching = [
    _CoachRow(
      'Meera Joshi',
      'Below Target',
      'Calls at 65% of target. CLM usage very low. '
          'Recommend joint working session with manager to identify blockers.',
      ['Joint Working', 'CLM Training', 'Territory Review'],
      0xFFB71C1C,
    ),
    _CoachRow(
      'Deepak Menon',
      'Needs Support',
      'Good call frequency but low conversion rate. Doctor engagement score '
          'below team average. Needs product knowledge refresher.',
      ['Product Training', 'Objection Handling', 'CLM Content Review'],
      0xFFE65100,
    ),
    _CoachRow(
      'Anita Desai',
      'On Track',
      'Consistent performance. Slight dip in new doctor addition. '
          'Explore adjacent territory for expansion opportunities.',
      ['Territory Expansion', 'New Doctor Targeting', 'Digital Detailing'],
      0xFF1565C0,
    ),
    _CoachRow(
      'Suresh Nair',
      'Star Performer',
      'Exceeded all KPIs. Strong CLM adoption and doctor engagement. '
          'Identify as team champion for best-practice sharing.',
      ['Best Practice Sharing', 'Mentor Allocation', 'Recognition'],
      0xFF1B5E20,
    ),
  ];

  // ─── Build ───────────────────────────────────────────────────────────────────

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
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Performance'),
            Tab(text: 'Peer Rank'),
            Tab(text: 'Coaching'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildPerformanceTab(),
          _buildPeerRankTab(),
          _buildCoachingTab(),
        ],
      ),
    );
  }

  // ─── Tab 1: Performance ──────────────────────────────────────────────────────

  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPerfSummary(),
        const SizedBox(height: 14),
        _aiCard(
          'AI Performance Summary',
          'Team average target achievement is 86%. Suresh Nair leads at 105%. '
              'Meera Joshi needs immediate attention at 65%.',
          Icons.insights,
          _orange,
        ),
        const SizedBox(height: 16),
        _sectionHead('KPI Achievement – Apr 2025',
            'Team-level metrics vs monthly target'),
        const SizedBox(height: 10),
        ..._kpis.map(_buildKpiCard),
        const SizedBox(height: 16),
        _buildProductivityChart(),
      ]),
    );
  }

  Widget _buildPerfSummary() {
    return Row(children: [
      Expanded(
          child: _miniStat('Total Reps', '24', Icons.person, _orange)),
      const SizedBox(width: 10),
      Expanded(
          child: _miniStat(
              'Avg Achieve', '86%', Icons.bar_chart, const Color(0xFF1B5E20))),
      const SizedBox(width: 10),
      Expanded(
          child: _miniStat(
              'Below Target', '4 reps', Icons.warning_amber, const Color(0xFFB71C1C))),
    ]);
  }

  Widget _miniStat(String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecor(),
      child: Column(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(val,
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        Text(label,
            style: TextStyle(
                fontSize: 9, color: Colors.grey.shade600),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildKpiCard(_KpiRow k) {
    final color = Color(k.colorValue);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecor(),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Center(
              child: Text('${k.pct}%',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k.label,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            Text(k.value,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: k.pct / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildProductivityChart() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final calls = [22, 28, 24, 30, 26, 14];
    const maxCalls = 35.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Daily Productivity – This Week',
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600)),
        Text('Team total doctor calls per day',
            style:
                TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(6, (i) {
              final h = (calls[i] / maxCalls) * 80;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child:
                      Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${calls[i]}',
                        style: TextStyle(
                            fontSize: 8, color: Colors.grey.shade600)),
                    const SizedBox(height: 3),
                    Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: i == 3
                            ? _orange
                            : _orange.withValues(alpha: 0.4 + i * 0.1),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(days[i],
                        style: TextStyle(
                            fontSize: 9, color: Colors.grey.shade600)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }

  // ─── Tab 2: Peer Rank ────────────────────────────────────────────────────────

  Widget _buildPeerRankTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiCard(
          'Team Benchmark',
          'Top 25% of reps contribute 48% of total output. '
              'Bridging Meera Joshi to median could add 12% team-wide uplift.',
          Icons.leaderboard,
          _orange,
        ),
        const SizedBox(height: 16),
        _sectionHead(
            'Peer Performance Ranking', 'Apr 2025 – all KPIs combined'),
        const SizedBox(height: 10),
        ..._employees.map(_buildRankCard),
        const SizedBox(height: 16),
        _buildBenchmarkCard(),
      ]),
    );
  }

  Widget _buildRankCard(_EmpRow e) {
    final pct = e.achievement;
    final color = pct >= 100
        ? const Color(0xFF1B5E20)
        : pct >= 80
            ? const Color(0xFF1565C0)
            : pct >= 70
                ? const Color(0xFFE65100)
                : const Color(0xFFB71C1C);

    final rankColor = e.rank == 1
        ? Colors.amber.shade700
        : e.rank == 2
            ? Colors.grey.shade500
            : e.rank == 3
                ? const Color(0xFF8D6E63)
                : Colors.grey.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: e.rank == 1
            ? Border.all(color: Colors.amber.shade300, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration:
              BoxDecoration(color: rankColor.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Center(
              child: Text('#${e.rank}',
                  style: TextStyle(
                      fontSize: 10,
                      color: rankColor,
                      fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${e.territory} · ${e.calls}/${e.target} calls',
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (pct / 110).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$pct%',
              style: TextStyle(
                  fontSize: 15, color: color, fontWeight: FontWeight.bold)),
          Text('Score: ${e.score}',
              style: TextStyle(
                  fontSize: 9, color: Colors.grey.shade500)),
        ]),
      ]),
    );
  }

  Widget _buildBenchmarkCard() {
    final benchmarks = [
      ('Top 25%', '101%', const Color(0xFF1B5E20)),
      ('Team Avg', '86%', const Color(0xFF1565C0)),
      ('Bottom 25%', '69%', const Color(0xFFB71C1C)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Team Benchmarks',
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: benchmarks
              .map((b) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                            color: b.$3.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: b.$3.withValues(alpha: 0.3))),
                        child: Column(children: [
                          Text(b.$2,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: b.$3,
                                  fontWeight: FontWeight.bold)),
                          Text(b.$1,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600),
                              textAlign: TextAlign.center),
                        ]),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ]),
    );
  }

  // ─── Tab 3: Coaching ─────────────────────────────────────────────────────────

  Widget _buildCoachingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiCard(
          'AI Coaching Engine',
          'Personalised coaching recommendations generated from performance '
              'data, CLM usage, engagement scores, and call report analysis.',
          Icons.school_outlined,
          _orange,
        ),
        const SizedBox(height: 16),
        _sectionHead('Coaching Insights',
            'AI-generated action plans for each representative'),
        const SizedBox(height: 10),
        ..._coaching.map(_buildCoachingCard),
        const SizedBox(height: 16),
        _buildTeamTrainingBlock(),
      ]),
    );
  }

  Widget _buildCoachingCard(_CoachRow c) {
    final color = Color(c.statusColor);
    final statusIcon = c.status == 'Star Performer'
        ? Icons.emoji_events
        : c.status == 'On Track'
            ? Icons.check_circle_outline
            : c.status == 'Needs Support'
                ? Icons.support_agent
                : Icons.warning_amber_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(statusIcon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(c.status,
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.smart_toy_outlined,
                  size: 12, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              Text('AI Plan',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(8)),
          child: Text(c.insight,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  height: 1.5)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: c.actions
              .map((a) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check, size: 10, color: color),
                      const SizedBox(width: 4),
                      Text(a,
                          style: TextStyle(
                              fontSize: 10, color: color)),
                    ]),
                  ))
              .toList(),
        ),
      ]),
    );
  }

  Widget _buildTeamTrainingBlock() {
    final sessions = [
      ('CLM Content Mastery', '6 reps enrolled', Icons.slideshow,
          const Color(0xFF1565C0)),
      ('Objection Handling Workshop', '4 reps enrolled',
          Icons.record_voice_over, const Color(0xFF6A1B9A)),
      ('Digital Detailing Basics', '3 reps enrolled',
          Icons.tablet_android, const Color(0xFF2E7D32)),
      ('Competitor Analysis Update', 'All 24 reps', Icons.compare_arrows,
          _orange),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _orange.withValues(alpha: 0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.calendar_month, color: _orange, size: 18),
          const SizedBox(width: 8),
          Text('Upcoming Training Sessions',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ]),
        const SizedBox(height: 12),
        ...sessions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: s.$4.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(s.$3, color: s.$4, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.$1,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        Text(s.$2,
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600)),
                      ]),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 16),
              ]),
            )),
      ]),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _aiCard(
      String title, String text, IconData icon, Color color) {
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
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(text,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.4)),
              ]),
        ),
      ]),
    );
  }

  Widget _sectionHead(String title, String sub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87)),
      Text(sub,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]);
  }

  BoxDecoration _cardDecor() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      );
}

// ─── Data Classes ─────────────────────────────────────────────────────────────

class _EmpRow {
  final String name, territory;
  final int calls, target, score, achievement, rank;
  const _EmpRow(this.name, this.territory, this.calls, this.target, this.score,
      this.achievement, this.rank);
}

class _KpiRow {
  final String label, value;
  final int pct, colorValue;
  const _KpiRow(this.label, this.value, this.pct, this.colorValue);
}

class _CoachRow {
  final String name, status, insight;
  final List<String> actions;
  final int statusColor;
  const _CoachRow(
      this.name, this.status, this.insight, this.actions, this.statusColor);
}
