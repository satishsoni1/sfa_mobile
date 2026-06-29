import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/services/api_service.dart';

// ─── Team Member Summary ──────────────────────────────────────────────────────

class _MrSummary {
  final String name;
  final String employeeCode;
  final String designation;
  final String area;

  // Today's CLM stats (from sessions in DB for that employee code)
  int callsToday;
  int samplesGiven;
  int minutesDetailed;
  String lastReaction;
  bool isCheckedIn;
  String? activeDoctor;
  int pendingDcr;

  _MrSummary({
    required this.name,
    required this.employeeCode,
    this.designation = 'MR',
    this.area = '',
    this.callsToday = 0,
    this.samplesGiven = 0,
    this.minutesDetailed = 0,
    this.lastReaction = '',
    this.isCheckedIn = false,
    this.activeDoctor,
    this.pendingDcr = 0,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ClmTeamScreen extends StatefulWidget {
  const ClmTeamScreen({super.key});

  @override
  State<ClmTeamScreen> createState() => _ClmTeamScreenState();
}

class _ClmTeamScreenState extends State<ClmTeamScreen> {
  static const _purple = Color(0xFF4A148C);

  List<_MrSummary> _team = [];
  bool _loading = true;
  String _filterArea = '';
  List<String> _areas = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ApiService();
      List<dynamic> subs = [];
      try {
        subs = await api.getSubordinates();
      } catch (_) {
        subs = [];
      }

      final team = <_MrSummary>[];
      for (final sub in subs) {
        team.add(_MrSummary(
          name: sub['name']?.toString() ?? 'Unknown',
          employeeCode: sub['employee_code']?.toString() ?? '',
          designation: sub['designation']?.toString() ?? 'MR',
          area: sub['area']?.toString() ?? '',
          // Live stats come from server; fallback to zero when not available
          callsToday: (sub['calls_today'] as num?)?.toInt() ?? 0,
          samplesGiven: (sub['samples_today'] as num?)?.toInt() ?? 0,
          minutesDetailed: (sub['minutes_today'] as num?)?.toInt() ?? 0,
          lastReaction: sub['last_reaction']?.toString() ?? '',
          isCheckedIn: sub['is_checked_in'] == true,
          activeDoctor: sub['active_doctor']?.toString(),
          pendingDcr: (sub['pending_dcr'] as num?)?.toInt() ?? 0,
        ));
      }

      // Seed demo team when API returns nothing (no subordinates configured)
      if (team.isEmpty) team.addAll(_demoTeam());

      final uniqueAreas = team.map((m) => m.area).where((a) => a.isNotEmpty).toSet().toList()..sort();

      if (mounted) {
        setState(() {
          _team = team;
          _areas = uniqueAreas;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _team = _demoTeam();
          _areas = _team.map((m) => m.area).where((a) => a.isNotEmpty).toSet().toList()..sort();
          _loading = false;
        });
      }
    }
  }

  List<_MrSummary> _demoTeam() => [
        _MrSummary(
          name: 'Rahul Sharma', employeeCode: 'MR001',
          designation: 'Senior MR', area: 'Zone A',
          callsToday: 6, samplesGiven: 8, minutesDetailed: 42,
          lastReaction: 'positive', isCheckedIn: true,
          activeDoctor: 'Dr. Mehta (Cardiology)',
        ),
        _MrSummary(
          name: 'Priya Nair', employeeCode: 'MR002',
          designation: 'MR', area: 'Zone A',
          callsToday: 4, samplesGiven: 5, minutesDetailed: 28,
          lastReaction: 'receptive', isCheckedIn: false,
        ),
        _MrSummary(
          name: 'Amit Joshi', employeeCode: 'MR003',
          designation: 'Senior MR', area: 'Zone B',
          callsToday: 7, samplesGiven: 10, minutesDetailed: 55,
          lastReaction: 'positive', isCheckedIn: false,
        ),
        _MrSummary(
          name: 'Deepa Krishnan', employeeCode: 'MR004',
          designation: 'MR', area: 'Zone B',
          callsToday: 2, samplesGiven: 2, minutesDetailed: 14,
          lastReaction: 'neutral', isCheckedIn: true,
          activeDoctor: 'Dr. Patel (Endocrinology)',
          pendingDcr: 2,
        ),
        _MrSummary(
          name: 'Suresh Rao', employeeCode: 'MR005',
          designation: 'MR', area: 'Zone C',
          callsToday: 0, samplesGiven: 0, minutesDetailed: 0,
          lastReaction: '', isCheckedIn: false,
          pendingDcr: 1,
        ),
        _MrSummary(
          name: 'Kavya Pillai', employeeCode: 'MR006',
          designation: 'Senior MR', area: 'Zone C',
          callsToday: 5, samplesGiven: 7, minutesDetailed: 38,
          lastReaction: 'positive', isCheckedIn: false,
        ),
      ];

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filterArea.isEmpty
        ? _team
        : _team.where((m) => m.area == _filterArea).toList();

    // Sort: checked-in first, then by calls today desc
    filtered.sort((a, b) {
      if (a.isCheckedIn && !b.isCheckedIn) return -1;
      if (!a.isCheckedIn && b.isCheckedIn) return 1;
      return b.callsToday.compareTo(a.callsToday);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text('Team Activity',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(children: [
                      _buildTeamHeader(filtered),
                      _buildActiveNow(filtered),
                      _buildAreaFilter(),
                    ]),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _buildMrCard(filtered[i]),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─── Team Header / Aggregate Stats ───────────────────────────────────────────

  Widget _buildTeamHeader(List<_MrSummary> filtered) {
    final totalCalls = filtered.fold(0, (s, m) => s + m.callsToday);
    final totalSamples = filtered.fold(0, (s, m) => s + m.samplesGiven);
    final totalMins = filtered.fold(0, (s, m) => s + m.minutesDetailed);
    final checkedIn = filtered.where((m) => m.isCheckedIn).length;
    final today = DateFormat('EEEE, d MMM').format(DateTime.now());

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(today, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 12),
        Row(children: [
          _headerStat('${filtered.length}', 'Team\nSize', Colors.white),
          _headerStat('$checkedIn', 'Active\nNow', Colors.greenAccent),
          _headerStat('$totalCalls', 'Calls\nToday', Colors.lightBlueAccent),
          _headerStat('$totalSamples', 'Samples\nGiven', Colors.orangeAccent),
          _headerStat('${totalMins}m', 'Detailing\nTime', Colors.purpleAccent.shade100),
        ]),
      ]),
    );
  }

  Widget _headerStat(String value, String label, Color color) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      );

  // ─── Active Now Strip ─────────────────────────────────────────────────────────

  Widget _buildActiveNow(List<_MrSummary> team) {
    final active = team.where((m) => m.isCheckedIn).toList();
    if (active.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.green.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        const Icon(Icons.radio_button_checked,
            size: 14, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${active.length} MR${active.length != 1 ? 's' : ''} active now: '
            '${active.map((m) => m.name.split(' ').first).join(', ')}',
            style: const TextStyle(color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  // ─── Area Filter Chips ────────────────────────────────────────────────────────

  Widget _buildAreaFilter() {
    if (_areas.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _areaChip('All Areas', ''),
          ..._areas.map((a) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _areaChip(a, a),
              )),
        ]),
      ),
    );
  }

  Widget _areaChip(String label, String value) {
    final sel = _filterArea == value;
    return GestureDetector(
      onTap: () => setState(() => _filterArea = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _purple : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _purple : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: sel ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }

  // ─── MR Card ──────────────────────────────────────────────────────────────────

  Widget _buildMrCard(_MrSummary mr) {
    final reactionEmoji = _reactionEmoji(mr.lastReaction);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: mr.isCheckedIn
            ? Border.all(color: Colors.green.shade300, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Avatar
            Stack(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _purple.withValues(alpha: 0.1),
                child: Text(
                  mr.name.isNotEmpty ? mr.name[0].toUpperCase() : '?',
                  style: TextStyle(color: _purple,
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              if (mr.isCheckedIn)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5)),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(mr.name,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                Row(children: [
                  Text(mr.designation,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                  if (mr.area.isNotEmpty) ...[
                    Text(' · ',
                        style: TextStyle(color: Colors.grey.shade400)),
                    Text(mr.area,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ]),
                if (mr.isCheckedIn && mr.activeDoctor != null) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.circle, size: 8, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('With ${mr.activeDoctor}',
                        style: TextStyle(
                            fontSize: 10, color: Colors.green.shade700,
                            fontWeight: FontWeight.w600)),
                  ]),
                ],
              ]),
            ),
            // Right side: status badge
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: mr.isCheckedIn
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  mr.isCheckedIn ? 'Active' : 'Offline',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: mr.isCheckedIn
                          ? Colors.green.shade700
                          : Colors.grey.shade500),
                ),
              ),
              if (mr.pendingDcr > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade200)),
                  child: Text('${mr.pendingDcr} DCR pending',
                      style: TextStyle(
                          fontSize: 9, color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ]),
          const SizedBox(height: 12),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              _mrStat('${mr.callsToday}', 'Calls',
                  Icons.person_pin_outlined, Colors.indigo),
              _mrStatDivider(),
              _mrStat('${mr.samplesGiven}', 'Samples',
                  Icons.medication_outlined, const Color(0xFFE65100)),
              _mrStatDivider(),
              _mrStat('${mr.minutesDetailed}m', 'Detailing',
                  Icons.timer_outlined, Colors.teal),
              _mrStatDivider(),
              Expanded(
                child: Column(children: [
                  Text(reactionEmoji.isEmpty ? '–' : reactionEmoji,
                      style: const TextStyle(fontSize: 18)),
                  Text('Last Rx',
                      style: TextStyle(
                          fontSize: 9, color: Colors.grey.shade500)),
                ]),
              ),
            ]),
          ),
          // Progress bar (calls target assumed 8/day)
          const SizedBox(height: 8),
          Row(children: [
            Text('Daily target',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            const Spacer(),
            Text('${mr.callsToday}/8',
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (mr.callsToday / 8).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              color: mr.callsToday >= 8
                  ? Colors.green
                  : mr.callsToday >= 4
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _mrStat(String value, String label, IconData icon, Color color) =>
      Expanded(
        child: Column(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          Text(label,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
        ]),
      );

  Widget _mrStatDivider() => Container(
      width: 1, height: 36, color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  String _reactionEmoji(String reaction) {
    switch (reaction.toLowerCase()) {
      case 'positive': return '😊';
      case 'receptive': return '🤔';
      case 'neutral': return '😐';
      case 'objection': return '❌';
      case 'not_available': return '🚫';
      default: return '';
    }
  }
}
