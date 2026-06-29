import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/models/ai_hub_models.dart';
import '../../providers/ai_hub_provider.dart';

class AiSalesAssistantScreen extends StatefulWidget {
  const AiSalesAssistantScreen({super.key});

  @override
  State<AiSalesAssistantScreen> createState() => _AiSalesAssistantScreenState();
}

class _AiSalesAssistantScreenState extends State<AiSalesAssistantScreen>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF1565C0);
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiHubProvider>().loadSalesAssistant();
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
          const Icon(Icons.support_agent, size: 18),
          const SizedBox(width: 8),
          Text('Sales Assistant',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<AiHubProvider>(
            builder: (ctx, prov, child) => IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () => prov.loadSalesAssistant(forceRefresh: true),
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
            Tab(text: 'Engagement'),
            Tab(text: 'Playbooks'),
            Tab(text: 'Recommend'),
          ],
        ),
      ),
      body: Consumer<AiHubProvider>(
        builder: (ctx, prov, child) {
          if (prov.salesState == AiHubLoadState.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = prov.salesData;
          if (data == null) {
            return _buildEmpty('No sales data available');
          }
          return TabBarView(
            controller: _tab,
            children: [
              _buildEngagementTab(data),
              _buildPlaybooksTab(data),
              _buildRecommendationsTab(data),
            ],
          );
        },
      ),
    );
  }

  // ─── Tab 1: Engagement ────────────────────────────────────────────────────────

  Widget _buildEngagementTab(AiSalesAssistantData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (data.observation != null)
          _aiCard(
            'AI Observation',
            data.observation!.text,
            Icons.insights,
            _blue,
          ),
        const SizedBox(height: 16),
        _sectionHead('Doctor Engagement Score',
            'Based on CLM visits, content views & reactions'),
        const SizedBox(height: 10),
        ...data.doctorScores.map(_buildEngCard),
        const SizedBox(height: 16),
        _sectionHead(
            'Conversion Prediction', 'AI likelihood score – next 30 days'),
        const SizedBox(height: 10),
        ...data.doctorScores
            .where((d) => d.conversionProduct != null)
            .map(_buildConvCard),
      ]),
    );
  }

  Widget _buildEngCard(AiDoctorScore d) {
    final color = d.engagementColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _blue.withValues(alpha: 0.1),
            child: Text(d.initials,
                style: TextStyle(
                    color: _blue, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.doctorName,
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text(d.speciality,
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ]),
          ),
          if (d.isFlagged)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('Flagged',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.red,
                      fontWeight: FontWeight.bold)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(d.engagementLevel,
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('Engagement',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const Spacer(),
          Text('${d.engagementScore}%',
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: d.engagementScore / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        if (d.daysSinceVisit > 30)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${d.daysSinceVisit} days since last visit',
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w500)),
          ),
      ]),
    );
  }

  Widget _buildConvCard(AiDoctorScore d) {
    final score = d.conversionScore;
    final color = score >= 80
        ? const Color(0xFF1B5E20)
        : score >= 60
            ? const Color(0xFFE65100)
            : const Color(0xFFB71C1C);

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
          decoration:
              BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Center(
              child: Text('$score%',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.doctorName,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            Text('→ ${d.conversionProduct ?? ''}',
                style:
                    TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text(d.conversionLevel,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ─── Tab 2: Playbooks ─────────────────────────────────────────────────────────

  Widget _buildPlaybooksTab(AiSalesAssistantData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiCard(
          "Today's Priority",
          '${data.playbooks.length} AI meeting playbooks ready for today\'s '
              'planned visits. Personalised strategies based on CLM interactions.',
          Icons.auto_awesome,
          _blue,
        ),
        const SizedBox(height: 16),
        _sectionHead('AI Meeting Playbooks',
            'Personalised preparation for each doctor'),
        const SizedBox(height: 10),
        ...data.playbooks.map(_buildPlaybookCard),
        const SizedBox(height: 16),
        if (data.scheduling.isNotEmpty) _buildSmartScheduling(data),
      ]),
    );
  }

  Widget _buildPlaybookCard(AiPlaybook p) {
    final priorityColor = p.priority == 'urgent'
        ? Colors.red
        : p.priority == 'high'
            ? Colors.orange
            : _blue;
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
              Text(p.brandName,
                  style: TextStyle(
                      fontSize: 10,
                      color: _blue.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Text(
              p.priority == 'urgent'
                  ? 'Urgent'
                  : p.priority == 'high'
                      ? 'High Priority'
                      : 'AI Ready',
              style: TextStyle(
                  fontSize: 9,
                  color: priorityColor,
                  fontWeight: FontWeight.bold),
            ),
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
                  fontSize: 11, color: Colors.grey.shade700, height: 1.5)),
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
                        style:
                            const TextStyle(fontSize: 10, color: _blue)),
                  ))
              .toList(),
        ),
      ]),
    );
  }

  Widget _buildSmartScheduling(AiSalesAssistantData data) {
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
        ...data.scheduling.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                    width: 56,
                    child: Text(s.suggestedDay,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600))),
                Icon(s.icon, size: 13, color: s.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(s.doctorName,
                        style: GoogleFonts.poppins(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                    Text(s.reason,
                        style: TextStyle(
                            fontSize: 9, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            )),
      ]),
    );
  }

  // ─── Tab 3: Recommendations ───────────────────────────────────────────────────

  Widget _buildRecommendationsTab(AiSalesAssistantData data) {
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
        ...data.productFit.map(_buildRecCard),
        const SizedBox(height: 16),
        if (data.segments.isNotEmpty) _buildSegmentCard(data),
      ]),
    );
  }

  Widget _buildRecCard(AiProductPerformance r) {
    final color = r.scoreColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecor(),
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
              Text(r.productName,
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              Text(r.targetSpecialities,
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${r.fitScore}% fit',
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold)),
            Text(r.growthValue,
                style: TextStyle(
                    fontSize: 11,
                    color: r.growthPositive
                        ? Colors.green.shade700
                        : Colors.red.shade600,
                    fontWeight: FontWeight.w600)),
          ]),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: r.fitScore / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ]),
    );
  }

  Widget _buildSegmentCard(AiSalesAssistantData data) {
    final maxCount = data.segments
        .map((s) => s.doctorCount)
        .fold(0, (a, b) => a > b ? a : b);

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
        ...data.segments.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                    width: 110,
                    child: Text(s.speciality,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: Stack(children: [
                    Container(
                        height: 8,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(
                      widthFactor: maxCount > 0 ? s.doctorCount / maxCount : 0,
                      child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                              color: s.color,
                              borderRadius: BorderRadius.circular(4))),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                Text('${s.doctorCount}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: s.color)),
                const SizedBox(width: 6),
                Text(s.topProduct,
                    style: TextStyle(
                        fontSize: 9, color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis),
              ]),
            )),
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87)),
      Text(sub,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]);
  }

  Widget _buildEmpty(String msg) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: Colors.grey.shade600)),
        ]),
      );

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
