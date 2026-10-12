import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/routes/pod_routes.dart';
import 'package:zforce/features/pod/screens/secondary_sales_kam_stockists_screen.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/services/secondary_sales_background_monitor.dart';
import 'package:zforce/features/pod/services/secondary_sales_dashboard_service.dart';
import 'package:zforce/features/pod/services/secondary_sales_data_refresh.dart';

class SecondarySalesDashboardScreen extends StatefulWidget {
  const SecondarySalesDashboardScreen({
    super.key,
    this.service,
    this.onBackPressed,
  });

  final SecondarySalesDashboardService? service;

  /// When hosted inside [MainNavigation], leave the Secondary Sales module
  /// (confirm + pop root). Do not call rootNavigator.pop() from the AppBar.
  final Future<void> Function()? onBackPressed;

  @override
  State<SecondarySalesDashboardScreen> createState() =>
      _SecondarySalesDashboardScreenState();
}

class _SecondarySalesDashboardScreenState
    extends State<SecondarySalesDashboardScreen> {
  late final SecondarySalesDashboardService _service;
  late DateTime _selectedMonth;
  int _loadToken = 0;
  bool _loading = true;
  Object? _error;
  SecondarySalesDashboardData? _data;
  int _tabIndex = 0;
  final Set<int> _expandedManagerIds = <int>{};

  /// Employee/KAM filter — only IDs from Laravel's available_kams/employees.
  String? _selectedEmployeeId;
  String? _selectedZoneId;

  final TextEditingController _employeeSearch = TextEditingController();
  final TextEditingController _stockistSearch = TextEditingController();
  Timer? _employeeDebounce;
  Timer? _stockistDebounce;
  String _employeeQuery = '';
  String _stockistQuery = '';

  String get _monthKey =>
      '${_selectedMonth.year.toString().padLeft(4, '0')}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    SecondarySalesDataRefresh.tick.addListener(_onDataRefresh);
    _service = widget.service ?? SecondarySalesDashboardService();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    if (isSecondarySalesUpload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SecondarySalesBackgroundMonitor.instance
            .attachMessengerContext(context);
        SecondarySalesBackgroundMonitor.instance.ensureStarted();
      });
    }
    _reload(reset: true);
  }

  @override
  void dispose() {
    SecondarySalesDataRefresh.tick.removeListener(_onDataRefresh);
    _employeeDebounce?.cancel();
    _stockistDebounce?.cancel();
    _employeeSearch.dispose();
    _stockistSearch.dispose();
    super.dispose();
  }

  void _onDataRefresh() {
    if (!mounted) return;
    _reload();
  }

  Future<void> _reload({bool reset = false}) async {
    final token = ++_loadToken;
    final month = _monthKey;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _data = null;
        _expandedManagerIds.clear();
      }
    });
    try {
      final data = await _service.fetchDashboard(
        month: month,
        employeeId: _selectedEmployeeId,
        zoneId: _selectedZoneId,
      );
      if (!mounted || token != _loadToken) return;
      // Drop stale unauthorized filter if Laravel no longer returns it.
      final allowedIds = {
        for (final k in data.filters.availableKams)
          if (k.id != null && !k.unassigned) k.id!,
      };
      if (_selectedEmployeeId != null &&
          allowedIds.isNotEmpty &&
          !allowedIds.contains(_selectedEmployeeId)) {
        _selectedEmployeeId = null;
      }
      setState(() {
        _data = data;
        _loading = false;
        if (!data.showsTeamSection && _tabIndex == 0) {
          _tabIndex = 0; // stockists-only layout uses single pane below
        }
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
    } on SecondarySalesDashboardException catch (e) {
      if (!mounted || token != _loadToken) return;
      if (e.isForbidden) {
        // Clear unauthorized filter and show message; do not keep stale data.
        _selectedEmployeeId = null;
        _selectedZoneId = null;
      }
      setState(() {
        _loading = false;
        _error = e;
        if (e.isForbidden) _data = null;
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _onEmployeeSearch(String value) {
    _employeeDebounce?.cancel();
    _employeeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _employeeQuery = value.trim());
    });
  }

  void _onStockistSearch(String value) {
    _stockistDebounce?.cancel();
    _stockistDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _stockistQuery = value.trim());
    });
  }

  void _toggleExpand(int? employeeId) {
    if (employeeId == null) return;
    setState(() {
      if (!_expandedManagerIds.add(employeeId)) {
        _expandedManagerIds.remove(employeeId);
      }
    });
  }

  Future<void> _openEmployee(SecondarySalesEmployeePerformance row) async {
    if (row.employeeId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SecondarySalesKamStockistsScreen(
          employeeId: row.employeeId!,
          employeeName: row.employeeName,
          designation: row.designation,
          month: _monthKey,
          service: _service,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _handleBack() async {
    if (widget.onBackPressed != null) {
      await widget.onBackPressed!();
      return;
    }
    // Standalone / deep-link fallback: pop one route safely.
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    final root = Navigator.of(context, rootNavigator: true);
    if (root.canPop()) root.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        title: const Text(
          'Secondary Sales',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => _handleBack(),
        ),
        actions: [
          IconButton(
            tooltip: 'Upload Status Report',
            onPressed: () {
              Navigator.pushNamed(context, PodRoutes.uploadStatusReport);
            },
            icon: const Icon(Icons.assessment_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _data == null) {
      return const _DashboardSkeleton();
    }
    if (_error != null && _data == null) {
      return SecondarySalesStatusError(
        error: _error!,
        onRetry: () => _reload(reset: true),
      );
    }

    final data = _data!;
    final hierarchy = data.effectiveHierarchy;
    final showTeam = data.showsTeamSection;
    final tabIndex = showTeam ? _tabIndex : 0;
    final monthLabel = DateFormat('MMM yyyy').format(_selectedMonth);
    final bottomPad = MediaQuery.paddingOf(context).bottom + 88;

    return RefreshIndicator(
      color: const Color(0xFF450095),
      onRefresh: () => _reload(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SecondarySalesMonthBar(
              selectedMonth: _selectedMonth,
              onMonthChanged: (month) {
                setState(() {
                  _selectedMonth = DateTime(month.year, month.month, 1);
                });
                _reload(reset: true);
              },
            ),
            if (hierarchy != null) ...[
              const SizedBox(height: 12),
              _HierarchyHeader(hierarchy: hierarchy),
            ],
            const SizedBox(height: 14),
            _OverviewSection(
              overview: data.overview,
              stockistCount: data.visibleStockists.length,
              title: hierarchy?.sectionTitle ?? 'SUMMARY',
            ),
            if (showTeam && data.filters.availableKams.isNotEmpty) ...[
              const SizedBox(height: 12),
              _EmployeeFilterBar(
                options: data.filters.availableKams,
                selectedId: _selectedEmployeeId,
                onChanged: (id) {
                  setState(() => _selectedEmployeeId = id);
                  _reload(reset: true);
                },
              ),
            ],
            if (showTeam) ...[
              const SizedBox(height: 14),
              _SegmentedTabs(
                index: tabIndex,
                onChanged: (index) => setState(() => _tabIndex = index),
                teamLabel: 'Team',
                stockistLabel: 'Stockists',
              ),
            ],
            const SizedBox(height: 14),
            if (showTeam && tabIndex == 0)
              _TeamPerformanceSection(
                data: data,
                query: _employeeQuery,
                search: _employeeSearch,
                onSearch: _onEmployeeSearch,
                onClearSearch: () {
                  _employeeSearch.clear();
                  setState(() => _employeeQuery = '');
                },
                expandedIds: _expandedManagerIds,
                onToggle: _toggleExpand,
                onOpen: _openEmployee,
                monthLabel: monthLabel,
              )
            else
              _StockistStatementsSection(
                stockists: data.visibleStockists,
                query: _stockistQuery,
                search: _stockistSearch,
                onSearch: _onStockistSearch,
                onClearSearch: () {
                  _stockistSearch.clear();
                  setState(() => _stockistQuery = '');
                },
                month: _monthKey,
                monthLabel: monthLabel,
                service: _service,
                onOpened: _reload,
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.index,
    required this.onChanged,
    this.teamLabel = 'Team',
    this.stockistLabel = 'Stockists',
  });

  final int index;
  final ValueChanged<int> onChanged;
  final String teamLabel;
  final String stockistLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E6F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Keep legacy key; label is hierarchy-neutral ("Team").
          _seg(teamLabel, 0, key: const ValueKey('ss-tab-hierarchy')),
          _seg(stockistLabel, 1, key: const ValueKey('ss-tab-stockists')),
        ],
      ),
    );
  }

  Widget _seg(String label, int value, {Key? key}) {
    final selected = index == value;
    return Expanded(
      child: Material(
        key: key,
        color: selected ? const Color(0xFF450095) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => onChanged(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF5D6570),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HierarchyHeader extends StatelessWidget {
  const _HierarchyHeader({required this.hierarchy});
  final SecondarySalesHierarchy hierarchy;

  @override
  Widget build(BuildContext context) {
    final count = hierarchy.visibleEmployeeCount;
    final level = hierarchy.level?.trim();
    final name = hierarchy.employeeName?.trim();
    final subtitleParts = <String>[
      if (level != null && level.isNotEmpty) level,
      if (name != null && name.isNotEmpty) name,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4ECFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8C4F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hierarchy.headerEyebrow,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: Color(0xFF450095),
            ),
          ),
          if (subtitleParts.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitleParts.join(' • '),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
          if (count != null) ...[
            const SizedBox(height: 2),
            Text(
              '$count Employees',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D6570),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmployeeFilterBar extends StatelessWidget {
  const _EmployeeFilterBar({
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  final List<SecondarySalesKamOption> options;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = options
        .where((o) => o.id != null && !o.unassigned)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String?>(
      value: selectedId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Employee',
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE6E8EE)),
        ),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All visible employees'),
        ),
        for (final o in items)
          DropdownMenuItem<String?>(
            value: o.id,
            child: Text(o.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.overview,
    required this.stockistCount,
    this.title = 'SUMMARY',
  });
  final SecondarySalesOverview overview;
  final int stockistCount;
  final String title;

  @override
  Widget build(BuildContext context) {
    final completion = overview.completionPercentage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Total Sales',
                value: _inr(overview.totalSales),
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                title: 'Statements',
                value: '${overview.statementCount}',
                icon: Icons.description_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Stockists',
                value: '$stockistCount',
                icon: Icons.storefront_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                title: 'Completion',
                value: '${completion.toStringAsFixed(0)}%',
                icon: Icons.task_alt_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF450095)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7B8490),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2A37),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF450095)),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClear,
              ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE6E8EE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE6E8EE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF450095)),
        ),
      ),
    );
  }
}

class _TeamPerformanceSection extends StatelessWidget {
  const _TeamPerformanceSection({
    required this.data,
    required this.query,
    required this.search,
    required this.onSearch,
    required this.onClearSearch,
    required this.expandedIds,
    required this.onToggle,
    required this.onOpen,
    required this.monthLabel,
  });

  final SecondarySalesDashboardData data;
  final String query;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final Set<int> expandedIds;
  final ValueChanged<int?> onToggle;
  final ValueChanged<SecondarySalesEmployeePerformance> onOpen;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final roots = _filterTree(
      SecondarySalesHierarchyTree.fromApi(
        managers: data.managerPerformance,
        kams: data.kamPerformance,
      ),
      query,
    );
    final expanded = query.isEmpty
        ? expandedIds
        : {
            ...expandedIds,
            ..._ancestorIds(roots),
          };
    final visible = SecondarySalesHierarchyTree.flattenVisible(roots, expanded);
    final noTeamRows =
        data.managerPerformance.isEmpty && data.kamPerformance.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Team Performance',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 10),
        _SearchField(
          controller: search,
          hint: 'Search employee',
          onChanged: onSearch,
          onClear: onClearSearch,
        ),
        const SizedBox(height: 12),
        if (noTeamRows)
          _EmptyCopy(
            title: 'No team data available',
            subtitle:
                'No secondary sales data available for $monthLabel.',
          )
        else if (visible.isEmpty)
          const _EmptyCopy(
            title: 'No results found',
            subtitle: 'Try a different employee name.',
          )
        else
          for (final node in visible)
            _HierarchyCard(
              node: node,
              expanded: node.employee.employeeId != null &&
                  expanded.contains(node.employee.employeeId),
              onExpand: () => onToggle(node.employee.employeeId),
              onOpen: () => onOpen(node.employee),
            ),
      ],
    );
  }
}

class _HierarchyCard extends StatelessWidget {
  const _HierarchyCard({
    required this.node,
    required this.expanded,
    required this.onExpand,
    required this.onOpen,
  });

  final SecondarySalesHierarchyNode node;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final row = node.employee;
    final hasChildren = node.children.isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(node.depth * 14.0, 0, 0, 10),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
            border: Border(
              left: BorderSide(
                color: node.depth == 0
                    ? const Color(0xFF450095)
                    : const Color(0xFFB9A7D4),
                width: 3,
              ),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: row.employeeId != null ? onOpen : (hasChildren ? onExpand : null),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 20,
                    color: const Color(0xFF450095).withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.employeeName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF1F2A37),
                          ),
                        ),
                        if (row.designation != null &&
                            row.designation!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            row.designation!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7B8490),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        _MetaLine(
                          label: node.isKam ? 'Sales' : 'Team Sales',
                          value: row.totalSales == null
                              ? '—'
                              : _inr(row.totalSales!),
                        ),
                        _MetaLine(
                          label: 'Statements',
                          value: '${row.totalDocuments ?? 0}',
                        ),
                        if (row.teamSize != null)
                          _MetaLine(label: 'Team Size', value: '${row.teamSize}'),
                        if (row.stockistCount != null)
                          _MetaLine(
                            label: 'Stockists',
                            value: '${row.stockistCount}',
                          ),
                      ],
                    ),
                  ),
                  if (hasChildren)
                    IconButton(
                      key: ValueKey('ss-expand-${row.employeeId}'),
                      onPressed: onExpand,
                      icon: Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: const Color(0xFF450095),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 8, right: 8),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF9AA3AF),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7B8490)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2A37),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockistStatementsSection extends StatelessWidget {
  const _StockistStatementsSection({
    required this.stockists,
    required this.query,
    required this.search,
    required this.onSearch,
    required this.onClearSearch,
    required this.month,
    required this.monthLabel,
    required this.service,
    required this.onOpened,
  });

  final List<SecondarySalesStockistPerformance> stockists;
  final String query;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final String month;
  final String monthLabel;
  final SecondarySalesDashboardService service;
  final VoidCallback onOpened;

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final filtered = q.isEmpty
        ? stockists
        : stockists.where((row) {
            return row.stockistName.toLowerCase().contains(q) ||
                (row.stockistId?.toString().contains(q) ?? false);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Stockist Statements',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 10),
        _SearchField(
          controller: search,
          hint: 'Search stockist name or code',
          onChanged: onSearch,
          onClear: onClearSearch,
        ),
        const SizedBox(height: 12),
        if (stockists.isEmpty)
          _EmptyCopy(
            title: 'No stockist statements available',
            subtitle:
                'No secondary sales data available for $monthLabel.',
          )
        else if (filtered.isEmpty)
          const _EmptyCopy(
            title: 'No results found',
            subtitle: 'Try a different name or stockist code.',
          )
        else
          for (final row in filtered)
            SecondarySalesStockistPerformanceTile(
              row: row,
              month: month,
              service: service,
              onOpened: onOpened,
            ),
      ],
    );
  }
}

class _EmptyCopy extends StatelessWidget {
  const _EmptyCopy({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 42, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box({double h = 72}) => Container(
          height: h,
          decoration: BoxDecoration(
            color: const Color(0xFFE9EBF0),
            borderRadius: BorderRadius.circular(14),
          ),
        );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          box(h: 48),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: box()),
              const SizedBox(width: 10),
              Expanded(child: box()),
            ],
          ),
          const SizedBox(height: 14),
          box(h: 44),
          const SizedBox(height: 14),
          box(h: 96),
          const SizedBox(height: 10),
          box(h: 96),
        ],
      ),
    );
  }
}

List<SecondarySalesHierarchyNode> _filterTree(
  List<SecondarySalesHierarchyNode> nodes,
  String query,
) {
  if (query.isEmpty) return nodes;
  final q = query.toLowerCase();
  final kept = <SecondarySalesHierarchyNode>[];
  for (final node in nodes) {
    final children = _filterTree(node.children, query);
    final matches = node.employee.employeeName.toLowerCase().contains(q) ||
        (node.employee.designation?.toLowerCase().contains(q) ?? false) ||
        (node.employee.employeeId?.toString().contains(q) ?? false);
    if (matches || children.isNotEmpty) {
      kept.add(
        SecondarySalesHierarchyNode(
          employee: node.employee,
          isKam: node.isKam,
          children: children,
        ),
      );
    }
  }
  return kept;
}

Set<int> _ancestorIds(List<SecondarySalesHierarchyNode> nodes) {
  final ids = <int>{};
  void walk(SecondarySalesHierarchyNode node) {
    if (node.children.isNotEmpty && node.employee.employeeId != null) {
      ids.add(node.employee.employeeId!);
    }
    for (final child in node.children) {
      walk(child);
    }
  }

  for (final node in nodes) {
    walk(node);
  }
  return ids;
}

String _inr(double value) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(value);
}
