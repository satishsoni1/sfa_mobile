import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AiProductPerformanceScreen extends StatefulWidget {
  const AiProductPerformanceScreen({super.key});

  @override
  State<AiProductPerformanceScreen> createState() =>
      _AiProductPerformanceScreenState();
}

class _AiProductPerformanceScreenState
    extends State<AiProductPerformanceScreen>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF2E7D32);
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

  static const _products = [
    _ProdRow('CardioMax 10mg', 2450, 2080, '+18%', 'Cardiology', 0xFF1B5E20),
    _ProdRow('DiabetaControl', 3100, 2541, '+22%', 'Diabetology', 0xFF1B5E20),
    _ProdRow('OncoClear', 560, 427, '+31%', 'Oncology', 0xFF1B5E20),
    _ProdRow('NeuroCare Plus', 1820, 1701, '+7%', 'Neurology', 0xFFE65100),
    _ProdRow('PulmoRelief', 980, 1031, '-5%', 'Pulmonology', 0xFFB71C1C),
  ];

  static const _regions = [
    _RegionRow('Delhi', 45, 1, 95),
    _RegionRow('Mumbai', 38, 2, 92),
    _RegionRow('Pune', 27, 5, 88),
    _RegionRow('Bangalore', 34, 4, 79),
    _RegionRow('Hyderabad', 22, 8, 65),
  ];

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.trending_up, size: 18),
          const SizedBox(width: 8),
          Text('Product Performance',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: _green,
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
            Tab(text: 'Trends'),
            Tab(text: 'Regions'),
            Tab(text: 'Insights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildTrendsTab(),
          _buildRegionsTab(),
          _buildInsightsTab(),
        ],
      ),
    );
  }

  // ─── Tab 1: Trends ───────────────────────────────────────────────────────────

  Widget _buildTrendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSummaryRow(),
        const SizedBox(height: 14),
        _aiCard(
          'AI Analysis',
          'OncoClear shows highest growth (+31%) despite lowest volume. '
              'Increase oncology coverage to accelerate adoption.',
          Icons.insights,
          _green,
        ),
        const SizedBox(height: 16),
        _sectionHead('Sales Trends – Apr vs Mar 2025',
            'Month-over-month unit comparison'),
        const SizedBox(height: 10),
        ..._products.map(_buildProductBar),
        const SizedBox(height: 16),
        _buildMonthlyChart(),
      ]),
    );
  }

  Widget _buildSummaryRow() {
    return Row(children: [
      Expanded(
          child: _statCard('Total Units', '8,910', '+14%',
              Icons.inventory_2_outlined, _green)),
      const SizedBox(width: 10),
      Expanded(
          child: _statCard('Revenue', '₹24.5L', '+11%',
              Icons.currency_rupee, Colors.blue.shade700)),
      const SizedBox(width: 10),
      Expanded(
          child: _statCard(
              'Products', '5 Active', '2 review', Icons.medication, Colors.orange.shade700)),
    ]);
  }

  Widget _statCard(String label, String value, String sub, IconData icon,
      Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        Text(label,
            style:
                TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        Text(sub,
            style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildProductBar(_ProdRow p) {
    final isPos = p.growth.startsWith('+');
    final growthColor = isPos
        ? const Color(0xFF1B5E20)
        : const Color(0xFFB71C1C);
    const maxUnits = 3500.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name,
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text(p.segment,
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade500)),
            ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: growthColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              Icon(
                  isPos ? Icons.trending_up : Icons.trending_down,
                  size: 12,
                  color: growthColor),
              const SizedBox(width: 3),
              Text(p.growth,
                  style: TextStyle(
                      fontSize: 11,
                      color: growthColor,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        _barRow('Apr 2025', p.current, p.current / maxUnits,
            Color(p.colorValue)),
        const SizedBox(height: 5),
        _barRow('Mar 2025', p.prev, p.prev / maxUnits,
            Colors.grey.shade400),
      ]),
    );
  }

  Widget _barRow(String label, int count, double frac, Color color) {
    return Row(children: [
      SizedBox(
          width: 58,
          child: Text(label,
              style: TextStyle(
                  fontSize: 9, color: Colors.grey.shade500))),
      Expanded(
        child: Stack(children: [
          Container(
              height: 8,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4))),
          FractionallySizedBox(
            widthFactor: frac.clamp(0.0, 1.0),
            child: Container(
                height: 8,
                decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4))),
          ),
        ]),
      ),
      const SizedBox(width: 8),
      Text('${count}u',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black87)),
    ]);
  }

  Widget _buildMonthlyChart() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr'];
    final values = [6200, 7100, 7800, 8910];
    const maxVal = 9500.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Monthly Volume – All Products',
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Jan – Apr 2025',
            style:
                TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (i) {
              final h = (values[i] / maxVal) * 100;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${values[i]}',
                            style: TextStyle(
                                fontSize: 8,
                                color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: i == 3
                                ? _green
                                : _green.withValues(
                                    alpha: 0.35 + i * 0.2),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(months[i],
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600)),
                      ]),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }

  // ─── Tab 2: Regions ──────────────────────────────────────────────────────────

  Widget _buildRegionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiCard(
          'Regional Insight',
          'Delhi leads at 95% performance index. Hyderabad needs attention – '
              '8 doctors flagged for low engagement this quarter.',
          Icons.map_outlined,
          _green,
        ),
        const SizedBox(height: 16),
        _sectionHead('Region-wise Performance',
            'Doctors covered, issues flagged & performance index'),
        const SizedBox(height: 10),
        _buildRegionTable(),
        const SizedBox(height: 16),
        _buildConversionFunnel(),
      ]),
    );
  }

  Widget _buildRegionTable() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6)
          ]),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.08),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Expanded(
                flex: 3,
                child: Text('Region',
                    style: _hdrStyle())),
            Expanded(
                flex: 2,
                child: Text('Doctors',
                    style: _hdrStyle(), textAlign: TextAlign.center)),
            Expanded(
                flex: 2,
                child: Text('Issues',
                    style: _hdrStyle(), textAlign: TextAlign.center)),
            Expanded(
                flex: 3,
                child: Text('Performance',
                    style: _hdrStyle(), textAlign: TextAlign.center)),
          ]),
        ),
        ..._regions.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          final c = r.performance >= 85
              ? const Color(0xFF1B5E20)
              : r.performance >= 70
                  ? const Color(0xFFE65100)
                  : const Color(0xFFB71C1C);
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border:
                  Border(top: BorderSide(color: Colors.grey.shade100)),
              color: i.isOdd ? Colors.grey.shade50 : Colors.white,
            ),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Text(r.name,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  flex: 2,
                  child: Text('${r.doctors}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade700),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('${r.issues}',
                      style: TextStyle(
                          fontSize: 11,
                          color: r.issues > 4
                              ? Colors.red.shade600
                              : Colors.grey.shade600),
                      textAlign: TextAlign.center)),
              Expanded(
                flex: 3,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${r.performance}%',
                        style: TextStyle(
                            fontSize: 10,
                            color: c,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildConversionFunnel() {
    final stages = [
      ('Doctors Visited', 156),
      ('CLM Sessions Done', 132),
      ('Positive Reaction', 89),
      ('Follow-up Completed', 64),
      ('Rx Generated', 48),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Conversion Tracking',
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600)),
        Text('Apr 2025 – CLM to Rx funnel',
            style:
                TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 14),
        ...stages.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(
                    width: 140,
                    child: Text(s.$1,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600))),
                Expanded(
                  child: Stack(children: [
                    Container(
                        height: 18,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(
                      widthFactor: (s.$2 / 156).clamp(0.0, 1.0),
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: Color.lerp(_green,
                              const Color(0xFF81C784), 1 - s.$2 / 156),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 6),
                        child: Text('${s.$2}',
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

  // ─── Tab 3: Insights ─────────────────────────────────────────────────────────

  Widget _buildInsightsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiCard(
          'AI Prediction',
          'Q2 projection: +16% growth if 3 planned territory expansions execute '
              'on time. DiabetaControl poised to cross 4,000 units in May.',
          Icons.auto_awesome,
          _green,
        ),
        const SizedBox(height: 16),
        _sectionHead('Top Performers', 'Highest growth products this month'),
        const SizedBox(height: 10),
        _perfCard('OncoClear', '+31%', '560 units', 'Oncology',
            Icons.star, Colors.amber.shade700),
        _perfCard('DiabetaControl', '+22%', '3,100 units', 'Diabetology',
            Icons.trending_up, _green),
        _perfCard('CardioMax 10mg', '+18%', '2,450 units', 'Cardiology',
            Icons.trending_up, _green),
        const SizedBox(height: 16),
        _sectionHead('Needs Attention', 'Products requiring strategic review'),
        const SizedBox(height: 10),
        _alertCard(
          'PulmoRelief',
          '–5% growth in April 2025',
          'Visit frequency dropped in Pune & Bangalore. Only 3 pulmonologists '
              'showing consistent engagement. Territory review recommended.',
        ),
        const SizedBox(height: 16),
        _buildAiStrategyBlock(),
      ]),
    );
  }

  Widget _perfCard(String name, String growth, String units, String seg,
      IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecor(),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            Text('$units · $seg',
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade600)),
          ]),
        ),
        Text(growth,
            style: TextStyle(
                fontSize: 14, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _alertCard(String name, String issue, String detail) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded,
            color: Colors.red, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700)),
            Text(issue,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(detail,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                    height: 1.4)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAiStrategyBlock() {
    final recs = [
      'Increase PulmoRelief visits by 40% in Pune – 12 pulmonologists '
          'have not been visited in 30+ days.',
      'Bundle CardioMax + DiabetaControl for General Physician visits – '
          '78% of GPs in Mumbai prescribe both.',
      'OncoClear growth driven by 2 key oncologists – schedule quarterly '
          'reviews to protect relationship.',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _green.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lightbulb_outline, color: _green, size: 18),
          const SizedBox(width: 8),
          Text('AI Strategic Recommendations',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _green)),
        ]),
        const SizedBox(height: 12),
        ...recs.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                          color: _green, shape: BoxShape.circle),
                      child: Center(
                          child: Text('${e.key + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(e.value,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                height: 1.5))),
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

  TextStyle _hdrStyle() => TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Colors.grey.shade700);

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

class _ProdRow {
  final String name, growth, segment;
  final int current, prev, colorValue;
  const _ProdRow(this.name, this.current, this.prev, this.growth,
      this.segment, this.colorValue);
}

class _RegionRow {
  final String name;
  final int doctors, issues, performance;
  const _RegionRow(this.name, this.doctors, this.issues, this.performance);
}
