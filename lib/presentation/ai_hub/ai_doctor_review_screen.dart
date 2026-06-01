import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AiDoctorReviewScreen extends StatefulWidget {
  const AiDoctorReviewScreen({super.key});

  @override
  State<AiDoctorReviewScreen> createState() => _AiDoctorReviewScreenState();
}

class _AiDoctorReviewScreenState extends State<AiDoctorReviewScreen>
    with SingleTickerProviderStateMixin {
  static const _purple = Color(0xFF6A1B9A);
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

  static const _doctors = [
    _DrRow('Dr. Amit Shah', 'Cardiologist', 'Mumbai',
        92, 'Improving', 0xFF1B5E20, '3 days ago', 8),
    _DrRow('Dr. Sunita Patel', 'Diabetologist', 'Delhi',
        88, 'Stable', 0xFF1B5E20, '5 days ago', 6),
    _DrRow('Dr. Priya Mehta', 'Neurologist', 'Pune',
        78, 'Stable', 0xFF1B5E20, '8 days ago', 5),
    _DrRow('Dr. Neha Gupta', 'Gynecologist', 'Bangalore',
        71, 'Declining', 0xFFE65100, '14 days ago', 3),
    _DrRow('Dr. Rajesh Kumar', 'Oncologist', 'Mumbai',
        65, 'Declining', 0xFFE65100, '18 days ago', 4),
    _DrRow('Dr. Vikram Singh', 'Pulmonologist', 'Hyderabad',
        45, 'At Risk', 0xFFB71C1C, '45 days ago', 2),
    _DrRow('Dr. Anand Joshi', 'Cardiologist', 'Pune',
        38, 'At Risk', 0xFFB71C1C, '52 days ago', 1),
  ];

  static const _objections = [
    _ObjRow('Price / Cost Concern', 42, 0xFFB71C1C),
    _ObjRow('Already Prescribing Generic', 28, 0xFFE65100),
    _ObjRow('Need More Clinical Data', 21, 0xFF1565C0),
    _ObjRow('Patient Compliance Issues', 15, 0xFF6A1B9A),
    _ObjRow('Competitor Loyalty', 12, 0xFF00695C),
    _ObjRow('Dosing Inconvenience', 8, 0xFF795548),
  ];

  static const _affinityData = [
    _AffinityRow('Dr. Amit Shah', 'CardioMax', 95, 'Cardiologist'),
    _AffinityRow('Dr. Sunita Patel', 'DiabetaControl', 91, 'Diabetologist'),
    _AffinityRow('Dr. Priya Mehta', 'NeuroCare Plus', 76, 'Neurologist'),
    _AffinityRow('Dr. Rajesh Kumar', 'OncoClear', 68, 'Oncologist'),
    _AffinityRow('Dr. Neha Gupta', 'DiabetaControl', 62, 'Gynecologist'),
    _AffinityRow('Dr. Vikram Singh', 'PulmoRelief', 44, 'Pulmonologist'),
  ];

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.person_search, size: 18),
          const SizedBox(width: 8),
          Text('Doctor Review',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber, size: 12, color: Colors.red),
              const SizedBox(width: 4),
              Text('12 Alerts',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade200,
                      fontWeight: FontWeight.bold)),
            ]),
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
            Tab(text: 'Engagement'),
            Tab(text: 'Objections'),
            Tab(text: 'Affinity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildEngagementTab(),
          _buildObjectionsTab(),
          _buildAffinityTab(),
        ],
      ),
    );
  }

  // ─── Tab 1: Engagement ───────────────────────────────────────────────────────

  Widget _buildEngagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildEngagementSummary(),
        const SizedBox(height: 14),
        _aiCard(
          'AI Alert',
          '2 doctors (Dr. Vikram Singh, Dr. Anand Joshi) have not been visited '
              'in 45+ days. Immediate re-engagement recommended.',
          Icons.warning_amber_rounded,
          const Color(0xFFBF360C),
        ),
        const SizedBox(height: 16),
        _sectionHead(
            'Doctor Engagement Overview', 'Trend, last visit & CLM score'),
        const SizedBox(height: 10),
        ..._doctors.map(_buildDoctorEngCard),
        const SizedBox(height: 16),
        _buildTerritoryComparison(),
      ]),
    );
  }

  Widget _buildEngagementSummary() {
    return Row(children: [
      Expanded(
          child: _miniStat('Total Doctors', '156', Icons.people, _purple)),
      const SizedBox(width: 10),
      Expanded(
          child: _miniStat(
              'Improving', '42', Icons.trending_up, const Color(0xFF1B5E20))),
      const SizedBox(width: 10),
      Expanded(
          child: _miniStat(
              'At Risk', '12', Icons.warning_amber, const Color(0xFFBF360C))),
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
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        Text(label,
            style:
                TextStyle(fontSize: 9, color: Colors.grey.shade600),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildDoctorEngCard(_DrRow d) {
    final color = Color(d.trendColor);
    final trendIcon = d.trend == 'Improving'
        ? Icons.trending_up
        : d.trend == 'Declining' || d.trend == 'At Risk'
            ? Icons.trending_down
            : Icons.trending_flat;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: d.trend == 'At Risk'
            ? Border.all(color: Colors.red.shade200, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: _purple.withValues(alpha: 0.1),
          child: Text(
            d.name.split(' ').skip(1).map((s) => s[0]).take(2).join(),
            style: TextStyle(
                color: _purple,
                fontWeight: FontWeight.bold,
                fontSize: 11),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(d.name,
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600))),
              Icon(trendIcon, size: 14, color: color),
            ]),
            Text('${d.speciality} · ${d.territory}',
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: d.score / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${d.score}%',
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text(d.trend,
                style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(d.lastVisit,
              style: TextStyle(
                  fontSize: 9, color: Colors.grey.shade500)),
          Text('${d.visits} visits',
              style: TextStyle(
                  fontSize: 9, color: Colors.grey.shade400)),
        ]),
      ]),
    );
  }

  Widget _buildTerritoryComparison() {
    final territories = [
      ('Delhi', 95, const Color(0xFF1B5E20)),
      ('Mumbai', 88, const Color(0xFF1B5E20)),
      ('Pune', 76, const Color(0xFF1B5E20)),
      ('Bangalore', 68, const Color(0xFFE65100)),
      ('Hyderabad', 52, const Color(0xFFB71C1C)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Territory Comparison',
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600)),
        Text('Average doctor engagement index by territory',
            style:
                TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 14),
        ...territories.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                    width: 80,
                    child: Text(t.$1,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500))),
                Expanded(
                  child: Stack(children: [
                    Container(
                        height: 20,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(
                      widthFactor: (t.$2 / 100).clamp(0.0, 1.0),
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                            color: t.$3,
                            borderRadius: BorderRadius.circular(4)),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 6),
                        child: Text('${t.$2}%',
                            style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              ]),
            )),
      ]),
    );
  }

  // ─── Tab 2: Objections ───────────────────────────────────────────────────────

  Widget _buildObjectionsTab() {
    final total = _objections.fold<int>(0, (sum, o) => sum + o.count);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiCard(
          'AI Pattern Detected',
          'Price concern is the #1 objection across all territories (42 instances). '
              'Prepare ROI comparison sheets for next round of visits.',
          Icons.psychology,
          _purple,
        ),
        const SizedBox(height: 16),
        _sectionHead('Objection Analysis',
            '$total objections recorded across ${_doctors.length} doctors'),
        const SizedBox(height: 10),
        ..._objections.map((o) => _buildObjBar(o, total)),
        const SizedBox(height: 16),
        _buildObjectionByProduct(),
        const SizedBox(height: 16),
        _buildAiHandlingGuide(),
      ]),
    );
  }

  Widget _buildObjBar(_ObjRow o, int total) {
    final pct = (o.count / total * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(o.label,
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600))),
          Text('$pct% (${ o.count})',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(o.color),
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: o.count / total,
            backgroundColor: Colors.grey.shade200,
            valueColor:
                AlwaysStoppedAnimation<Color>(Color(o.color)),
            minHeight: 8,
          ),
        ),
      ]),
    );
  }

  Widget _buildObjectionByProduct() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Objections by Product',
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _objProdRow('CardioMax', 'Price (18)', 'Clinical Data (8)'),
        _objProdRow('DiabetaControl', 'Compliance (12)', 'Generic (9)'),
        _objProdRow('NeuroCare Plus', 'Price (11)', 'Competitor (7)'),
        _objProdRow('PulmoRelief', 'Dosing (8)', 'Generic (5)'),
        _objProdRow('OncoClear', 'Clinical Data (6)', 'Protocol (4)'),
      ]),
    );
  }

  Widget _objProdRow(String product, String obj1, String obj2) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(
            width: 100,
            child: Text(product,
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w600))),
        Expanded(
          child: Wrap(spacing: 6, children: [
            _objChip(obj1, Colors.red.shade100, Colors.red.shade700),
            _objChip(obj2, Colors.orange.shade100, Colors.orange.shade700),
          ]),
        ),
      ]),
    );
  }

  Widget _objChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 10, color: fg)),
    );
  }

  Widget _buildAiHandlingGuide() {
    final tips = [
      ('Price Concern', 'Present cost-per-outcome data. Compare 90-day treatment cost vs hospitalisation.'),
      ('Generic Competition', 'Use bioavailability and consistency data. Highlight adverse event rates.'),
      ('Clinical Data Request', 'Always carry latest trial reprints. Offer to arrange KOL webinar.'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _purple.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lightbulb_outline, color: _purple, size: 18),
          const SizedBox(width: 8),
          Text('AI Objection Handling Guide',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _purple)),
        ]),
        const SizedBox(height: 12),
        ...tips.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.$1,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _purple)),
                    const SizedBox(height: 3),
                    Text(t.$2,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            height: 1.4)),
                  ]),
            )),
      ]),
    );
  }

  // ─── Tab 3: Affinity ─────────────────────────────────────────────────────────

  Widget _buildAffinityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiCard(
          'AI Product-Doctor Matching',
          'Affinity score is calculated from CLM slide engagement, '
              'reaction data, and prescription history.',
          Icons.hub_outlined,
          _purple,
        ),
        const SizedBox(height: 16),
        _sectionHead('Product Affinity Map',
            'Which doctors respond best to which products'),
        const SizedBox(height: 10),
        ..._affinityData.map(_buildAffinityCard),
        const SizedBox(height: 16),
        _buildAffinityMatrix(),
        const SizedBox(height: 16),
        _buildNewDoctorOpportunities(),
      ]),
    );
  }

  Widget _buildAffinityCard(_AffinityRow r) {
    final color = r.score >= 80
        ? const Color(0xFF1B5E20)
        : r.score >= 60
            ? const Color(0xFFE65100)
            : const Color(0xFFB71C1C);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecor(),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: _purple.withValues(alpha: 0.1),
          child: Text(
            r.doctorName.split(' ').skip(1).map((s) => s[0]).take(2).join(),
            style: TextStyle(
                color: _purple, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.doctorName,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${r.speciality} → ${r.product}',
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: r.score / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Text('${r.score}%',
            style: TextStyle(
                fontSize: 14, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildAffinityMatrix() {
    final products = ['CardioMax', 'DiabetaCtrl', 'NeuroCare', 'OncoClear'];
    final segments = ['Cardiology', 'Diabetology', 'Neurology', 'Oncology'];
    final scores = [
      [95, 12, 8, 5],
      [10, 91, 15, 18],
      [7, 14, 76, 9],
      [5, 18, 10, 68],
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Affinity Matrix',
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600)),
        Text('Speciality × Product engagement %',
            style:
                TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 12),
        Table(
          border: TableBorder.all(color: Colors.grey.shade200),
          columnWidths: const {0: FlexColumnWidth(1.4)},
          children: [
            TableRow(
              decoration: BoxDecoration(color: _purple.withValues(alpha: 0.07)),
              children: [
                const TableCell(child: SizedBox()),
                ...products.map((p) => TableCell(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 5),
                        child: Text(p,
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700),
                            textAlign: TextAlign.center),
                      ),
                    )),
              ],
            ),
            ...List.generate(4, (row) => TableRow(
                  children: [
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        child: Text(segments[row],
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700)),
                      ),
                    ),
                    ...List.generate(4, (col) {
                      final v = scores[row][col];
                      final c = v >= 70
                          ? const Color(0xFF1B5E20)
                          : v >= 20
                              ? const Color(0xFFE65100)
                              : Colors.grey.shade400;
                      return TableCell(
                        child: Container(
                          color: v >= 70
                              ? c.withValues(alpha: 0.1)
                              : null,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text('$v',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: c,
                                  fontWeight: v >= 70
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                              textAlign: TextAlign.center),
                        ),
                      );
                    }),
                  ],
                )),
          ],
        ),
      ]),
    );
  }

  Widget _buildNewDoctorOpportunities() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _purple.withValues(alpha: 0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person_add_outlined, color: _purple, size: 18),
          const SizedBox(width: 8),
          Text('New Doctor Opportunities',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _purple)),
        ]),
        const SizedBox(height: 10),
        Text(
            'AI has identified 14 cardiologists in Delhi not yet covered. '
            '6 of them have published papers referencing CardioMax – '
            'high conversion potential. Recommend adding to tour plan.',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                height: 1.5)),
        const SizedBox(height: 10),
        Row(children: [
          _oppChip('Delhi – 6 targets', const Color(0xFF1565C0)),
          const SizedBox(width: 8),
          _oppChip('Pune – 5 targets', const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          _oppChip('Mumbai – 3 targets', _purple),
        ]),
      ]),
    );
  }

  Widget _oppChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
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

class _DrRow {
  final String name, speciality, territory, trend, lastVisit;
  final int score, trendColor, visits;
  const _DrRow(this.name, this.speciality, this.territory, this.score,
      this.trend, this.trendColor, this.lastVisit, this.visits);
}

class _ObjRow {
  final String label;
  final int count, color;
  const _ObjRow(this.label, this.count, this.color);
}

class _AffinityRow {
  final String doctorName, product, speciality;
  final int score;
  const _AffinityRow(
      this.doctorName, this.product, this.score, this.speciality);
}
