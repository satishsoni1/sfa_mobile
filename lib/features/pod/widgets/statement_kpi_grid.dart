import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zforce/features/pod/models/statement_detail_model.dart';

// ============================================================
// StatementKpiGrid — 2-column responsive KPI cards
// ============================================================

class StatementKpiGrid extends StatelessWidget {
  final StatementDetail detail;
  const StatementKpiGrid({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final fmt  = NumberFormat('#,##,##0.00');
    final fmtI = NumberFormat('#,##,##0');
    final salesQty = detail.items
        .fold<double>(0, (s, it) => s + it.salesQty)
        .toInt();

    final kpis = [
      _K('Opening Value',   '₹${fmt.format(detail.openingValue)}',
          Icons.account_balance_wallet_outlined, const Color(0xFF2196F3)),
      _K('Sales Value',     '₹${fmt.format(detail.salesValue)}',
          Icons.trending_up_rounded,             const Color(0xFF4CAF50)),
      _K('Closing Value',   '₹${fmt.format(detail.closingValue)}',
          Icons.price_check_rounded,             const Color(0xFF9C27B0)),
      _K('Purchase Return', '₹${fmt.format(detail.purchaseReturn)}',
          Icons.assignment_return_outlined,      const Color(0xFFFF9800)),
      _K('Opening Qty',     fmtI.format(detail.openingQty),
          Icons.inbox_outlined,                  const Color(0xFF009688)),
      _K('Total Products',  fmtI.format(detail.totalProducts),
          Icons.inventory_2_outlined,            const Color(0xFF3F51B5)),
      _K('Sales Qty',       fmtI.format(salesQty),
          Icons.shopping_cart_outlined,          const Color(0xFF4CAF50)),
      _K('Closing Qty',     fmtI.format(detail.closingQty),
          Icons.output_rounded,                  const Color(0xFF9C27B0)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kpis.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.1,
      ),
      itemBuilder: (_, i) => _KpiCard(k: kpis[i]),
    );
  }
}

class _K {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _K(this.label, this.value, this.icon, this.color);
}

class _KpiCard extends StatelessWidget {
  final _K k;
  const _KpiCard({required this.k});

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: k.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(k.icon, color: k.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  k.label,
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  k.value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: -0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
