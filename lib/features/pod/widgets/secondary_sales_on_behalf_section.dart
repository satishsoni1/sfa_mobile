import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/models/secondary_sales_upload_on_behalf_models.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/services/secondary_sales_upload_on_behalf_service.dart';

/// "Upload On Behalf Of" employee selector + dependent stockist list.
///
/// Stockists for a selected employee come from Laravel
/// `GET .../upload/team-members/{employee}/stockists`.
class SecondarySalesOnBehalfSection extends StatefulWidget {
  const SecondarySalesOnBehalfSection({
    super.key,
    required this.selectedEmployee,
    required this.selectedStockist,
    required this.onEmployeeChanged,
    required this.onStockistChanged,
    this.service,
    this.enabled = true,
  });

  final SecondarySalesUploadTeamMember? selectedEmployee;
  final SecondarySalesStockistInfo? selectedStockist;
  final ValueChanged<SecondarySalesUploadTeamMember?> onEmployeeChanged;
  final ValueChanged<SecondarySalesStockistInfo?> onStockistChanged;
  final SecondarySalesUploadOnBehalfService? service;
  final bool enabled;

  @override
  State<SecondarySalesOnBehalfSection> createState() =>
      _SecondarySalesOnBehalfSectionState();
}

class _SecondarySalesOnBehalfSectionState
    extends State<SecondarySalesOnBehalfSection> {
  late final SecondarySalesUploadOnBehalfService _service;
  List<SecondarySalesUploadTeamMember> _members = const [];
  List<SecondarySalesStockistInfo> _stockists = const [];
  bool _loadingMembers = true;
  bool _loadingStockists = false;
  String? _membersError;
  String? _stockistsError;
  bool _onBehalfUnavailable = false;
  /// Prevents overlapping Retry / init loads.
  bool _membersRequestInFlight = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SecondarySalesUploadOnBehalfService();
    // ignore: avoid_print
    print('[SS_ON_BEHALF_TRACE] UI initState — start loading team members');
    debugPrint('[SS_ON_BEHALF_TRACE] UI initState — start loading team members');
    _loadTeamMembers();
  }

  @override
  void didUpdateWidget(covariant SecondarySalesOnBehalfSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.selectedEmployee?.id;
    final newId = widget.selectedEmployee?.id;
    if (oldId != newId && newId != null) {
      _loadStockistsFor(newId);
    }
    if (newId == null && oldId != null) {
      setState(() {
        _stockists = const [];
        _stockistsError = null;
        _loadingStockists = false;
      });
    }
  }

  Future<void> _loadTeamMembers() async {
    if (_membersRequestInFlight) {
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] UI skip load — request already in flight');
      return;
    }
    _membersRequestInFlight = true;
    // ignore: avoid_print
    print('[SS_ON_BEHALF_TRACE] UI state loading');
    setState(() {
      _loadingMembers = true;
      _membersError = null;
      _onBehalfUnavailable = false;
    });
    try {
      final members = await _service.fetchTeamMembers();
      // ignore: avoid_print
      print(
        '[SS_ON_BEHALF_TRACE] UI received members count=${members.length} '
        'mounted=$mounted',
      );
      if (!mounted) {
        // ignore: avoid_print
        print('[SS_ON_BEHALF_TRACE] UI abort setState — not mounted');
        return;
      }
      setState(() {
        _members = members;
        _loadingMembers = false;
        // Empty list is not an error — leaf / no on-behalf permission.
        _onBehalfUnavailable = members.isEmpty;
        _membersError = null;
      });
      // ignore: avoid_print
      print(
        '[SS_ON_BEHALF_TRACE] setState/team-members update '
        'count=${members.length} canUploadOnBehalf=${members.isNotEmpty} '
        'loading=false error=null unavailable=${members.isEmpty}',
      );
    } on UnauthorizedException catch (e, st) {
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] EXCEPTION');
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] type=UnauthorizedException');
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] message=$e');
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] stack=$st');
      if (!mounted) return;
      setState(() {
        _loadingMembers = false;
        // Diagnostic: do not hide the real exception.
        _membersError = 'Team members failed: UnauthorizedException: $e';
      });
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] UI state error message=$_membersError');
    } on SecondarySalesUploadOnBehalfException catch (e, st) {
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] EXCEPTION');
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] type=SecondarySalesUploadOnBehalfException');
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] message=${e.message}');
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] statusCode=${e.statusCode}');
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] stack=$st');
      if (!mounted) return;
      setState(() {
        _loadingMembers = false;
        if (e.isForbidden) {
          _onBehalfUnavailable = true;
          _members = const [];
          _membersError = null;
          // ignore: avoid_print
          print('[SS_ON_BEHALF_TRACE] UI state forbidden/unavailable');
        } else {
          // Diagnostic: show the real exception in the UI.
          _membersError =
              'Team members failed: ${e.message} (status=${e.statusCode})';
          // ignore: avoid_print
          print('[SS_ON_BEHALF_TRACE] UI state error message=$_membersError');
        }
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] EXCEPTION');
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] type=${e.runtimeType}');
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] message=$e');
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] stack=$st');
      if (!mounted) return;
      setState(() {
        _loadingMembers = false;
        // Diagnostic: do not hide behind the generic message.
        _membersError = 'Team members failed: ${e.runtimeType}: $e';
      });
      // ignore: avoid_print
      print('[SS_ON_BEHALF_TRACE] UI state error message=$_membersError');
    } finally {
      _membersRequestInFlight = false;
    }
  }

  Future<void> _loadStockistsFor(int employeeId) async {
    setState(() {
      _loadingStockists = true;
      _stockistsError = null;
      _stockists = const [];
    });
    try {
      final stockists =
          await _service.fetchStockistsForEmployee(employeeId);
      if (!mounted) return;
      setState(() {
        _stockists = stockists;
        _loadingStockists = false;
      });
    } on SecondarySalesUploadOnBehalfException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStockists = false;
        _stockistsError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingStockists = false;
        _stockistsError =
            'Unable to load stockists for this employee. Please try again.';
      });
    }
  }

  Future<void> _openEmployeeSheet() async {
    if (!widget.enabled || _loadingMembers || _onBehalfUnavailable) return;
    if (_members.isEmpty) return;

    final selected = await showModalBottomSheet<SecondarySalesUploadTeamMember>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _EmployeeSearchSheet(
        members: _members,
        selectedId: widget.selectedEmployee?.id,
      ),
    );
    if (selected == null || !mounted) return;
    if (selected.id == widget.selectedEmployee?.id) return;
    debugPrint('[SS_ON_BEHALF] selected employee_id=${selected.id}');
    widget.onEmployeeChanged(selected);
  }

  void _clearEmployee() {
    widget.onEmployeeChanged(null);
  }

  Future<void> _openStockistSheet() async {
    if (!widget.enabled ||
        widget.selectedEmployee == null ||
        _loadingStockists) {
      return;
    }
    if (_stockists.isEmpty) return;

    final selected = await showModalBottomSheet<SecondarySalesStockistInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _OnBehalfStockistSearchSheet(
        stockists: _stockists,
        selectedId: widget.selectedStockist?.id,
      ),
    );
    if (selected == null || !mounted) return;
    widget.onStockistChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMembers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'Loading team members…',
              style: TextStyle(fontSize: 13, color: Color(0xFF5D6570)),
            ),
          ],
        ),
      );
    }

    if (_membersError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _membersError!,
            style: TextStyle(fontSize: 13, color: Colors.red.shade700),
          ),
          TextButton(
            onPressed: _loadTeamMembers,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_onBehalfUnavailable) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6E8EE)),
        ),
        child: Text(
          'Upload on behalf is not available for your account.',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5D6570),
          ),
        ),
      );
    }

    final employee = widget.selectedEmployee;
    final stockist = widget.selectedStockist;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Upload On Behalf Of',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        _SelectorTile(
          label: employee?.displayLabel ?? 'Select Team Member',
          subtitle: employee?.subtitle,
          enabled: widget.enabled,
          onTap: _openEmployeeSheet,
          onClear: employee == null ? null : _clearEmployee,
        ),
        if (employee != null) ...[
          const SizedBox(height: 14),
          const Text(
            'Stockist',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          if (_loadingStockists)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Loading stockists…',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5D6570)),
                  ),
                ],
              ),
            )
          else if (_stockistsError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stockistsError!,
                  style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                ),
                TextButton(
                  onPressed: () => _loadStockistsFor(employee.id),
                  child: const Text('Retry'),
                ),
              ],
            )
          else if (_stockists.isEmpty)
            Text(
              'No stockists available for this employee.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            )
          else ...[
            _SelectorTile(
              label: stockist?.name ?? 'Select Stockist',
              subtitle: stockist == null
                  ? 'Search stockist…'
                  : [
                      if (stockist.id != null) 'ID: ${stockist.id}',
                      if ((stockist.code ?? '').trim().isNotEmpty)
                        stockist.code!.trim(),
                      if (stockist.displayAddress != null)
                        stockist.displayAddress!,
                    ].join(' · '),
              enabled: widget.enabled,
              onTap: _openStockistSheet,
              onClear: stockist == null
                  ? null
                  : () => widget.onStockistChanged(null),
            ),
            if (stockist != null) ...[
              const SizedBox(height: 10),
              _SelectedStockistSummary(stockist: stockist),
            ],
          ],
        ],
      ],
    );
  }
}

class _SelectorTile extends StatelessWidget {
  const _SelectorTile({
    required this.label,
    required this.onTap,
    this.subtitle,
    this.onClear,
    this.enabled = true,
  });

  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE6E8EE)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? const Color(0xFF2C3E50)
                            : Colors.grey.shade500,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: enabled ? onClear : null,
                  icon: Icon(Icons.close_rounded, color: Colors.red.shade600),
                )
              else
                Icon(Icons.expand_more_rounded, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedStockistSummary extends StatelessWidget {
  const _SelectedStockistSummary({required this.stockist});
  final SecondarySalesStockistInfo stockist;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4ECFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF450095).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected Stockist',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF450095),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stockist.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C3E50),
            ),
          ),
          if (stockist.id != null)
            Text(
              'ID: ${stockist.id}'
              '${(stockist.code ?? '').trim().isNotEmpty ? ' · ${stockist.code}' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          if (stockist.displayAddress != null) ...[
            const SizedBox(height: 2),
            Text(
              stockist.displayAddress!,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmployeeSearchSheet extends StatefulWidget {
  const _EmployeeSearchSheet({
    required this.members,
    this.selectedId,
  });

  final List<SecondarySalesUploadTeamMember> members;
  final int? selectedId;

  @override
  State<_EmployeeSearchSheet> createState() => _EmployeeSearchSheetState();
}

class _EmployeeSearchSheetState extends State<_EmployeeSearchSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.members
        : widget.members.where((m) {
            return m.displayLabel.toLowerCase().contains(q) ||
                m.name.toLowerCase().contains(q) ||
                (m.code ?? '').toLowerCase().contains(q) ||
                m.id.toString().contains(q) ||
                (m.designation ?? '').toLowerCase().contains(q) ||
                (m.teamName ?? '').toLowerCase().contains(q) ||
                (m.teamCode ?? '').toLowerCase().contains(q);
          }).toList();

    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Search team member',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Name, ID, or designation',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF7F8FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE6E8EE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE6E8EE)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No team members found'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final m = filtered[index];
                        final selected = m.id == widget.selectedId;
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFF450095)
                                  : const Color(0xFFE6E8EE),
                            ),
                          ),
                          tileColor:
                              selected ? const Color(0xFFF4ECFF) : Colors.white,
                          title: Text(
                            m.displayLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(m.subtitle),
                          trailing: selected
                              ? const Icon(Icons.check_circle,
                                  color: Color(0xFF450095))
                              : null,
                          onTap: () => Navigator.pop(context, m),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnBehalfStockistSearchSheet extends StatefulWidget {
  const _OnBehalfStockistSearchSheet({
    required this.stockists,
    this.selectedId,
  });

  final List<SecondarySalesStockistInfo> stockists;
  final int? selectedId;

  @override
  State<_OnBehalfStockistSearchSheet> createState() =>
      _OnBehalfStockistSearchSheetState();
}

class _OnBehalfStockistSearchSheetState
    extends State<_OnBehalfStockistSearchSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.stockists
        : widget.stockists.where((s) {
            return s.name.toLowerCase().contains(q) ||
                (s.id?.toString().contains(q) ?? false) ||
                (s.code ?? '').toLowerCase().contains(q) ||
                (s.displayAddress ?? '').toLowerCase().contains(q);
          }).toList();

    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Search stockist',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search stockist…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF7F8FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE6E8EE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE6E8EE)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No stockists found'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final s = filtered[index];
                        final selected = s.id == widget.selectedId;
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFF450095)
                                  : const Color(0xFFE6E8EE),
                            ),
                          ),
                          tileColor:
                              selected ? const Color(0xFFF4ECFF) : Colors.white,
                          title: Text(
                            s.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              if (s.id != null) 'ID: ${s.id}',
                              if ((s.code ?? '').trim().isNotEmpty) s.code!,
                              if (s.displayAddress != null) s.displayAddress!,
                            ].join('\n'),
                          ),
                          isThreeLine: s.displayAddress != null,
                          trailing: selected
                              ? const Icon(Icons.check_circle,
                                  color: Color(0xFF450095))
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.pop(context, s),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
