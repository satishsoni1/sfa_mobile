import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/clm_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clm_provider.dart';
import '../../providers/dcr_provider.dart';
import '../dcr/dcr_dashboard_screen.dart';
import 'clm_doctor_list_screen.dart';
import 'clm_sync_screen.dart';
import 'clm_team_screen.dart';

class ClmHomeScreen extends StatefulWidget {
  const ClmHomeScreen({super.key});

  @override
  State<ClmHomeScreen> createState() => _ClmHomeScreenState();
}

class _ClmHomeScreenState extends State<ClmHomeScreen>
    with SingleTickerProviderStateMixin {
  static const _purple = Color(0xFF4A148C);
  static const _purpleLight = Color(0xFF7B1FA2);

  late TabController _tabCtrl;
  bool _hasSubordinates = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ClmProvider>().init();
        _checkRole();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _checkRole() {
    final user = context.read<AuthProvider>().user;
    // Show team tab for managers (ASM / RSM / ZSM / NSM)
    final mgr = ['asm', 'rsm', 'zsm', 'nsm', 'manager'];
    final des = (user?.designation ?? '').toLowerCase();
    setState(() {
      _hasSubordinates = mgr.any((r) => des.contains(r));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [_buildAppBar()],
        body: _hasSubordinates
            ? Column(children: [
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildMyActivity(),
                      ChangeNotifierProvider.value(
                        value: context.read<ClmProvider>(),
                        child: const ClmTeamScreen(),
                      ),
                    ],
                  ),
                ),
              ])
            : _buildMyActivity(),
      ),
      floatingActionButton: _buildStartFab(),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: _purple,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VODOCLM',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text(DateFormat('EEEE, d MMM').format(DateTime.now()),
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_purple, _purpleLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 42, 16, 0),
              child: Icon(Icons.medical_services_outlined,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
        ),
      ),
      actions: [
        // Active session indicator
        Consumer<ClmProvider>(
          builder: (_, prov, _) {
            final active = prov.activeSession;
            if (active == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'Active: ${active.doctorName}',
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.green.shade300, width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.radio_button_checked,
                        size: 10, color: Colors.greenAccent),
                    const SizedBox(width: 5),
                    Text('Live',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.cloud_sync_outlined),
          tooltip: 'Sync & Download',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: context.read<ClmProvider>(),
                child: const ClmSyncScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Tab Bar (visible only for managers) ─────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: _purple,
      child: TabBar(
        controller: _tabCtrl,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(icon: Icon(Icons.person_outlined, size: 18), text: 'My Activity'),
          Tab(icon: Icon(Icons.groups_outlined, size: 18), text: 'Team View'),
        ],
      ),
    );
  }

  // ─── My Activity Content ─────────────────────────────────────────────────────

  Widget _buildMyActivity() {
    return RefreshIndicator(
      onRefresh: () => context.read<ClmProvider>().init(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _buildActiveSessBanner(),
          _buildSyncBanner(),
          const SizedBox(height: 14),
          _buildStatCards(),
          const SizedBox(height: 20),
          _buildQuickActions(),
          const SizedBox(height: 20),
          _buildRecentSessions(),
        ],
      ),
    );
  }

  // ─── Active Session Banner ────────────────────────────────────────────────────

  Widget _buildActiveSessBanner() {
    return Consumer<ClmProvider>(
      builder: (_, prov, _) {
        final sess = prov.activeSession;
        if (sess == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade300, width: 1.5),
          ),
          child: Row(children: [
            const Icon(Icons.radio_button_checked,
                size: 16, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Active session in progress',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.green.shade800)),
                Text('Dr. ${sess.doctorName} · Started ${DateFormat("h:mm a").format(sess.startTime)}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.green.shade700)),
              ]),
            ),
            ElevatedButton(
              onPressed: _navigateToDoctors,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Resume', style: TextStyle(fontSize: 12)),
            ),
          ]),
        );
      },
    );
  }

  // ─── Sync Banner ──────────────────────────────────────────────────────────────

  Widget _buildSyncBanner() {
    return Consumer<ClmProvider>(
      builder: (_, prov, _) {
        final status = prov.syncStatus;
        final pending = prov.pendingUploads;

        if (status.state == SyncState.idle && pending == 0) {
          return const SizedBox.shrink();
        }

        Color bg; IconData icon; String label; Color textColor;

        if (status.state == SyncState.syncing) {
          bg = Colors.blue.shade50; icon = Icons.sync;
          label = status.message.isNotEmpty ? status.message : 'Syncing…';
          textColor = Colors.blue.shade800;
        } else if (status.state == SyncState.error) {
          bg = Colors.red.shade50; icon = Icons.error_outline;
          label = 'Sync failed. Tap to retry.';
          textColor = Colors.red.shade800;
        } else if (pending > 0) {
          bg = Colors.amber.shade50; icon = Icons.upload_outlined;
          label = '$pending session${pending != 1 ? 's' : ''} pending upload';
          textColor = Colors.amber.shade900;
        } else {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            if (status.state == SyncState.syncing)
              const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 10),
            Expanded(child: Text(label,
                style: TextStyle(fontSize: 12, color: textColor))),
            if (status.state != SyncState.syncing)
              TextButton(
                onPressed: () => context.read<ClmProvider>().syncNow(),
                style: TextButton.styleFrom(
                    foregroundColor: _purple,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(56, 28)),
                child: const Text('Sync Now', style: TextStyle(fontSize: 12)),
              ),
          ]),
        );
      },
    );
  }

  // ─── Stat Cards ───────────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    return Consumer<ClmProvider>(
      builder: (_, prov, _) {
        final stats = prov.todayStats;
        final sessions = stats['sessions'] ?? 0;
        final mins = stats['total_minutes'] ?? 0;
        final doctors = prov.filteredDoctors.length;
        final brands = prov.allBrands.length;

        return Row(children: [
          _statCard('Visits\nToday', '$sessions',
              Icons.person_pin_outlined, Colors.green.shade600),
          const SizedBox(width: 8),
          _statCard('Time\nSpent', '${mins}m',
              Icons.timer_outlined, Colors.blue.shade600),
          const SizedBox(width: 8),
          _statCard('Doctors', '$doctors',
              Icons.people_alt_outlined, Colors.orange.shade600),
          const SizedBox(width: 8),
          _statCard('Brands', '$brands',
              Icons.medication_outlined, _purple),
        ]);
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6, offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15, color: Colors.black87)),
          Text(label,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ─── Quick Actions ────────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quick Actions',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 14)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _actionCard(
          icon: Icons.person_search_outlined,
          label: 'Doctor List',
          subtitle: 'Browse & filter',
          color: _purple,
          onTap: _navigateToDoctors,
        )),
        const SizedBox(width: 10),
        Expanded(child: _actionCard(
          icon: Icons.download_for_offline_outlined,
          label: 'Sync & Download',
          subtitle: 'Get latest data',
          color: Colors.teal.shade700,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: context.read<ClmProvider>(),
                child: const ClmSyncScreen(),
              ),
            ),
          ),
        )),
      ]),
      const SizedBox(height: 10),
      _actionCard(
        icon: Icons.assignment_outlined,
        label: 'Daily Call Report (DCR)',
        subtitle: 'Visits · Samples · RCPA · Pending Drafts',
        color: const Color(0xFFE65100),
        onTap: _navigateToDcr,
      ),
    ]);
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6, offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500)),
              ]),
            ),
            Icon(Icons.chevron_right,
                color: Colors.grey.shade400, size: 18),
          ]),
        ),
    );
  }

  // ─── Recent Sessions ──────────────────────────────────────────────────────────

  Widget _buildRecentSessions() {
    return Consumer<ClmProvider>(
      builder: (_, prov, _) {
        final sessions = prov.recentSessions;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Recent Presentations',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const Spacer(),
            if (sessions.isNotEmpty)
              Text('${sessions.length} total',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
          ]),
          const SizedBox(height: 10),
          if (sessions.isEmpty)
            _emptySessionCard()
          else
            ...sessions.take(8).map(_sessionCard),
        ]);
      },
    );
  }

  Widget _emptySessionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        Icon(Icons.slideshow_outlined,
            size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text('No presentations yet',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        const SizedBox(height: 4),
        Text('Tap "Start CLM" to begin your first session',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
      ]),
    );
  }

  Widget _sessionCard(ClmSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: _purple.withValues(alpha: 0.1),
          child: Text(
            session.doctorName.isNotEmpty
                ? session.doctorName[0].toUpperCase()
                : '?',
            style: TextStyle(
                color: _purple,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(session.doctorName,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            Text(
              DateFormat('d MMM yy · h:mm a').format(session.startTime),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(session.durationLabel,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: session.isSynced
                  ? Colors.green.shade50
                  : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              session.isSynced ? 'Synced' : 'Pending',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: session.isSynced
                      ? Colors.green.shade700
                      : Colors.amber.shade700),
            ),
          ),
        ]),
      ]),
    );
  }

  // ─── FAB ──────────────────────────────────────────────────────────────────────

  Widget _buildStartFab() {
    return Consumer<ClmProvider>(
      builder: (_, prov, _) {
        final active = prov.activeSession;
        if (active != null) {
          return FloatingActionButton.extended(
            onPressed: _navigateToDoctors,
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.play_circle_outline),
            label: Text('Resume – ${active.doctorName.split(' ').first}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          );
        }
        return FloatingActionButton.extended(
          onPressed: _navigateToDoctors,
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.play_circle_outline),
          label: Text('Start CLM',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        );
      },
    );
  }

  // ─── Navigation ───────────────────────────────────────────────────────────────

  void _navigateToDoctors() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<ClmProvider>(),
          child: const ClmDoctorListScreen(),
        ),
      ),
    );
  }

  void _navigateToDcr() {
    final dcrProv = DcrProvider();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: dcrProv,
          child: const DcrDashboardScreen(),
        ),
      ),
    );
  }
}
