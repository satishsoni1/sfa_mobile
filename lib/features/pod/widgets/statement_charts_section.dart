import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:zforce/features/pod/models/statement_detail_model.dart';

// ============================================================
// StatementChartsSection
// - Empty chart = small compact placeholder (60px tall)
// - Chart with data = grows to full size automatically
// - Responsive: stacks on narrow, side-by-side on wide
// ============================================================

class StatementChartsSection extends StatelessWidget {
  final StatementDetail detail;
  const StatementChartsSection({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final top10Sales    = _sortedTop10((it) => it.salesValue);
    final top10SalesQty = _sortedTop10((it) => it.salesQty);
    final top10Closing  = _sortedTop10((it) => it.closingValue);

    final hasDonut      = detail.salesValue + detail.closingValue > 0;
    final hasOpenClose  = detail.openingValue + detail.closingValue > 0;

    return LayoutBuilder(builder: (ctx, constraints) {
      final wide = constraints.maxWidth > 380;

      Widget donutCard = _ChartCard(
        title: 'Sales vs Closing Value',
        isEmpty: !hasDonut,
        child: hasDonut ? _SalesClosingDonut(detail: detail) : null,
      );
      Widget openCloseCard = _ChartCard(
        title: 'Opening vs Closing Value',
        isEmpty: !hasOpenClose,
        child: hasOpenClose ? _OpeningClosingBar(detail: detail) : null,
      );

      Widget top10ValueCard = _ChartCard(
        title: 'Top 10 by Sales Value',
        isEmpty: top10Sales.isEmpty,
        child: top10Sales.isNotEmpty
            ? _HBarChart(
                items: top10Sales,
                getValue: (it) => it.salesValue,
                color: const Color(0xFF4CAF50),
                fmtVal: (v) => '₹${NumberFormat.compact().format(v)}',
              )
            : null,
      );
      Widget top10QtyCard = _ChartCard(
        title: 'Top 10 by Sales Qty',
        isEmpty: top10SalesQty.isEmpty,
        child: top10SalesQty.isNotEmpty
            ? _HBarChart(
                items: top10SalesQty,
                getValue: (it) => it.salesQty,
                color: const Color(0xFF2196F3),
                fmtVal: (v) => NumberFormat.compact().format(v),
              )
            : null,
      );
      Widget closingStockCard = _ChartCard(
        title: 'Top by Closing Stock Value',
        isEmpty: top10Closing.isEmpty,
        child: top10Closing.isNotEmpty
            ? _HBarChart(
                items: top10Closing,
                getValue: (it) => it.closingValue,
                color: const Color(0xFF9C27B0),
                fmtVal: (v) => '₹${NumberFormat.compact().format(v)}',
                fullWidth: true,
              )
            : null,
      );

      if (wide) {
        return Column(children: [
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: donutCard),
              const SizedBox(width: 10),
              Expanded(child: openCloseCard),
            ]),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: top10ValueCard),
              const SizedBox(width: 10),
              Expanded(child: top10QtyCard),
            ]),
          ),
          const SizedBox(height: 10),
          closingStockCard,
        ]);
      }

      // Narrow — single column
      return Column(children: [
        donutCard,
        const SizedBox(height: 10),
        openCloseCard,
        const SizedBox(height: 10),
        top10ValueCard,
        const SizedBox(height: 10),
        top10QtyCard,
        const SizedBox(height: 10),
        closingStockCard,
      ]);
    });
  }

  List<StatementItem> _sortedTop10(double Function(StatementItem) key) {
    return ([...detail.items]
          ..sort((a, b) => key(b).compareTo(key(a))))
        .where((it) => key(it) > 0)
        .take(10)
        .toList();
  }
}

// ─────────────────────────────────────────────
// Chart card wrapper
// isEmpty=true → compact 56px placeholder
// isEmpty=false → natural height from child
// ─────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final bool isEmpty;
  final Widget? child;

  const _ChartCard({
    required this.title,
    required this.isEmpty,
    this.child,
  });

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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: -0.1)),
              ),
              if (isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('No data yet',
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                ),
            ]),
            if (isEmpty)
              // Compact placeholder — just a tiny bar to show the card exists
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  Icon(Icons.bar_chart_rounded, size: 28, color: Colors.grey.shade200),
                  const SizedBox(width: 8),
                  Text(
                    'Data will appear when backend\npopulates product details.',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ]),
              )
            else ...[
              const SizedBox(height: 12),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 1. Donut — Sales vs Closing Value
// ─────────────────────────────────────────────

class _SalesClosingDonut extends StatelessWidget {
  final StatementDetail detail;
  const _SalesClosingDonut({required this.detail});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,##0.00');
    return Column(children: [
      SizedBox(
        height: 160,
        child: PieChart(PieChartData(
          sections: [
            PieChartSectionData(
              value: detail.salesValue,
              color: const Color(0xFF4CAF50),
              title: '',
              radius: 48,
            ),
            PieChartSectionData(
              value: detail.closingValue,
              color: const Color(0xFF9C27B0),
              title: '',
              radius: 48,
            ),
          ],
          centerSpaceRadius: 44,
          sectionsSpace: 3,
        )),
      ),
      const SizedBox(height: 10),
      // Mini legend
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Dot(color: const Color(0xFF4CAF50)),
        const SizedBox(width: 4),
        Text('Sales  ₹${fmt.format(detail.salesValue)}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(width: 14),
        _Dot(color: const Color(0xFF9C27B0)),
        const SizedBox(width: 4),
        Text('Closing  ₹${fmt.format(detail.closingValue)}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    ]);
  }
}

// ─────────────────────────────────────────────
// 2. Bar — Opening vs Closing Value
// ─────────────────────────────────────────────

class _OpeningClosingBar extends StatelessWidget {
  final StatementDetail detail;
  const _OpeningClosingBar({required this.detail});

  @override
  Widget build(BuildContext context) {
    final maxY = ([detail.openingValue, detail.closingValue]
          .reduce((a, b) => a > b ? a : b)) *
        1.25;

    return SizedBox(
      height: 180,
      child: BarChart(BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (val, _) => Text(
                NumberFormat.compact().format(val),
                style: const TextStyle(fontSize: 8, color: Colors.grey),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (val, _) {
                final labels = ['Opening\nValue', 'Closing\nValue'];
                final i = val.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Text(labels[i],
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                    textAlign: TextAlign.center);
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey.shade100, strokeWidth: 1),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(
              toY: detail.openingValue,
              color: const Color(0xFF2196F3),
              width: 32,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(
              toY: detail.closingValue,
              color: const Color(0xFF9C27B0),
              width: 32,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ]),
        ],
      )),
    );
  }
}

// ─────────────────────────────────────────────
// Horizontal bar — reusable for charts 3/4/5
// ─────────────────────────────────────────────

class _HBarChart extends StatelessWidget {
  final List<StatementItem> items;
  final double Function(StatementItem) getValue;
  final Color color;
  final String Function(double) fmtVal;
  final bool fullWidth;

  const _HBarChart({
    required this.items,
    required this.getValue,
    required this.color,
    required this.fmtVal,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal =
        items.map(getValue).reduce((a, b) => a > b ? a : b);

    // Each bar row = 30px; add 20px bottom axis
    final height = (items.length * 30.0 + 24).clamp(80.0, 340.0);

    return SizedBox(
      height: height,
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.start,
        maxY: maxVal * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            getTooltipItem: (group, barIdx, rod, spotIdx) => BarTooltipItem(
              '${items[group.x].productName}\n',
              const TextStyle(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              children: [
                TextSpan(
                  text: fmtVal(rod.toY),
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: fullWidth ? 130 : 100,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= items.length) return const SizedBox.shrink();
                final name = items[idx].productName;
                final maxLen = fullWidth ? 18 : 13;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    name.length > maxLen ? '${name.substring(0, maxLen)}…' : name,
                    style: const TextStyle(fontSize: 8, color: Colors.black54),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (val, _) => Text(
                fmtVal(val),
                style: const TextStyle(fontSize: 7, color: Colors.grey),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: false,
          drawVerticalLine: true,
          verticalInterval: maxVal / 4,
          getDrawingVerticalLine: (_) =>
              FlLine(color: Colors.grey.shade100, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: items.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: getValue(e.value),
                color: color.withValues(alpha: 0.85),
                width: 16,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxVal * 1.2,
                  color: color.withValues(alpha: 0.06),
                ),
              ),
            ],
          );
        }).toList(),
      )),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
