import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/models/ai_hub_models.dart';
import '../../providers/ai_hub_provider.dart';

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
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiHubProvider>().loadDoctorReview();
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
          const Icon(Icons.person_search, size: 18),
          const SizedBox(width: 8),
          Text('Doctor Review',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<AiHubProvider>(
            builder: (ctx, prov, child) => IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () => prov.loadDoctorReview(forceRefresh: true),
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
            Tab(text: 'All Doctors'),
            Tab(text: 'Flagged'),
          ],
        ),
      ),
      body: Consumer<AiHubProvider>(
        builder: (ctx, prov, child) {
          if (prov.doctorState == AiHubLoadState.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = prov.doctorData;
          if (data == null || data.doctors.isEmpty) {
            return _buildEmpty('No doctor data available');
          }
          return TabBarView(
            controller: _tab,
            children: [
              _buildAllDoctorsTab(data),
              _buildFlaggedTab(data),
            ],
          );
        },
      ),
    );
  }

  // ─── All Doctors ──────────────────────────────────────────────────────────────

  Widget _buildAllDoctorsTab(AiDoctorReviewData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary row
        Row(children: [
          _chip('${data.doctors.length}', 'Total', _purple),
          const SizedBox(width: 10),
          _chip('${data.highCount}', 'High Eng.', const Color(0xFF1B5E20)),
          const SizedBox(width: 10),
          _chip('${data.flaggedCount}', 'Flagged', Colors.redAccent),
          const SizedBox(width: 10),
          _chip('${data.avgEngagement.toStringAsFixed(0)}%', 'Avg Score',
              Colors.blueAccent),
        ]),
        const SizedBox(height: 14),
        if (data.observation != null)
          _aiCard('AI Observation', data.observation!.text, Icons.insights,
              _purple),
        const SizedBox(height: 16),
        _sectionHead('Doctor Engagement Scores',
            'Sorted by risk level — flagged doctors appear first'),
        const SizedBox(height: 10),
        ...data.doctors.map(_buildDoctorCard),
      ]),
    );
  }

  Widget _chip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                  fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildDoctorCard(AiDoctorScore d) {
    final color = d.engagementColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: d.isFlagged
            ? Border.all(color: Colors.redAccent.withValues(alpha: 0.4))
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
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(d.initials,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(d.doctorName,
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                if (d.isFlagged) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.warning_amber,
                      size: 14, color: Colors.redAccent),
                ],
              ]),
              Text(d.speciality,
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text(d.engagementLevel,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.bold)),
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
        if (d.isFlagged && d.flagReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 12, color: Colors.redAccent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(d.flagReason!,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.redAccent)),
                ),
              ]),
            ),
          ),
        if (d.daysSinceVisit > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${d.daysSinceVisit} days since last visit',
              style: TextStyle(
                  fontSize: 10,
                  color: d.daysSinceVisit > 30
                      ? Colors.redAccent
                      : Colors.grey.shade500),
            ),
          ),
      ]),
    );
  }

  // ─── Flagged Tab ──────────────────────────────────────────────────────────────

  Widget _buildFlaggedTab(AiDoctorReviewData data) {
    final flagged = data.doctors.where((d) => d.isFlagged).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber, color: Colors.redAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${flagged.length} Doctors Require Attention',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent)),
                Text(
                    'These doctors have not been visited in over 30 days '
                    'or show a declining engagement trend.',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade600, height: 1.4)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (flagged.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.green, size: 24),
              const SizedBox(width: 10),
              const Text('No flagged doctors — great coverage!',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w600)),
            ]),
          )
        else
          ...flagged.map(_buildDoctorCard),
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
