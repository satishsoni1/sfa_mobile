import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/routes/pod_routes.dart';
import 'package:zforce/features/pod/screens/secondary_sales_kam_stockists_screen.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/services/secondary_sales_dashboard_service.dart';

class SecondarySalesStockistStatementsScreen extends StatefulWidget {
  const SecondarySalesStockistStatementsScreen({
    super.key,
    required this.stockistId,
    required this.stockistName,
    required this.month,
    this.kamId,
    this.zoneId,
    this.service,
  });

  final int stockistId;
  final String stockistName;
  final String month;
  final int? kamId;
  final String? zoneId;
  final SecondarySalesDashboardService? service;

  @override
  State<SecondarySalesStockistStatementsScreen> createState() =>
      _SecondarySalesStockistStatementsScreenState();
}

class _SecondarySalesStockistStatementsScreenState
    extends State<SecondarySalesStockistStatementsScreen> {
  late final SecondarySalesDashboardService _service;
  late String _month;
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  final List<SecondarySalesStockistStatement> _statements = [];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasError = false;
  Object? _error;
  int? _nextPage;
  int _loadToken = 0;

  static const int _perPage = 20;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SecondarySalesDashboardService();
    _month = widget.month;
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore || _initialLoading) return;
    if (_nextPage == null) return;
    final pos = _scroll.position;
    if (pos.maxScrollExtent <= 0) return;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _load(reset: false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _load(reset: true);
    });
  }

  Future<void> _load({required bool reset}) async {
    final token = reset ? ++_loadToken : _loadToken;
    if (reset) {
      setState(() {
        _initialLoading = true;
        _hasError = false;
        _error = null;
        _loadingMore = false;
        _nextPage = null;
        _statements.clear();
      });
    } else {
      if (_loadingMore || _nextPage == null) return;
      setState(() => _loadingMore = true);
    }

    final requestPage = reset ? 1 : _nextPage!;
    try {
      final response = await _service.getStockistStatements(
        stockistId: widget.stockistId,
        month: _month,
        page: requestPage,
        perPage: _perPage,
        search: _search.text,
        kamId: widget.kamId,
        zoneId: widget.zoneId,
      );
      if (!mounted || token != _loadToken) return;

      final existing = <String>{
        for (final s in _statements)
          if (s.identity != 'x:x:x') s.identity,
      };
      final incoming = reset
          ? response.statements
          : response.statements.where((s) {
              if (s.identity == 'x:x:x') return true;
              return existing.add(s.identity);
            });

      setState(() {
        if (reset) {
          _statements
            ..clear()
            ..addAll(incoming);
        } else {
          _statements.addAll(incoming);
        }
        _nextPage = response.pagination.nextPage;
        _initialLoading = false;
        _loadingMore = false;
        _hasError = false;
        _error = null;
      });
    } on UnauthorizedException catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _hasError = _statements.isEmpty;
        _error = e;
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _hasError = reset || _statements.isEmpty;
        _error = e;
      });
    }
  }

  String get _monthLabel {
    final parts = _month.split('-');
    if (parts.length >= 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null) {
        return DateFormat('MMMM yyyy').format(DateTime(year, month));
      }
    }
    return widget.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.stockistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C3E50),
              ),
            ),
            const Text(
              'Secondary Sales Statements',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7F8C8D),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _hasError && _statements.isEmpty
            ? SecondarySalesStatusError(
                error: _error ??
                    const SecondarySalesDashboardException(
                      'Unable to load stockist statements.',
                    ),
                onRetry: () => _load(reset: true),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SecondarySalesMonthBar(
                      selectedMonth: _parseMonthKey(_month),
                      onMonthChanged: (month) {
                        setState(() {
                          _month =
                              '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
                        });
                        _load(reset: true);
                      },
                    ),
                  ),
                  _Header(
                    stockistName: widget.stockistName,
                    monthLabel: _monthLabel,
                    search: _search,
                    onSearchChanged: _onSearchChanged,
                  ),
                  Expanded(child: _buildBody()),
                ],
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF450095)),
        ),
      );
    }
    if (_statements.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF450095),
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            Icon(Icons.description_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No data available for the selected month.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No statements found for this stockist in $_monthLabel.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF450095),
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _statements.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _statements.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF450095)),
                  ),
                ),
              ),
            );
          }
          final statement = _statements[index];
          return _StatementCard(
            key: ValueKey(
              'statement-${statement.id}-${statement.documentId}-$index',
            ),
            statement: statement,
            onView: () => openSecondarySalesStatementView(
              context,
              statement,
            ),
          );
        },
      ),
    );
  }
}

void openSecondarySalesStatementView(
  BuildContext context,
  SecondarySalesStockistStatement statement,
) {
  final podId = statement.documentId ?? statement.id;
  if (podId != null) {
    Navigator.pushNamed(
      context,
      PodRoutes.statementDetail,
      arguments: {'podId': podId},
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        statement.isProcessing
            ? 'This statement is still processing.'
            : statement.isPending
                ? 'This statement is still pending.'
                : 'Document details are not available yet.',
      ),
    ),
  );
}

DateTime _parseMonthKey(String month) {
  final parts = month.split('-');
  if (parts.length >= 2) {
    final year = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (year != null && m != null) return DateTime(year, m);
  }
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.stockistName,
    required this.monthLabel,
    required this.search,
    required this.onSearchChanged,
  });

  final String stockistName;
  final String monthLabel;
  final TextEditingController search;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stockistName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Secondary Sales Statements',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF450095),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            monthLabel,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search statement or file name',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE8EEF2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE8EEF2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatementCard extends StatelessWidget {
  const _StatementCard({
    super.key,
    required this.statement,
    required this.onView,
  });

  final SecondarySalesStockistStatement statement;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statement.fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          _StatusBadge(status: statement.displayStatus, raw: statement.normalizedStatus),
          if (statement.statementMonth != null &&
              statement.statementMonth!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _monthTitle(statement.statementMonth!),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
          if (statement.createdAt != null && statement.createdAt!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _formatDate(statement.createdAt!),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          if (statement.isCompleted) ...[
            const SizedBox(height: 6),
            Text(
              _salesLabel(statement.sales),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
          ] else if (statement.sales != null) ...[
            const SizedBox(height: 6),
            Text(
              _salesLabel(statement.sales),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
          if (statement.productCount != null) ...[
            const SizedBox(height: 2),
            Text(
              'Products: ${statement.productCount}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
          if (statement.isFailed &&
              statement.errorMessage != null &&
              statement.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              statement.errorMessage!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade600),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onView,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF450095),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                statement.isProcessing ? 'PROCESSING' : 'VIEW',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.raw});

  final String status;
  final String raw;

  @override
  Widget build(BuildContext context) {
    final color = switch (raw) {
      'completed' => Colors.green,
      'processing' => Colors.orange,
      'failed' => Colors.red,
      'pending' => Colors.blueGrey,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

String _monthTitle(String raw) {
  final parts = raw.split('-');
  if (parts.length >= 2) {
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year != null && month != null) {
      return DateFormat('MMMM yyyy').format(DateTime(year, month));
    }
  }
  return raw;
}

String _salesLabel(double? sales) {
  if (sales == null) return 'Sales —';
  return 'Sales ${_inr(sales)}';
}

String _inr(double value) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(value);
}

String _formatDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
}
