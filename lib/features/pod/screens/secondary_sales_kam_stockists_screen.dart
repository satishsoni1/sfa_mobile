import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/screens/secondary_sales_stockist_statements_screen.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/services/secondary_sales_dashboard_service.dart';

class SecondarySalesKamStockistsScreen extends StatefulWidget {
  const SecondarySalesKamStockistsScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    this.designation,
    this.service,
  });

  final int employeeId;
  final String employeeName;
  final String month;
  final String? designation;
  final SecondarySalesDashboardService? service;

  @override
  State<SecondarySalesKamStockistsScreen> createState() =>
      _SecondarySalesKamStockistsScreenState();
}

class _SecondarySalesKamStockistsScreenState
    extends State<SecondarySalesKamStockistsScreen> {
  late final SecondarySalesDashboardService _service;
  late String _month;
  int _loadToken = 0;
  bool _loading = true;
  Object? _error;
  SecondarySalesKamStockistsResponse? _data;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SecondarySalesDashboardService();
    _month = widget.month;
    _reload();
  }

  Future<void> _reload() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final data = await _service.fetchKamStockists(
        kamId: widget.employeeId,
        month: _month,
      );
      if (!mounted || token != _loadToken) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on UnauthorizedException {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loading = false;
        _error = const SecondarySalesDashboardException(
          'You are not authorized to view this data.',
          401,
        );
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _onMonthChanged(DateTime month) {
    setState(() {
      _month =
          '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.employeeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.designation?.isNotEmpty == true
                  ? widget.designation!
                  : 'Stockists',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7F8C8D),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SecondarySalesMonthBar(
            selectedMonth: _parseMonth(_month),
            onMonthChanged: _onMonthChanged,
          ),
        ),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF450095)),
        ),
      );
    }
    if (_error != null) {
      return SecondarySalesStatusError(
        error: _error!,
        onRetry: _isForbidden ? null : _reload,
      );
    }
    final stockists = _data?.stockists ?? const [];
    if (stockists.isEmpty) {
      return const SecondarySalesEmptyState(
        text: 'No data available for the selected month.',
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF450095),
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            widget.employeeName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C3E50),
            ),
          ),
          if (_data?.totalSales != null) ...[
            const SizedBox(height: 4),
            Text(
              'Total ${_inr(_data!.totalSales!)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF450095),
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final row in stockists)
            SecondarySalesStockistPerformanceTile(
              row: row,
              month: _month,
              service: _service,
            ),
        ],
      ),
    );
  }

  bool get _isForbidden =>
      _error is SecondarySalesDashboardException &&
      (_error as SecondarySalesDashboardException).isForbidden;
}

class SecondarySalesMonthBar extends StatelessWidget {
  const SecondarySalesMonthBar({
    super.key,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List<DateTime>.generate(
      24,
      (i) => DateTime(now.year, now.month - i, 1),
    );
    final labelFmt = DateFormat('MMM yyyy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded,
              color: Color(0xFF450095), size: 18),
          const SizedBox(width: 10),
          const Text(
            'Month',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _key(selectedMonth),
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              items: [
                for (final m in months)
                  DropdownMenuItem<String>(
                    value: _key(m),
                    child: Text(labelFmt.format(m)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                final parts = value.split('-');
                onMonthChanged(
                  DateTime(int.parse(parts[0]), int.parse(parts[1])),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SecondarySalesStockistPerformanceTile extends StatelessWidget {
  const SecondarySalesStockistPerformanceTile({
    super.key,
    required this.row,
    required this.month,
    this.service,
    this.onOpened,
  });

  final SecondarySalesStockistPerformance row;
  final String month;
  final SecondarySalesDashboardService? service;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    final docs = row.documents;
    final completed = row.completedStatements;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EEF2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.stockistName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'KAM: ${row.kamLabel}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (row.sales != null)
                        Text(
                          'Sales                         ${_inr(row.sales!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      if (docs != null)
                        Text(
                          'Statements                    $docs',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      if (completed != null)
                        Text(
                          'Completed                     $completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'View Statements →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF450095),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    if (row.stockistId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stockist details are not available.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SecondarySalesStockistStatementsScreen(
          stockistId: row.stockistId!,
          stockistName: row.stockistName,
          month: month,
          kamId: row.kamId,
          service: service,
        ),
      ),
    );
    onOpened?.call();
  }
}

class SecondarySalesStatusError extends StatelessWidget {
  const SecondarySalesStatusError({
    super.key,
    required this.error,
    this.onRetry,
  });

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final exception = error is SecondarySalesDashboardException
        ? error as SecondarySalesDashboardException
        : null;
    final forbidden = exception?.isForbidden == true;
    final notFound = exception?.isNotFound == true;
    final message = forbidden
        ? 'You are not authorized to view this data.'
        : notFound
            ? 'This data is no longer available.'
            : (exception?.message ?? 'Unable to load Secondary Sales dashboard');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              forbidden ? Icons.lock_outline : Icons.error_outline,
              size: 48,
              color: forbidden ? const Color(0xFF450095) : Colors.red.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (onRetry != null && !forbidden) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF450095),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SecondarySalesEmptyState extends StatelessWidget {
  const SecondarySalesEmptyState({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
        ),
      ),
    );
  }
}

DateTime _parseMonth(String month) {
  final parts = month.split('-');
  if (parts.length >= 2) {
    final year = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (year != null && m != null) return DateTime(year, m);
  }
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}

String _inr(double value) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(value);
}
