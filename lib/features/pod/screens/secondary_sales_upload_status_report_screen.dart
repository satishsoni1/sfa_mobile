import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:zforce/features/pod/bloc/secondary_sales_upload_status_cubit.dart';
import 'package:zforce/features/pod/models/secondary_sales_upload_status_models.dart';
import 'package:zforce/features/pod/screens/secondary_sales_kam_stockists_screen.dart';
import 'package:zforce/features/pod/services/secondary_sales_upload_status_service.dart';

/// Hierarchy-aware Secondary Sales Upload Status Report.
class SecondarySalesUploadStatusReportScreen extends StatelessWidget {
  const SecondarySalesUploadStatusReportScreen({
    super.key,
    this.cubit,
  });

  /// Optional injected cubit for tests; production leaves this null.
  final SecondarySalesUploadStatusCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final injected = cubit;
    if (injected != null) {
      return BlocProvider.value(
        value: injected,
        child: const _UploadStatusReportView(),
      );
    }
    return BlocProvider(
      create: (_) => SecondarySalesUploadStatusCubit()..initialize(),
      child: const _UploadStatusReportView(),
    );
  }
}

class _UploadStatusReportView extends StatefulWidget {
  const _UploadStatusReportView();

  @override
  State<_UploadStatusReportView> createState() =>
      _UploadStatusReportViewState();
}

class _UploadStatusReportViewState extends State<_UploadStatusReportView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _emptyMessage(SecondarySalesUploadStatusState state) {
    final q = state.searchQuery.trim();
    if (q.isNotEmpty) {
      return 'No results found for "$q"';
    }
    return 'No results found';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Upload Status Report',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                context.read<SecondarySalesUploadStatusCubit>().loadReport(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: BlocConsumer<SecondarySalesUploadStatusCubit,
          SecondarySalesUploadStatusState>(
        listenWhen: (p, c) =>
            p.searchEpoch != c.searchEpoch ||
            p.stockistSummary != c.stockistSummary ||
            (p.errorMessage != c.errorMessage &&
                c.errorMessage != null &&
                c.stockistSummary == null &&
                !c.isLoadingReport),
        listener: (context, state) {
          if (_searchController.text != state.searchQuery) {
            _searchController.value = TextEditingValue(
              text: state.searchQuery,
              selection: TextSelection.collapsed(
                offset: state.searchQuery.length,
              ),
            );
          }
          final summary = state.stockistSummary;
          if (summary != null) {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => _StockistSummarySheet(summary: summary),
            ).whenComplete(() {
              if (context.mounted) {
                context
                    .read<SecondarySalesUploadStatusCubit>()
                    .clearStockistSummary();
              }
            });
          }
        },
        builder: (context, state) {
          final showInitialLoader =
              state.isLoadingReport && state.report == null;
          final showResultsLoader =
              state.isLoadingReport && state.report != null;
          return RefreshIndicator(
            color: const Color(0xFF450095),
            onRefresh: () =>
                context.read<SecondarySalesUploadStatusCubit>().loadReport(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
              children: [
                SecondarySalesMonthBar(
                  selectedMonth: state.month,
                  onMonthChanged: (m) => context
                      .read<SecondarySalesUploadStatusCubit>()
                      .selectMonth(m),
                ),
                const SizedBox(height: 12),
                _FiltersCard(state: state),
                const SizedBox(height: 12),
                _LevelSelector(state: state),
                const SizedBox(height: 12),
                _SearchField(
                  controller: _searchController,
                  level: state.level,
                  onChanged: (v) => context
                      .read<SecondarySalesUploadStatusCubit>()
                      .onSearchChanged(v),
                  onClear: () => context
                      .read<SecondarySalesUploadStatusCubit>()
                      .clearSearch(),
                ),
                const SizedBox(height: 12),
                if (state.errorMessage != null)
                  _Banner(
                    message: state.errorMessage!,
                    color: Colors.red.shade50,
                    border: Colors.red.shade200,
                    textColor: Colors.red.shade800,
                  ),
                if (state.filterErrorMessage != null) ...[
                  const SizedBox(height: 8),
                  _Banner(
                    message: state.filterErrorMessage!,
                    color: Colors.orange.shade50,
                    border: Colors.orange.shade200,
                    textColor: Colors.orange.shade900,
                  ),
                ],
                const SizedBox(height: 12),
                if (showInitialLoader)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF450095),
                      ),
                    ),
                  )
                else ...[
                  _SummaryCards(summary: state.report?.summary),
                  const SizedBox(height: 12),
                  if (showResultsLoader)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: Color(0xFF450095),
                        backgroundColor: Color(0xFFE8DEF8),
                      ),
                    ),
                  if (state.rows.isEmpty && !showResultsLoader)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE6E8EE)),
                      ),
                      child: Text(
                        _emptyMessage(state),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  else if (state.rows.isNotEmpty)
                    ...state.rows.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RowCard(
                          row: row,
                          onTap: () {
                            final stockistId = row.stockistId ?? row.id;
                            if (stockistId == null) return;
                            if (state.level == 'customer' ||
                                row.stockistId != null ||
                                (row.levelLabel ?? '')
                                    .toLowerCase()
                                    .contains('stockist') ||
                                (row.levelLabel ?? '')
                                    .toLowerCase()
                                    .contains('customer')) {
                              context
                                  .read<SecondarySalesUploadStatusCubit>()
                                  .openStockistSummary(stockistId);
                            }
                          },
                        ),
                      ),
                    ),
                  if (state.hasMore) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: state.isLoadingMore
                            ? null
                            : () => context
                                .read<SecondarySalesUploadStatusCubit>()
                                .loadMore(),
                        child: state.isLoadingMore
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Load More'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.level,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String level;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hint = secondarySalesUploadStatusSearchHint(level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EE)),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE6E8EE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF450095)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({required this.state});
  final SecondarySalesUploadStatusState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SecondarySalesUploadStatusCubit>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filters',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              if (state.isLoadingFilters) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (state.divisions.isNotEmpty)
            _FilterDropdown(
              label: 'Division',
              options: state.divisions,
              selected: state.selectedDivision,
              onChanged: cubit.selectDivision,
            ),
          if (state.zms.isNotEmpty)
            _FilterDropdown(
              label: 'ZM',
              options: state.zms,
              selected: state.selectedZm,
              onChanged: cubit.selectZm,
            ),
          if (state.sms.isNotEmpty)
            _FilterDropdown(
              label: 'SM',
              options: state.sms,
              selected: state.selectedSm,
              onChanged: cubit.selectSm,
            ),
          if (state.nsms.isNotEmpty)
            _FilterDropdown(
              label: 'NSM',
              options: state.nsms,
              selected: state.selectedNsm,
              onChanged: cubit.selectNsm,
            ),
          if (state.states.isNotEmpty)
            _FilterDropdown(
              label: 'State',
              options: state.states,
              selected: state.selectedState,
              onChanged: cubit.selectState,
            ),
          if (state.teams.isNotEmpty)
            _FilterDropdown(
              label: 'Team',
              options: state.teams,
              selected: state.selectedTeam,
              onChanged: cubit.selectTeam,
            ),
          if (state.employees.isNotEmpty)
            _FilterDropdown(
              label: 'Employee',
              options: state.employees,
              selected: state.selectedEmployee,
              onChanged: cubit.selectEmployee,
            ),
          if (state.stockists.isNotEmpty)
            _FilterDropdown(
              label: 'Stockist',
              options: state.stockists,
              selected: state.selectedStockist,
              onChanged: cubit.selectStockist,
            ),
          if (state.divisions.isEmpty &&
              state.zms.isEmpty &&
              state.sms.isEmpty &&
              state.nsms.isEmpty &&
              state.states.isEmpty &&
              state.teams.isEmpty &&
              state.employees.isEmpty &&
              state.stockists.isEmpty &&
              !state.isLoadingFilters)
            Text(
              'No hierarchy filters available for your account. '
              'Month and level still apply.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<SecondarySalesUploadStatusFilterOption> options;
  final SecondarySalesUploadStatusFilterOption? selected;
  final ValueChanged<SecondarySalesUploadStatusFilterOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<int?>(
        value: selected?.id,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('All'),
          ),
          ...options.map(
            (o) => DropdownMenuItem<int?>(
              value: o.id,
              child: Text(
                o.code == null || o.code!.isEmpty
                    ? o.label
                    : '${o.label} (${o.code})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: (id) {
          if (id == null) {
            onChanged(null);
            return;
          }
          final match = options.where((o) => o.id == id);
          onChanged(match.isEmpty ? null : match.first);
        },
      ),
    );
  }
}

class _LevelSelector extends StatelessWidget {
  const _LevelSelector({required this.state});
  final SecondarySalesUploadStatusState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EE)),
      ),
      child: DropdownButtonFormField<String>(
        value: state.level,
        decoration: InputDecoration(
          labelText: 'Report Level',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: kSecondarySalesUploadStatusLevels
            .map(
              (e) => DropdownMenuItem<String>(
                value: e.key,
                child: Text(e.value),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          context.read<SecondarySalesUploadStatusCubit>().selectLevel(v);
        },
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});
  final SecondarySalesUploadStatusSummary? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary ?? const SecondarySalesUploadStatusSummary();
    final nf = NumberFormat('#,##0');
    final pf = NumberFormat('#,##0.##');
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Total Customer',
                value: nf.format(s.totalCustomer ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'Data Uploaded',
                value: nf.format(s.dataUploaded ?? 0),
                accent: const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Data Not Uploaded',
                value: nf.format(s.dataNotUploaded ?? 0),
                accent: const Color(0xFFE65100),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'Uploaded %',
                value: '${pf.format(s.dataUploadedPercentage ?? 0)}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MetricCard(
          label: 'Not Uploaded %',
          value: '${pf.format(s.dataNotUploadedPercentage ?? 0)}%',
          accent: const Color(0xFFC62828),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent ?? const Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row, required this.onTap});
  final SecondarySalesUploadStatusRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('#,##0');
    final pf = NumberFormat('#,##0.##');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE6E8EE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.displayTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF2C3E50),
                ),
              ),
              if ((row.levelLabel ?? '').isNotEmpty ||
                  (row.code ?? '').isNotEmpty)
                Text(
                  [
                    if ((row.levelLabel ?? '').isNotEmpty) row.levelLabel,
                    if ((row.code ?? '').isNotEmpty) row.code,
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  _mini('Total', nf.format(row.totalCustomer ?? 0)),
                  _mini('Uploaded', nf.format(row.dataUploaded ?? 0)),
                  _mini('Not Uploaded', nf.format(row.dataNotUploaded ?? 0)),
                  _mini(
                    'Uploaded %',
                    '${pf.format(row.uploadedPercentage ?? 0)}%',
                  ),
                  _mini(
                    'Not %',
                    '${pf.format(row.notUploadedPercentage ?? 0)}%',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Text(
      '$label: $value',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
  }
}

class _StockistSummarySheet extends StatelessWidget {
  const _StockistSummarySheet({required this.summary});
  final SecondarySalesUploadStatusStockistSummary summary;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    String money(double? v) => v == null ? '—' : currency.format(v);
    String qty(double? v) {
      if (v == null) return '—';
      if (v == v.roundToDouble()) return v.toInt().toString();
      return v.toStringAsFixed(2);
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            summary.stockistName ?? 'Stockist Summary',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C3E50),
            ),
          ),
          Text(
            'Month: ${summary.month ?? '—'}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          _kv('Opening', money(summary.openingValue), qty(summary.openingQty)),
          _kv('Receipt / Purchase', money(summary.receiptValue),
              qty(summary.receiptQty)),
          _kv('Sales', money(summary.salesValue), qty(summary.salesQty)),
          _kv('Closing', money(summary.closingValue), qty(summary.closingQty)),
          const SizedBox(height: 8),
          Text(
            'Values use Product Master PTR from Laravel.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, String qty) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Text('Qty $qty', style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.color,
    required this.border,
    required this.textColor,
  });

  final String message;
  final Color color;
  final Color border;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(message, style: TextStyle(color: textColor, fontSize: 13)),
    );
  }
}
