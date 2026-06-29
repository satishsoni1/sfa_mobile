import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/ai_hub_provider.dart';
import 'ai_sales_assistant_screen.dart';
import 'ai_product_performance_screen.dart';
import 'ai_doctor_review_screen.dart';
import 'ai_employee_reports_screen.dart';

class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key});

  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiHubProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.auto_awesome, size: 18),
          const SizedBox(width: 8),
          Text('AI Insights Hub',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<AiHubProvider>(
            builder: (context2, prov, child2) => Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: prov.hubState == AiHubLoadState.loaded
                        ? const Color(0xFF69F0AE)
                        : Colors.orange,
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                prov.hubState == AiHubLoadState.loaded ? 'Live' : 'Loading',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF69F0AE),
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: prov.refresh,
                tooltip: 'Refresh',
              ),
            ]),
          ),
        ],
      ),
      body: Consumer<AiHubProvider>(
        builder: (ctx, prov, child) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(prov)),
              SliverToBoxAdapter(child: _buildModulesGrid(context, prov)),
              if (prov.insights.isNotEmpty)
                SliverToBoxAdapter(child: _buildAiInsightBanner(prov)),
              SliverToBoxAdapter(child: _buildRecentInsights(context, prov)),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader(AiHubProvider prov) {
    return Container(
      decoration: const BoxDecoration(color: Colors.blueAccent),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Powered by AI & Machine Learning',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
              Text(
                prov.isHubLoading
                    ? 'Loading intelligence…'
                    : '4 Intelligence Modules',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        if (prov.isHubLoading)
          const LinearProgressIndicator(
            backgroundColor: Colors.white24,
            color: Colors.white,
          )
        else
          Row(children: [
            _headerChip(
                prov.metricValue('accuracy_score', fallback: '87%'),
                'Accuracy'),
            const SizedBox(width: 8),
            _headerChip(
                prov.metricValue('doctor_count', fallback: '156'),
                'Doctors'),
            const SizedBox(width: 8),
            _headerChip(
                prov.metricValue('insights_count', fallback: '23'),
                'Insights'),
            const SizedBox(width: 8),
            _headerChip(
                prov.metricValue('active_regions', fallback: '5'),
                'Regions'),
          ]),
      ]),
    );
  }

  Widget _headerChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Text(value,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10)),
      ]),
    );
  }

  // ─── Module Grid ──────────────────────────────────────────────────────────────

  Widget _buildModulesGrid(BuildContext context, AiHubProvider prov) {
    final modules = [
      _ModuleConfig(
        icon:    Icons.support_agent,
        title:   'Sales Assistant',
        subtitle:'Doctor insights, conversion prediction & meeting playbooks',
        color:   const Color(0xFF1565C0),
        metrics: [
          '${prov.metricValue('accuracy_score', fallback: '87%')} accuracy',
          '${prov.metricValue('playbooks_ready', fallback: '8')} playbooks',
          '${prov.metricValue('doctor_count', fallback: '156')} doctors',
        ],
        badge: 'New',
        screen: const AiSalesAssistantScreen(),
      ),
      _ModuleConfig(
        icon:    Icons.trending_up,
        title:   'Product Performance',
        subtitle:'Sales trends, region analytics & conversion tracking',
        color:   const Color(0xFF2E7D32),
        metrics: [
          '${prov.metricValue('total_products', fallback: '12')} products',
          '${prov.metricValue('product_growth', fallback: '+18')}% growth',
          '${prov.metricValue('active_regions', fallback: '5')} regions',
        ],
        badge: null,
        screen: const AiProductPerformanceScreen(),
      ),
      _ModuleConfig(
        icon:    Icons.person_search,
        title:   'Doctor Review',
        subtitle:'Engagement trends, objections & product affinity',
        color:   const Color(0xFF6A1B9A),
        metrics: [
          '${prov.metricValue('doctor_count', fallback: '156')} doctors',
          '${prov.metricValue('flagged_doctors', fallback: '12')} flagged',
          'Objection map',
        ],
        badge: prov.metric('flagged_doctors') != null
            ? '${prov.metricValue('flagged_doctors')} alerts'
            : null,
        screen: const AiDoctorReviewScreen(),
      ),
      _ModuleConfig(
        icon:    Icons.groups,
        title:   'Employee Reports',
        subtitle:'Performance analysis, peer comparison & coaching',
        color:   const Color(0xFFBF360C),
        metrics: [
          '${prov.metricValue('total_reps', fallback: '24')} reps',
          '${prov.metricValue('avg_performance', fallback: '96')}% avg',
          'Coaching ready',
        ],
        badge: null,
        screen: const AiEmployeeReportsScreen(),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(14),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
        children: modules.map((m) => _ModuleCard(module: m)).toList(),
      ),
    );
  }

  // ─── AI Insight Banner ────────────────────────────────────────────────────────

  Widget _buildAiInsightBanner(AiHubProvider prov) {
    // Use the highest-priority insight from any module
    final topInsight = prov.insights.isNotEmpty ? prov.insights.first : null;
    if (topInsight == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF0277BD), Color(0xFF01579B)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Top AI Insight Today',
                style:
                    GoogleFonts.poppins(color: Colors.white70, fontSize: 10)),
            Text(topInsight.text,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4)),
          ]),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
      ]),
    );
  }

  // ─── Recent Insights List ─────────────────────────────────────────────────────

  Widget _buildRecentInsights(BuildContext context, AiHubProvider prov) {
    if (prov.isHubLoading) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: List.generate(4, (_) => _shimmerRow())),
      );
    }

    final items = prov.insights;
    if (items.isEmpty) return const SizedBox.shrink();

    Widget screenForModule(String module) {
      switch (module) {
        case 'product':  return const AiProductPerformanceScreen();
        case 'doctor':   return const AiDoctorReviewScreen();
        case 'employee': return const AiEmployeeReportsScreen();
        default:         return const AiSalesAssistantScreen();
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Text('Recent AI Insights',
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
      ),
      ...items.map((insight) => GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => screenForModule(insight.module)),
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: insight.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(insight.icon, color: insight.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(insight.tag,
                            style: TextStyle(
                                fontSize: 9,
                                color: insight.color,
                                fontWeight: FontWeight.w700)),
                        Text(insight.text,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ]),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 18),
              ]),
            ),
          )),
    ]);
  }

  Widget _shimmerRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      height: 56,
      decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10)),
    );
  }
}

// ─── Module Config & Card ──────────────────────────────────────────────────────

class _ModuleConfig {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final List<String> metrics;
  final String? badge;
  final Widget screen;

  const _ModuleConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.metrics,
    required this.badge,
    required this.screen,
  });
}

class _ModuleCard extends StatelessWidget {
  final _ModuleConfig module;
  const _ModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => module.screen)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: module.color.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: module.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(module.icon, color: module.color, size: 22),
            ),
            if (module.badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(module.badge!,
                    style: TextStyle(
                        fontSize: 8,
                        color: module.color,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 12),
          Text(module.title,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          const SizedBox(height: 3),
          Text(module.subtitle,
              style:
                  TextStyle(fontSize: 10, color: Colors.grey.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const Spacer(),
          ...module.metrics.map((m) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                          color: module.color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(m,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade700)),
                ]),
              )),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('Explore',
                style: TextStyle(
                    fontSize: 11,
                    color: module.color,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 2),
            Icon(Icons.arrow_forward, size: 13, color: module.color),
          ]),
        ]),
      ),
    );
  }
}
