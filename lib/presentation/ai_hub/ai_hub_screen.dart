import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ai_sales_assistant_screen.dart';
import 'ai_product_performance_screen.dart';
import 'ai_doctor_review_screen.dart';
import 'ai_employee_reports_screen.dart';

class AiHubScreen extends StatelessWidget {
  const AiHubScreen({super.key});

  static const _purple = Color(0xFF4A148C);

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
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFF69F0AE), shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text('Live',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF69F0AE),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildModulesGrid(context)),
          SliverToBoxAdapter(child: _buildAiInsightBanner()),
          SliverToBoxAdapter(child: _buildRecentInsights(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.blueAccent,
      ),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.psychology, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Powered by AI & Machine Learning',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 11)),
                    Text('4 Intelligence Modules',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ]),
            ),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              _headerChip('87%', 'Accuracy'),
              const SizedBox(width: 8),
              _headerChip('156', 'Doctors'),
              const SizedBox(width: 8),
              _headerChip('23', 'Insights'),
              const SizedBox(width: 8),
              _headerChip('5', 'Regions'),
            ],
          ),
        ],
      ),
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
            style:
                GoogleFonts.poppins(color: Colors.white70, fontSize: 10)),
      ]),
    );
  }

  Widget _buildModulesGrid(BuildContext context) {
    final modules = [
      _AiModule(
        icon: Icons.support_agent,
        title: 'Sales Assistant',
        subtitle: 'Doctor insights, conversion prediction & meeting playbooks',
        color: const Color(0xFF1565C0),
        metrics: ['87% accuracy', '23 insights', '8 playbooks'],
        badge: 'New',
        screen: const AiSalesAssistantScreen(),
      ),
      _AiModule(
        icon: Icons.trending_up,
        title: 'Product Performance',
        subtitle: 'Sales trends, region analytics & conversion tracking',
        color: const Color(0xFF2E7D32),
        metrics: ['12 products', '+18% growth', '5 regions'],
        badge: null,
        screen: const AiProductPerformanceScreen(),
      ),
      _AiModule(
        icon: Icons.person_search,
        title: 'Doctor Review',
        subtitle: 'Engagement trends, objections & product affinity',
        color: const Color(0xFF6A1B9A),
        metrics: ['156 doctors', '12 flagged', 'Objection map'],
        badge: '12 alerts',
        screen: const AiDoctorReviewScreen(),
      ),
      _AiModule(
        icon: Icons.groups,
        title: 'Employee Reports',
        subtitle: 'Performance analysis, peer comparison & coaching',
        color: const Color(0xFFBF360C),
        metrics: ['24 reps', '96% avg', 'Coaching ready'],
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
        children:
            modules.map((m) => _AiModuleCard(module: m)).toList(),
      ),
    );
  }

  Widget _buildAiInsightBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0277BD), Color(0xFF01579B)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top AI Insight Today',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 10)),
                Text(
                    'Dr. Amit Shah is 3× more likely to convert on CardioMax '
                    'this week based on CLM visit history & reaction data.',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.4)),
              ]),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_ios,
            color: Colors.white54, size: 14),
      ]),
    );
  }

  Widget _buildRecentInsights(BuildContext context) {
    final items = [
      _InsightItem(
        tag: 'Product',
        text: 'DiabetaControl up 22% in Pune region this month',
        icon: Icons.trending_up,
        color: const Color(0xFF2E7D32),
        screen: const AiProductPerformanceScreen(),
      ),
      _InsightItem(
        tag: 'Doctor Review',
        text: 'Dr. Vikram Singh flagged – no visit in 45 days',
        icon: Icons.warning_amber,
        color: const Color(0xFFE65100),
        screen: const AiDoctorReviewScreen(),
      ),
      _InsightItem(
        tag: 'Sales',
        text: 'AI playbooks ready for 8 doctors planned today',
        icon: Icons.article_outlined,
        color: const Color(0xFF1565C0),
        screen: const AiSalesAssistantScreen(),
      ),
      _InsightItem(
        tag: 'Employee',
        text: 'Suresh Nair – 105% target achieved, top performer',
        icon: Icons.emoji_events_outlined,
        color: const Color(0xFF6A1B9A),
        screen: const AiEmployeeReportsScreen(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Text('Recent AI Insights',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
        ),
        ...items.map((item) => GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => item.screen)),
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
                        color: item.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(item.icon, color: item.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.tag,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: item.color,
                                  fontWeight: FontWeight.w700)),
                          Text(item.text,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.black87)),
                        ]),
                  ),
                  Icon(Icons.chevron_right,
                      color: Colors.grey.shade400, size: 18),
                ]),
              ),
            )),
      ],
    );
  }
}

class _AiModule {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final List<String> metrics;
  final String? badge;
  final Widget screen;

  const _AiModule({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.metrics,
    required this.badge,
    required this.screen,
  });
}

class _InsightItem {
  final String tag;
  final String text;
  final IconData icon;
  final Color color;
  final Widget screen;

  const _InsightItem({
    required this.tag,
    required this.text,
    required this.icon,
    required this.color,
    required this.screen,
  });
}

class _AiModuleCard extends StatelessWidget {
  final _AiModule module;
  const _AiModuleCard({required this.module});

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: module.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(module.icon, color: module.color, size: 22),
                ),
                if (module.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
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
              ],
            ),
            const SizedBox(height: 12),
            Text(module.title,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            const SizedBox(height: 3),
            Text(module.subtitle,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade600),
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
                            color: module.color,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(m,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700)),
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
          ],
        ),
      ),
    );
  }
}
