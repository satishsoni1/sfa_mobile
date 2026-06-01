import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/clm_models.dart';
import '../../providers/clm_provider.dart';
import 'clm_cart_screen.dart';

class ClmDoctorProfileScreen extends StatefulWidget {
  final ClmDoctor doctor;
  const ClmDoctorProfileScreen({super.key, required this.doctor});

  @override
  State<ClmDoctorProfileScreen> createState() => _ClmDoctorProfileScreenState();
}

class _ClmDoctorProfileScreenState extends State<ClmDoctorProfileScreen>
    with SingleTickerProviderStateMixin {
  static const _purple = Color(0xFF4A148C);

  late TabController _tabCtrl;
  List<ClmVisitSummary> _visits = [];
  List<ClmCallReport> _reports = [];
  ClmDoctorStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prov = context.read<ClmProvider>();
    final results = await Future.wait([
      prov.getVisitHistory(widget.doctor.id, limit: 10),
      prov.getCallReportsForDoctor(widget.doctor.id),
      prov.getDoctorStats(widget.doctor.id),
    ]);
    if (!mounted) return;
    setState(() {
      _visits = results[0] as List<ClmVisitSummary>;
      _reports = results[1] as List<ClmCallReport>;
      _stats = results[2] as ClmDoctorStats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doctor;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          _buildSliverHeader(doc),
        ],
        body: Column(
          children: [
            _buildReminderBanners(doc),
            _buildStatsRow(),
            _buildTabBar(),
            Expanded(child: _buildTabBarView()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startCall(context),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.play_circle_outline),
        label: Text('Start Call', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ─── Sliver App Bar ───────────────────────────────────────────────────────────

  Widget _buildSliverHeader(ClmDoctor doc) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: _purple,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(doc.initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doc.name,
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17)),
                            Text(doc.speciality,
                                style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            if (doc.hospital != null) ...[
                              const SizedBox(height: 2),
                              Row(children: [
                                const Icon(Icons.local_hospital_outlined,
                                    size: 12, color: Colors.white54),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(doc.hospital!,
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 11),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ]),
                            ],
                          ],
                        ),
                      ),
                      _catBadge(doc),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    if (doc.mobile.isNotEmpty)
                      _contactButton(Icons.call, doc.mobile, () => _call(doc.mobile)),
                    if (doc.email != null && doc.email!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _contactButton(Icons.email_outlined, doc.email!, () => _email(doc.email!)),
                    ],
                    const Spacer(),
                    _scheduleNextCallButton(context),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _catBadge(ClmDoctor doc) {
    final color = doc.category == 'A'
        ? Colors.red.shade400
        : doc.category == 'B'
            ? Colors.orange.shade400
            : Colors.blue.shade400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.6))),
      child: Text('Cat ${doc.category}',
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _contactButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _scheduleNextCallButton(BuildContext context) {
    final doc = widget.doctor;
    final hasNext = doc.nextCallDate != null;
    return GestureDetector(
      onTap: () => _pickNextCallDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: hasNext
                ? Colors.green.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: hasNext
                    ? Colors.green.shade300
                    : Colors.white.withValues(alpha: 0.3))),
        child: Row(children: [
          Icon(Icons.event_outlined,
              color: hasNext ? Colors.green.shade200 : Colors.white70, size: 13),
          const SizedBox(width: 5),
          Text(
            hasNext
                ? DateFormat('d MMM').format(doc.nextCallDate!)
                : 'Schedule',
            style: TextStyle(
                color: hasNext ? Colors.green.shade200 : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }

  // ─── Reminder Banners ─────────────────────────────────────────────────────────

  Widget _buildReminderBanners(ClmDoctor doc) {
    final banners = <Widget>[];
    if (doc.hasBirthdaySoon()) {
      banners.add(_reminderBanner(
          '🎂', 'Birthday on ${doc.birthdayLabel}', Colors.pink.shade50,
          Colors.pink.shade400));
    }
    if (doc.hasAnniversarySoon()) {
      banners.add(_reminderBanner(
          '💍', 'Anniversary on ${doc.anniversaryLabel}', Colors.amber.shade50,
          Colors.amber.shade700));
    }
    if (doc.nextCallDate != null &&
        doc.nextCallDate!.difference(DateTime.now()).inDays <= 1 &&
        doc.nextCallDate!.isAfter(DateTime.now())) {
      banners.add(_reminderBanner(
          '📅',
          'Next call due ${DateFormat('d MMM').format(doc.nextCallDate!)}',
          Colors.blue.shade50,
          Colors.blue.shade600));
    }
    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(children: banners),
    );
  }

  Widget _reminderBanner(String emoji, String text, Color bg, Color fg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Text(text,
            style: TextStyle(
                color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }

  // ─── Stats Row ────────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    final s = _stats;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]),
      child: Row(children: [
        _statCell('${s?.totalSessions ?? 0}', 'Total Visits'),
        _divider(),
        _statCell('${s?.totalMinutes ?? 0}m', 'Time Spent'),
        _divider(),
        _statCell(
            s?.lastSession != null
                ? DateFormat('d MMM').format(s!.lastSession!)
                : '—',
            'Last Visit'),
        _divider(),
        _statCell(
            widget.doctor.nextCallDate != null
                ? DateFormat('d MMM').format(widget.doctor.nextCallDate!)
                : '—',
            'Next Call'),
      ]),
    );
  }

  Widget _statCell(String value, String label) => Expanded(
        child: Column(children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _purple)),
          Text(label,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ]),
      );

  Widget _divider() => Container(
      width: 1, height: 28, color: Colors.grey.shade200);

  // ─── Tabs ─────────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: _purple,
        unselectedLabelColor: Colors.grey.shade500,
        indicatorColor: _purple,
        labelStyle:
            GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Visit History'),
          Tab(text: 'Call Reports'),
          Tab(text: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildVisitHistoryTab(),
        _buildCallReportsTab(),
        _buildProfileTab(),
      ],
    );
  }

  // ─── Visit History Tab ────────────────────────────────────────────────────────

  Widget _buildVisitHistoryTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_visits.isEmpty) {
      return _emptyState(Icons.history, 'No visit history yet',
          'Start a CLM call with this doctor');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: _visits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _visitCard(_visits[i], i),
    );
  }

  Widget _visitCard(ClmVisitSummary v, int index) {
    final isFirst = index == 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isFirst
            ? Border.all(color: _purple.withValues(alpha: 0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(
                DateFormat('d MMM yyyy').format(v.visitDate),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _purple),
              ),
            ),
            if (isFirst) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4)),
                child: Text('Latest',
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold)),
              ),
            ],
            const Spacer(),
            if (v.reaction != null)
              Text(v.reaction!.emoji,
                  style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Row(children: [
              Icon(Icons.timer_outlined, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Text('${v.durationMinutes}m',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600)),
            ]),
          ]),
          const SizedBox(height: 10),
          // Brands discussed
          if (v.brandNames.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: v.brandNames
                  .map((b) => _chip(b, _purple.withValues(alpha: 0.08), _purple))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          // Slides shown
          Row(children: [
            Icon(Icons.slideshow_outlined,
                size: 12, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text('${v.slidesShown} slides shown',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            if (v.reaction != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.sentiment_satisfied_outlined,
                  size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(v.reaction!.label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600)),
            ],
          ]),
          // Topics discussed
          if (v.topicsDiscussed.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: v.topicsDiscussed
                  .map((t) => _chip(t, Colors.grey.shade100,
                      Colors.grey.shade700))
                  .toList(),
            ),
          ],
          // Notes
          if (v.callNotes != null && v.callNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes, size: 13, color: Colors.amber.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(v.callNotes!,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            height: 1.5)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Call Reports Tab ─────────────────────────────────────────────────────────

  Widget _buildCallReportsTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_reports.isEmpty) {
      return _emptyState(Icons.assignment_outlined, 'No call reports yet',
          'Submit a report after each visit');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: _reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _reportCard(_reports[i]),
    );
  }

  Widget _reportCard(ClmCallReport r) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(DateFormat('d MMM yyyy · h:mm a').format(r.createdAt),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const Spacer(),
            Text(r.reaction.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text(r.reaction.label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ]),
          if (r.callNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.callNotes,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade700, height: 1.5)),
          ],
          if (r.topicsDiscussed.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: r.topicsDiscussed
                  .map((t) => _chip(t, Colors.grey.shade100, Colors.grey.shade700))
                  .toList(),
            ),
          ],
          if (r.keyMessagesDelivered.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: r.keyMessagesDelivered
                  .map((m) => _chip(m, Colors.green.shade50, Colors.green.shade700))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            if (r.samplesGiven > 0) ...[
              Icon(Icons.science_outlined,
                  size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('${r.samplesGiven} samples',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(width: 12),
            ],
            if (r.competitorMentions.isNotEmpty) ...[
              Icon(Icons.warning_amber_outlined,
                  size: 12, color: Colors.orange.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(r.competitorMentions,
                    style: TextStyle(
                        fontSize: 11, color: Colors.orange.shade700),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
            if (r.nextCallDate != null) ...[
              const Spacer(),
              Icon(Icons.event, size: 12, color: Colors.blue.shade400),
              const SizedBox(width: 4),
              Text('Next: ${DateFormat('d MMM').format(r.nextCallDate!)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w600)),
            ],
          ]),
        ],
      ),
    );
  }

  // ─── Profile Tab ──────────────────────────────────────────────────────────────

  Widget _buildProfileTab() {
    final doc = widget.doctor;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      children: [
        _profileSection('Contact', [
          _profileRow(Icons.call, 'Mobile', doc.mobile),
          if (doc.email != null) _profileRow(Icons.email_outlined, 'Email', doc.email!),
          if (doc.address != null) _profileRow(Icons.location_on_outlined, 'Address', doc.address!),
        ]),
        const SizedBox(height: 12),
        _profileSection('Classification', [
          _profileRow(Icons.category_outlined, 'Category', 'Category ${doc.category}'),
          _profileRow(Icons.medical_services_outlined, 'Speciality', doc.speciality),
          _profileRow(Icons.map_outlined, 'Territory', doc.territory),
          _profileRow(Icons.place_outlined, 'Area', doc.area),
          _profileRow(Icons.local_hospital_outlined, 'Hospital', doc.hospital ?? '—'),
        ]),
        const SizedBox(height: 12),
        _profileSection('Dates & Reminders', [
          if (doc.birthday != null)
            _profileRow(Icons.cake_outlined, 'Birthday', doc.birthdayLabel ?? doc.birthday!),
          if (doc.anniversary != null)
            _profileRow(Icons.favorite_outline, 'Anniversary', doc.anniversaryLabel ?? doc.anniversary!),
          _profileRow(Icons.event_outlined, 'Next Call',
              doc.nextCallDate != null
                  ? DateFormat('d MMM yyyy').format(doc.nextCallDate!)
                  : 'Not scheduled'),
          _profileRow(Icons.repeat_outlined, 'Call Frequency',
              '${doc.callFrequencyTarget}×/month target'),
        ]),
        const SizedBox(height: 12),
        _profileSection('Engagement', [
          _profileRow(Icons.history, 'Total Sessions', '${doc.totalSessions}'),
          _profileRow(Icons.access_time, 'Last Visit', doc.daysSinceLabel),
          _profileRow(Icons.medication_outlined, 'Assigned Brands',
              '${doc.assignedBrandIds.length} products'),
        ]),
      ],
    );
  }

  Widget _profileSection(String title, List<Widget> rows) {
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
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _purple)),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 15, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500)),
        const Spacer(),
        Flexible(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  Widget _chip(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: fg)),
      );

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Future<void> _pickNextCallDate(BuildContext context) async {
    final prov = context.read<ClmProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.doctor.nextCallDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _purple),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    await prov.updateDoctorNextCallDate(widget.doctor.id, picked);
    if (mounted) setState(() {});
  }

  Future<void> _startCall(BuildContext context) async {
    final prov = context.read<ClmProvider>();
    final nav = Navigator.of(context);
    await prov.buildCartForDoctor(widget.doctor);
    if (!mounted) return;
    await nav.push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: ClmCartScreen(doctor: widget.doctor),
        ),
      ),
    );
    _load(); // Refresh after session
  }

  void _call(String number) =>
      launchUrl(Uri.parse('tel:$number'));

  void _email(String address) =>
      launchUrl(Uri.parse('mailto:$address'));
}
