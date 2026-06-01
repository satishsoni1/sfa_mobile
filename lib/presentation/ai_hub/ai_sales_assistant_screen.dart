import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AiSalesAssistantScreen extends StatefulWidget {
  const AiSalesAssistantScreen({super.key});

  @override
  State<AiSalesAssistantScreen> createState() =>
      _AiSalesAssistantScreenState();
}

class _AiSalesAssistantScreenState extends State<AiSalesAssistantScreen>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF1565C0);
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

  static const _engagements = [
    _EngRow('Dr. Amit Shah', 'Cardiologist', 92, 'High', 0xFF1B5E20),
    _EngRow('Dr. Sunita Patel', 'Diabetologist', 88, 'High', 0xFF1B5E20),
    _EngRow('Dr. Priya Mehta', 'Neurologist', 78, 'Medium', 0xFFE65100),
    _EngRow('Dr. Neha Gupta', 'Gynecologist', 71, 'Medium', 0xFFE65100),
    _EngRow('Dr. Rajesh Kumar', 'Oncologist', 65, 'Medium', 0xFFE65100),
    _EngRow('Dr. Vikram Singh', 'Pulmonologist', 45, 'At Risk', 0xFFB71C1C),
  ];

  static const _conversions = [
    _ConvRow('Dr. Amit Shah', 'CardioMax 10mg', 94, 'High', 0xFF1B5E20),
    _ConvRow('Dr. Sunita Patel', 'DiabetaControl', 88, 'High', 0xFF1B5E20),
    _ConvRow('Dr. Priya Mehta', 'NeuroCare Plus', 67, 'Medium', 0xFFE65100),
    _ConvRow('Dr. Rajesh Kumar', 'OncoClear', 52, 'Medium', 0xFFE65100),
    _ConvRow('Dr. Vikram Singh', 'PulmoRelief', 28, 'Low', 0xFFB71C1C),
  ];

  static const _playbooks = [
    _PlaybookRow(
      'Dr. Amit Shah',
      'CardioMax 10mg',
      'Focus on recent trial data. Patient has 3 hypertensive cases. '
          'Address previous side-effect concern with new safety data.',
      ['Recent Trial Data', 'Safety Profile', 'Dose Optimization'],
    ),
    _PlaybookRow(
      'Dr. Sunita Patel',
      'DiabetaControl',
      'Doctor showed strong interest in HbA1c data last visit. '
          'Bring updated outcomes report. Offer patient tracking brochures.',
      ['HbA1c Outcomes', 'Patient Material', 'Competitor Comparison'],
    ),
    _PlaybookRow(
      'Dr. Priya Mehta',
      'NeuroCare Plus',
      'Previously objected on price. Lead with value proposition. '
          'Compare with generic alternatives using superior outcomes data.',
      ['Value Proposition', 'Generic vs Brand', 'Dosing Convenience'],
    ),
    _PlaybookRow(
      'Dr. Rajesh Kumar',
      'OncoClear',
      'First visit for this brand. Build rapport. Share Phase III trial '
          'summary. Request inclusion in hospital treatment protocol.',
      ['Phase III Data', 'Protocol Request', 'Relationship Building'],
    ),
  ];

  static const _recommendations = [
    _RecRow('CardioMax 10mg', 'Cardiologists • General Physicians', 92, '+18%'),
    _RecRow('DiabetaControl', 'Diabetologists • Endocrinologists', 87, '+22%'),
    _RecRow('NeuroCare Plus', 'Neurologists • Psychiatrists', 74, '+7%'),
    _RecRow('OncoClear', 'Oncologists', 81, '+31%'),
    _RecRow('PulmoRelief', 'Pulmonologists • ENT', 56, '-5%'),
  ];

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.support_agent, size: 18),
          const SizedBox(width: 8),
          Text('Sales Assistant',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: _blue,
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
            Tab(text: 'Engagement'),
            Tab(text: 'Playbooks'),
            Tab(text: 'Recommend'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildEngagementTab(),
          _buildPlaybooksTab(),
          _buildRecommendationsTab(),
        ],
      ),
    );
  }

  // ─── Tab 1: Engagement & Conversion ─────────────────────────────────────────

  Widget _buildEngagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiCard(
          'AI Observation',
          '3 doctors show declining engagement this month. Prioritise visits '
              'to Dr. Vikram Singh and Dr. Rajesh Kumar before Q2 close.',
          Icons.insights,
          _blue,
        ),
        const SizedBox(height: 16),
        _sectionHead('Doctor Engagement Score',
            'Based on CLM visits, content views & reactions'),
        const SizedBox(height: 10),
        ..._engagements.map(_buildEngCard),
        const SizedBox(height: 16),
        _sectionHead(
            'Conversion Prediction', 'AI likelihood score – next 30 days'),
        const SizedBox(height: 10),
        ..._conversions.map(_buildConvCard),
      ]),
    );
  }

  Widget _buildEngCard(_EngRow d) {
    final color = Color(d.levelColor);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _blue.withValues(alpha: 0.1),
            child: Text(
              d.name.split(' ').skip(1).take(1).map((s) => s[0]).join() +
                  d.name.split(' ').skip(2).take(1).map((s) => s[0]).join(),
              style: TextStyle(
                  color: _blue, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name,
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text(d.speciality,
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text(d.level,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('Engagement',
              style:
                  TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const Spacer(),
          Text('${d.score}%',
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: d.score / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }

  Widget _buildConvCard(_ConvRow r) {
    final color = Color(r.levelColor);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)
        ],
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Center(
              child: Text('${r.score}%',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            Text('→ ${r.product}',
                style:
                    TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text(r.level,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ─── Tab 2: Playbooks ────────────────────────────────────────────────────────

  Widget _buildPlaybooksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiCard(
          'Today\'s Priority',
          '8 AI meeting playbooks ready for today\'s planned visits. '
              'Personalised strategies based on past CLM interactions.',
          Icons.auto_awesome,
          _blue,
        ),
        const SizedBox(height: 16),
        _sectionHead('AI Meeting Playbooks',
            'Personalised preparation for each doctor'),
        const SizedBox(height: 10),
        ..._playbooks.map(_buildPlaybookCard),
        const SizedBox(height: 16),
        _buildSmartScheduling(),
      ]),
    );
  }

  Widget _buildPlaybookCard(_PlaybookRow p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blue.withValues(alpha: 0.15)),
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
                color: _blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.article_outlined, color: _blue, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.doctorName,
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              Text(p.brand,
                  style: TextStyle(
                      fontSize: 10,
                      color: _blue.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Text('AI Ready',
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(8)),
          child: Text(p.strategy,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  height: 1.5)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: p.topics
              .map((t) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(t,
                        style: const TextStyle(
                            fontSize: 10, color: _blue)),
                  ))
              .toList(),
        ),
      ]),
    );
  }

  Widget _buildSmartScheduling() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _blue.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.schedule, color: _blue, size: 18),
          const SizedBox(width: 8),
          Text('Smart Scheduling Suggestions',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _blue)),
        ]),
        const SizedBox(height: 12),
        _schedRow('Mon AM', 'Dr. Amit Shah', 'Peak engagement window',
            Icons.star, Colors.amber),
        _schedRow('Tue PM', 'Dr. Sunita Patel', 'Post-lunch preferred',
            Icons.schedule, _blue),
        _schedRow('Wed AM', 'Dr. Priya Mehta', 'Before OPD hours',
            Icons.event, const Color(0xFF6A1B9A)),
        _schedRow('Thu AM', 'Dr. Rajesh Kumar', 'Morning slot confirmed',
            Icons.check_circle, Colors.green.shade700),
      ]),
    );
  }

  Widget _schedRow(String time, String doctor, String reason, IconData icon,
      Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(
            width: 56,
            child: Text(time,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600))),
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doctor,
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w600)),
            Text(reason,
                style: TextStyle(
                    fontSize: 9, color: Colors.grey.shade500)),
          ]),
        ),
      ]),
    );
  }

  // ─── Tab 3: Recommendations ──────────────────────────────────────────────────

  Widget _buildRecommendationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiCard(
          'Product Fit Analysis',
          'Based on doctor speciality, CLM engagement & visit history, '
              'AI maps the optimal product for each doctor segment.',
          Icons.recommend,
          _blue,
        ),
        const SizedBox(height: 16),
        _sectionHead(
            'Product Recommendations', 'Speciality match & conversion score'),
        const SizedBox(height: 10),
        ..._recommendations.map(_buildRecCard),
        const SizedBox(height: 16),
        _buildDoctorSegmentCard(),
      ]),
    );
  }

  Widget _buildRecCard(_RecRow r) {
    final isPos = r.growth.startsWith('+');
    final scoreColor = r.score >= 80
        ? const Color(0xFF1B5E20)
        : r.score >= 65
            ? const Color(0xFFE65100)
            : const Color(0xFFB71C1C);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.medication_outlined,
                size: 16, color: Color(0xFF4A148C)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.product,
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              Text(r.specialities,
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade600)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${r.score}% fit',
                style: TextStyle(
                    fontSize: 12,
                    color: scoreColor,
                    fontWeight: FontWeight.bold)),
            Text(r.growth,
                style: TextStyle(
                    fontSize: 11,
                    color: isPos
                        ? Colors.green.shade700
                        : Colors.red.shade600,
                    fontWeight: FontWeight.w600)),
          ]),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: r.score / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            minHeight: 5,
          ),
        ),
      ]),
    );
  }

  Widget _buildDoctorSegmentCard() {
    final segments = [
      ('Cardiologists', 28, 'CardioMax', const Color(0xFF1565C0)),
      ('Diabetologists', 34, 'DiabetaControl', const Color(0xFF2E7D32)),
      ('Oncologists', 12, 'OncoClear', const Color(0xFF6A1B9A)),
      ('Neurologists', 22, 'NeuroCare Plus', const Color(0xFFBF360C)),
      ('Pulmonologists', 18, 'PulmoRelief', const Color(0xFF00695C)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.groups, color: _blue, size: 18),
          const SizedBox(width: 8),
          Text('Doctor Segment Coverage',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ]),
        const SizedBox(height: 14),
        ...segments.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                    width: 110,
                    child: Text(s.$1,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700))),
                Expanded(
                  child: Stack(children: [
                    Container(
                        height: 8,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(
                      widthFactor: s.$2 / 40,
                      child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                              color: s.$4,
                              borderRadius: BorderRadius.circular(4))),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                Text('${s.$2}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: s.$4)),
                const SizedBox(width: 6),
                Text(s.$3,
                    style: TextStyle(
                        fontSize: 9, color: Colors.grey.shade500)),
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
          style:
              TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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

class _EngRow {
  final String name, speciality, level;
  final int score, levelColor;
  const _EngRow(
      this.name, this.speciality, this.score, this.level, this.levelColor);
}

class _ConvRow {
  final String name, product, level;
  final int score, levelColor;
  const _ConvRow(
      this.name, this.product, this.score, this.level, this.levelColor);
}

class _PlaybookRow {
  final String doctorName, brand, strategy;
  final List<String> topics;
  const _PlaybookRow(
      this.doctorName, this.brand, this.strategy, this.topics);
}

class _RecRow {
  final String product, specialities, growth;
  final int score;
  const _RecRow(this.product, this.specialities, this.score, this.growth);
}
