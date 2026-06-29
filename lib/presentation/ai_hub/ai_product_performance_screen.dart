import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/models/ai_hub_models.dart';
import '../../providers/ai_hub_provider.dart';

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
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiHubProvider>().loadProductPerformance();
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
          const Icon(Icons.trending_up, size: 18),
          const SizedBox(width: 8),
          Text('Product Performance',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<AiHubProvider>(
            builder: (ctx, prov, child) => IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () => prov.loadProductPerformance(forceRefresh: true),
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
            Tab(text: 'Overview'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: Consumer<AiHubProvider>(
        builder: (ctx, prov, child) {
          if (prov.productState == AiHubLoadState.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = prov.productData;
          if (data == null || data.products.isEmpty) {
            return _buildEmpty('No product data available');
          }
          return TabBarView(
            controller: _tab,
            children: [
              _buildOverviewTab(data),
              _buildTrendsTab(data),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(AiProductData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _summaryChip('${data.totalVisits}', 'Total Visits', _green),
          const SizedBox(width: 10),
          _summaryChip(
              '${data.totalConversions}', 'Conversions', Colors.blueAccent),
          const SizedBox(width: 10),
          _summaryChip(
              '${data.conversionRate.toStringAsFixed(1)}%',
              'Conv. Rate',
              const Color(0xFF6A1B9A)),
        ]),
        const SizedBox(height: 14),
        if (data.observation != null)
          _aiCard('AI Observation', data.observation!.text, Icons.insights, _green),
        const SizedBox(height: 16),
        _sectionHead(
            'Product Performance', 'Fit score, growth & conversion tracking'),
        const SizedBox(height: 10),
        ...data.products.map(_buildProductCard),
      ]),
    );
  }

  Widget _summaryChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildProductCard(AiProductPerformance p) {
    final color = p.scoreColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.medication_outlined,
                size: 16, color: Color(0xFF4A148C)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.productName,
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              Text(p.therapyArea,
                  style: TextStyle(
                      fontSize: 10,
                      color: _green.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${p.fitScore}% fit',
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.bold)),
            Text(p.growthValue,
                style: TextStyle(
                    fontSize: 12,
                    color: p.growthPositive
                        ? Colors.green.shade700
                        : Colors.red.shade600,
                    fontWeight: FontWeight.w700)),
          ]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text('Fit Score',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const Spacer(),
          Text('${p.fitScore}%',
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p.fitScore / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _statItem(Icons.people_outline, '${p.totalVisits}', 'Visits'),
          const SizedBox(width: 12),
          _statItem(
              Icons.check_circle_outline, '${p.totalConversions}', 'Converts'),
          const SizedBox(width: 12),
          _statItem(Icons.percent, '${p.conversionRate}%', 'Rate'),
          if (p.topRegion != null) ...[
            const SizedBox(width: 12),
            _statItem(Icons.location_on_outlined, p.topRegion!, 'Top Region'),
          ],
        ]),
        const SizedBox(height: 6),
        Text(p.targetSpecialities,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Row(children: [
      Icon(icon, size: 11, color: Colors.grey.shade500),
      const SizedBox(width: 3),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        Text(label,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
      ]),
    ]);
  }

  Widget _buildTrendsTab(AiProductData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiCard(
          'Trend Analysis',
          'Monthly visit trends across all products. '
              '${data.topProduct ?? 'Top product'} leads with highest growth.',
          Icons.bar_chart,
          _green,
        ),
        const SizedBox(height: 16),
        _sectionHead(
            'Monthly Visit Trends', 'Last 6 months visit activity per product'),
        const SizedBox(height: 10),
        ...data.products
            .where((p) => p.monthlyTrend.isNotEmpty)
            .map(_buildTrendCard),
      ]),
    );
  }

  Widget _buildTrendCard(AiProductPerformance p) {
    final trend = p.monthlyTrend;
    if (trend.isEmpty) return const SizedBox.shrink();

    final maxVal = trend
        .map((t) => (t['visits'] as num? ?? 0).toInt())
        .fold(0, (a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          Text(p.productName,
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(p.growthValue,
              style: TextStyle(
                  fontSize: 12,
                  color: p.growthPositive
                      ? Colors.green.shade700
                      : Colors.red.shade600,
                  fontWeight: FontWeight.w700)),
        ]),
        Text(p.therapyArea,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 14),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: trend.map((t) {
              final visits = (t['visits'] as num? ?? 0).toInt();
              final frac = maxVal > 0 ? visits / maxVal : 0.0;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('$visits',
                      style: TextStyle(fontSize: 8, color: Colors.grey.shade600)),
                  const SizedBox(height: 3),
                  Container(
                    width: 28,
                    height: 52 * frac,
                    decoration: BoxDecoration(
                        color: p.growthPositive
                            ? _green.withValues(alpha: 0.75)
                            : Colors.redAccent.withValues(alpha: 0.7),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4))),
                  ),
                  const SizedBox(height: 4),
                  Text(t['month']?.toString() ?? '',
                      style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                ],
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

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
