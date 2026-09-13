import 'package:flutter/material.dart';
import 'package:zforce/features/pod/models/statement_detail_model.dart';
import 'package:zforce/features/pod/services/statement_detail_service.dart';
import 'package:zforce/features/pod/widgets/statement_header_card.dart';
import 'package:zforce/features/pod/widgets/statement_kpi_grid.dart';
import 'package:zforce/features/pod/widgets/statement_charts_section.dart';
import 'package:zforce/features/pod/widgets/doctor_mapping_banner.dart';
import 'package:zforce/features/pod/widgets/statement_product_table.dart';

// ============================================================
// StatementDetailScreen — full statement detail view
// Modern, clean UI matching the web version.
// ============================================================

class StatementDetailScreen extends StatefulWidget {
  final int podId;
  const StatementDetailScreen({super.key, required this.podId});

  @override
  State<StatementDetailScreen> createState() => _StatementDetailScreenState();
}

class _StatementDetailScreenState extends State<StatementDetailScreen> {
  Future<StatementDetail>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = StatementDetailService.fetchDetail(widget.podId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFEEEEEE), height: 1),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Statement Details',
          style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: -0.3),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<StatementDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString().replaceFirst('Exception: ', ''),
              onRetry: _load,
            );
          }
          return _BodyView(detail: snapshot.data!);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Loading
// ─────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: Color(0xFF450095)),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading statement…',
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Error
// ─────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 40, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            const Text(
              'Failed to load statement',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF450095),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Body — scrollable content
// ─────────────────────────────────────────────

class _BodyView extends StatelessWidget {
  final StatementDetail detail;
  const _BodyView({required this.detail});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header card
          StatementHeaderCard(detail: detail),
          const SizedBox(height: 14),

          // 2. Totals strip
          StatementTotalsStrip(detail: detail),
          const SizedBox(height: 14),

          // 3. KPI grid
          StatementKpiGrid(detail: detail),
          const SizedBox(height: 20),

          // 4. Analytics section
          _SectionHeader(
            icon: Icons.insights_rounded,
            label: 'Analytics',
            subtitle: 'Charts update as backend populates data',
          ),
          const SizedBox(height: 10),
          StatementChartsSection(detail: detail),
          const SizedBox(height: 20),

          // 5. Doctor Mapping section
          _SectionHeader(
            icon: Icons.people_alt_rounded,
            label: 'Doctor Mapping',
          ),
          const SizedBox(height: 10),
          DoctorMappingBanner(summary: detail.mappingSummary),
          const SizedBox(height: 20),

          // 6. Products table section
          _SectionHeader(
            icon: Icons.table_chart_rounded,
            label: 'Products',
          ),
          const SizedBox(height: 10),
          StatementProductTable(items: detail.items, podId: detail.id),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  const _SectionHeader({
    required this.icon,
    required this.label,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF450095),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: const Color(0xFF450095)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: -0.2),
              ),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ],
    );
  }
}
