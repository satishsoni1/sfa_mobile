import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zforce/features/pod/models/statement_detail_model.dart';

// ============================================================
// StatementHeaderCard — Modern, clean header card
// ============================================================

class StatementHeaderCard extends StatelessWidget {
  final StatementDetail detail;
  const StatementHeaderCard({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final stockistName =
        detail.stockist?['name']?.toString() ?? detail.customerName ?? '—';
    final from = _fmt(detail.reportPeriodFrom);
    final to   = _fmt(detail.reportPeriodTo);
    final periodLine = (from != '—' || to != '—') ? '$from → $to' : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Purple gradient top bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF450095), Color(0xFF7B1FA2)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.store_mall_directory_rounded,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'STOCKIST',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  stockistName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (periodLine != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.date_range_rounded,
                          color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${detail.reportDescription ?? "Report"} · $periodLine',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Info grid
          Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(builder: (ctx, constraints) {
              final wide = constraints.maxWidth > 360;
              final tiles = [
                _InfoTile(
                  icon: Icons.business_rounded,
                  label: 'Company',
                  value: detail.vendorName ?? '—',
                  color: const Color(0xFF2196F3),
                ),
                _InfoTile(
                  icon: Icons.location_on_rounded,
                  label: 'Address',
                  value: detail.stockist?['address']?.toString() ?? '—',
                  color: const Color(0xFF4CAF50),
                ),
                _InfoTile(
                  icon: Icons.upload_file_rounded,
                  label: 'Uploaded by',
                  value: detail.uploadedBy ?? '—',
                  color: const Color(0xFFFF9800),
                ),
                _InfoTile(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'File',
                  value: detail.sourceFileName ?? '—',
                  color: const Color(0xFF9C27B0),
                ),
              ];

              if (wide) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: tiles[0]),
                        const SizedBox(width: 10),
                        Expanded(child: tiles[1]),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: tiles[2]),
                        const SizedBox(width: 10),
                        Expanded(child: tiles[3]),
                      ],
                    ),
                  ],
                );
              }
              return Column(
                children: tiles.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: t,
                )).toList(),
              );
            }),
          ),

          // Status + Upload date footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                _StatusBadge(status: detail.status),
                const Spacer(),
                if (detail.uploadedAt != null) ...[
                  Icon(Icons.access_time_rounded,
                      size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    _fmtDatetime(detail.uploadedAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      return DateFormat('dd MMM yy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _fmtDatetime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      return DateFormat('dd MMM yyyy · HH:mm').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              const SizedBox(height: 1),
              Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String label;
    switch (status.toLowerCase()) {
      case 'extracted':
      case 'completed':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        icon = Icons.check_circle_rounded;
        label = 'Completed';
        break;
      case 'pending':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        icon = Icons.hourglass_top_rounded;
        label = 'Pending';
        break;
      case 'failed':
      case 'error':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFB71C1C);
        icon = Icons.error_rounded;
        label = 'Failed';
        break;
      default:
        bg = const Color(0xFFF3E5F5);
        fg = const Color(0xFF4A148C);
        icon = Icons.info_rounded;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: fg),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

// ============================================================
// StatementTotalsStrip — scrollable totals row
// ============================================================

class StatementTotalsStrip extends StatelessWidget {
  final StatementDetail detail;
  const StatementTotalsStrip({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,##0.00');
    final salesQty = detail.items.fold<double>(0, (s, it) => s + it.salesQty);
    final items = [
      _T('Sales Value',    '₹${fmt.format(detail.salesValue)}',   const Color(0xFF4CAF50)),
      _T('Closing Value',  '₹${fmt.format(detail.closingValue)}',  const Color(0xFF9C27B0)),
      _T('Opening Value',  '₹${fmt.format(detail.openingValue)}',  const Color(0xFF2196F3)),
      _T('Purchase Value', '₹${fmt.format(detail.purchaseValue)}', const Color(0xFFFF9800)),
      _T('Sales Qty',      fmt.format(salesQty),                   const Color(0xFF009688)),
      _T('Closing Qty',    fmt.format(detail.closingQty),          const Color(0xFF3F51B5)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Statement Totals',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.2)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items.asMap().entries.map((e) {
                return Row(children: [
                  _TotalCell(t: e.value),
                  if (e.key < items.length - 1)
                    Container(
                      width: 1,
                      height: 36,
                      color: Colors.grey.shade100,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _T {
  final String label;
  final String value;
  final Color color;
  const _T(this.label, this.value, this.color);
}

class _TotalCell extends StatelessWidget {
  final _T t;
  const _TotalCell({required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t.label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500, letterSpacing: 0.2)),
      const SizedBox(height: 3),
      Text(t.value,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: t.color,
              letterSpacing: -0.3)),
    ]);
  }
}
