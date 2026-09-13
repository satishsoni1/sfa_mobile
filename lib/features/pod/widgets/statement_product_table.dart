import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zforce/features/pod/models/statement_detail_model.dart';

// ============================================================
// StatementProductTable
// - Modern card with search bar
// - Responsive: horizontal scroll for wide DataTable
// - Empty state: friendly illustrated message
// ============================================================

class StatementProductTable extends StatefulWidget {
  final List<StatementItem> items;
  final int podId;

  const StatementProductTable({
    super.key,
    required this.items,
    required this.podId,
  });

  @override
  State<StatementProductTable> createState() => _StatementProductTableState();
}

class _StatementProductTableState extends State<StatementProductTable> {
  final TextEditingController _search = TextEditingController();
  List<StatementItem> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _search.addListener(_onSearch);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.items
          : widget.items
              .where((it) => it.productName.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF450095).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.table_chart_rounded,
                    color: Color(0xFF450095), size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Product-wise Secondary Sales',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: -0.2),
                ),
              ),
              if (widget.items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF450095).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.items.length} items',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF450095)),
                  ),
                ),
            ]),
          ),

          // Search bar (only shown when items exist)
          if (widget.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search products…',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 18, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF450095), width: 1.5),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),

          // Divider
          Divider(height: 1, color: Colors.grey.shade100),

          // Content
          widget.items.isEmpty
              ? _EmptyTableView()
              : _filtered.isEmpty
                  ? _NoResultsView(query: _search.text)
                  : _TableContent(items: _filtered, podId: widget.podId),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty states
// ─────────────────────────────────────────────

class _EmptyTableView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.table_rows_rounded,
                size: 32, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 14),
          const Text(
            'No product data yet',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            'Product details will appear here once\nthe backend returns item-level data.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _NoResultsView extends StatelessWidget {
  final String query;
  const _NoResultsView({required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(
            'No results for "$query"',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Table content
// ─────────────────────────────────────────────

class _TableContent extends StatelessWidget {
  final List<StatementItem> items;
  final int podId;
  const _TableContent({required this.items, required this.podId});

  @override
  Widget build(BuildContext context) {
    final fmt    = NumberFormat('#,##0.00');
    final fmtVal = NumberFormat('#,##,##0.00');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        horizontalMargin: 14,
        headingRowHeight: 40,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 52,
        headingRowColor: WidgetStateProperty.all(
          const Color(0xFF450095).withValues(alpha: 0.06),
        ),
        border: TableBorder(
          horizontalInside: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
        columns: [
          _col('#'),
          _col('Product Name'),
          _col('Packing'),
          _colNum('Opening Qty'),
          _colNum('Receipts Qty'),
          _colNum('Sales Qty'),
          _colNum('Sales Value'),
          _colNum('Closing Qty'),
          _colNum('Closing Value'),
          _colNum('Hist May'),
          _colNum('Hist Apr'),
          _colNum('Mapped Qty'),
          _colNum('Remaining Qty'),
          _col('Status'),
          _col('Action'),
        ],
        rows: items.asMap().entries.map((e) {
          final i    = e.key;
          final item = e.value;
          final rowColor = i.isEven ? Colors.white : Colors.grey.shade50;

          return DataRow(
            color: WidgetStateProperty.all(rowColor),
            cells: [
              DataCell(Text('${i + 1}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
              DataCell(SizedBox(
                width: 160,
                child: Text(item.productName,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
              )),
              DataCell(Text(item.packing,
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text(fmt.format(item.openingQty),
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text(fmt.format(item.receiptsQty),
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text(fmt.format(item.salesQty),
                  style: const TextStyle(fontSize: 11))),
              DataCell(_ValueCell(
                value: item.salesValue,
                formatted: '₹${fmtVal.format(item.salesValue)}',
              )),
              DataCell(Text(fmt.format(item.closingQty),
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text('₹${fmtVal.format(item.closingValue)}',
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text(fmt.format(item.histMay),
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text(fmt.format(item.histApr),
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text(fmt.format(item.mappedQty),
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text(fmt.format(item.remainingQty),
                  style: const TextStyle(fontSize: 11))),
              DataCell(_StatusChip(status: item.mappingStatus)),
              DataCell(_MapButton(
                item: item,
                podId: podId,
              )),
            ],
          );
        }).toList(),
      ),
    );
  }

  DataColumn _col(String label) => DataColumn(
        label: Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87)),
      );

  DataColumn _colNum(String label) => DataColumn(
        numeric: true,
        label: Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87)),
      );
}

class _ValueCell extends StatelessWidget {
  final double value;
  final String formatted;
  const _ValueCell({required this.value, required this.formatted});

  @override
  Widget build(BuildContext context) {
    return Text(
      formatted,
      style: TextStyle(
          fontSize: 11,
          fontWeight: value > 0 ? FontWeight.w600 : FontWeight.normal,
          color: value == 0 ? Colors.red.shade400 : Colors.black87),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status.toLowerCase()) {
      case 'mapped':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        label = 'Mapped';
        break;
      case 'partial':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = 'Partial';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _MapButton extends StatelessWidget {
  final StatementItem item;
  final int podId;
  const _MapButton({required this.item, required this.podId});

  @override
  Widget build(BuildContext context) {
    if (item.mappingStatus == 'mapped') {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF2E7D32)),
        const SizedBox(width: 4),
        const Text('Done',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
      ]);
    }
    return SizedBox(
      height: 28,
      child: TextButton(
        onPressed: () => _openSheet(context),
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF450095),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('Map Doctors', style: TextStyle(fontSize: 10)),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MapSheet(item: item, podId: podId),
    );
  }
}

// ─────────────────────────────────────────────
// Map Doctors bottom sheet
// ─────────────────────────────────────────────

class _MapSheet extends StatelessWidget {
  final StatementItem item;
  final int podId;
  const _MapSheet({required this.item, required this.podId});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF450095).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded,
                    color: Color(0xFF450095), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Map Doctors',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                  Text(item.productName,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            _InfoRow(label: 'Packing', value: item.packing),
            _InfoRow(
                label: 'Sales Qty',
                value: item.salesQty.toStringAsFixed(2)),
            _InfoRow(
                label: 'Remaining Qty',
                value: item.remainingQty.toStringAsFixed(2),
                highlight: true),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFCC80)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFE65100), size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Doctor mapping will be enabled once the backend map-doctors API is deployed by your backend engineer.',
                    style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _InfoRow({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: highlight ? const Color(0xFFE65100) : Colors.black87)),
      ]),
    );
  }
}
