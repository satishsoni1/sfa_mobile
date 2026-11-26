import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/doctor_brand_priority_models.dart';
import '../../data/services/api_service.dart';

class DoctorPriorityEditorScreen extends StatefulWidget {
  final MclDoctorPriority doctor;
  final List<BrandPriorityBrand> availableBrands;
  final int minRequiredBrands;
  final bool isReadOnly;

  const DoctorPriorityEditorScreen({
    super.key,
    required this.doctor,
    required this.availableBrands,
    this.minRequiredBrands = 8,
    this.isReadOnly = false,
  });

  @override
  State<DoctorPriorityEditorScreen> createState() =>
      _DoctorPriorityEditorScreenState();
}

class _DoctorPriorityEditorScreenState
    extends State<DoctorPriorityEditorScreen> {
  static const Color _purple = Color(0xFF4A148C);
  static const Color _plum = Color(0xFF6A1B9A);

  late List<DoctorPriorityItem> _priorities;
  late final List<String> _initialClusters;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priorities = widget.doctor.priorities
        .map((p) => DoctorPriorityItem(
              priorityRank: p.priorityRank,
              brandCluster: p.brandCluster,
              brandName: p.brandName,
            ))
        .toList();
    _reindexPriorities();
    _initialClusters = _priorities
        .map((p) => p.brandCluster.trim().toLowerCase())
        .toList();
  }

  bool get _hasUnsavedChanges {
    if (widget.isReadOnly) return false;
    if (_priorities.length != _initialClusters.length) return true;
    for (int i = 0; i < _priorities.length; i++) {
      if (_priorities[i].brandCluster.trim().toLowerCase() !=
          _initialClusters[i]) {
        return true;
      }
    }
    return false;
  }

  String get _cleanDoctorName => widget.doctor.formattedDoctorName.isNotEmpty
      ? widget.doctor.formattedDoctorName
      : widget.doctor.doctorName;

  void _reindexPriorities() {
    for (int i = 0; i < _priorities.length; i++) {
      _priorities[i].priorityRank = i + 1;
    }
  }

  bool _isBrandAdded(String cluster) {
    final lower = cluster.trim().toLowerCase();
    return _priorities.any((p) => p.brandCluster.trim().toLowerCase() == lower);
  }

  bool _isPathfinderBrand(String cluster) {
    final lower = cluster.trim().toLowerCase();
    return widget.doctor.pathfinderBrands
        .any((b) => b.trim().toLowerCase() == lower);
  }

  List<String> get _missingPathfinderBrands {
    return widget.doctor.pathfinderBrands
        .where((b) => !_isBrandAdded(b))
        .toList();
  }

  bool get _hasMinBrands => _priorities.length >= widget.minRequiredBrands;
  bool get _hasAllPathfinderBrands => _missingPathfinderBrands.isEmpty;
  bool get _canSave =>
      !widget.isReadOnly && _hasMinBrands && _hasAllPathfinderBrands;

  void _onReorder(int oldIndex, int newIndex) {
    if (widget.isReadOnly) return;
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _priorities.removeAt(oldIndex);
      _priorities.insert(newIndex, item);
      _reindexPriorities();
    });
  }

  void _removePriority(int index) {
    if (widget.isReadOnly) return;
    setState(() {
      _priorities.removeAt(index);
      _reindexPriorities();
    });
  }

  void _showAddBrandSheet() {
    if (widget.isReadOnly) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddBrandSheet(
        allBrands: widget.availableBrands,
        pathfinderBrands: widget.doctor.pathfinderBrands,
        isBrandAdded: _isBrandAdded,
        currentPriorityCount: _priorities.length,
        onConfirm: (selectedBrands) {
          setState(() {
            for (final brand in selectedBrands) {
              if (!_isBrandAdded(brand.brandCluster)) {
                _priorities.add(DoctorPriorityItem(
                  priorityRank: _priorities.length + 1,
                  brandCluster: brand.brandCluster,
                  brandName: brand.brandName,
                ));
              }
            }
            _reindexPriorities();
          });
        },
      ),
    );
  }

  Future<void> _savePriorities() async {
    if (!_hasMinBrands) {
      _showSnack(
        'Minimum ${widget.minRequiredBrands} brand priorities required (current: ${_priorities.length}).',
        Colors.red.shade700,
      );
      return;
    }

    if (!_hasAllPathfinderBrands) {
      _showSnack(
        'All Pathfinder brands must be included. Missing: ${_missingPathfinderBrands.join(", ")}',
        Colors.red.shade700,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = _priorities.map((p) => p.toJson()).toList();
      await ApiService().saveDoctorBrandPriority(widget.doctor.doctorId, payload);
      if (mounted) {
        _showSnack(
          'Priorities saved for $_cleanDoctorName!',
          Colors.green.shade700,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          e.toString().replaceFirst('Exception: ', ''),
          Colors.red.shade700,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    ));
  }

  Future<bool> _onWillPop() async {
    if (_isSaving) return false;
    if (!_hasUnsavedChanges) return true;

    final primaryBtnStyle = ElevatedButton.styleFrom(
      backgroundColor: _purple,
      foregroundColor: Colors.white,
      elevation: 3,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );

    final decision = await showDialog<_LeaveDecision>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              _canSave ? Icons.save_outlined : Icons.warning_amber_rounded,
              color: _canSave ? _purple : Colors.orange.shade700,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Save Changes?',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _canSave
                  ? 'You have unsaved brand priority changes for $_cleanDoctorName. Do you want to save them before leaving, or discard your changes?'
                  : 'You have unsaved brand priority changes for $_cleanDoctorName (${!_hasMinBrands ? 'minimum ${widget.minRequiredBrands} brands required' : 'missing mandatory Pathfinder brands'}). If you leave now, your changes will be lost.',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 20),
            if (_canSave) ...[
              ElevatedButton(
                style: primaryBtnStyle,
                onPressed: () => Navigator.pop(ctx, _LeaveDecision.save),
                child: Text(
                  'Save Changes',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, _LeaveDecision.discard),
                    child: Text(
                      'Discard',
                      style: GoogleFonts.poppins(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, _LeaveDecision.stay),
                    child: Text(
                      'Stay',
                      style: GoogleFonts.poppins(
                        color: _purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              ElevatedButton(
                style: primaryBtnStyle,
                onPressed: () => Navigator.pop(ctx, _LeaveDecision.stay),
                child: Text(
                  'Keep Editing',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _LeaveDecision.discard),
                child: Text(
                  'Discard Changes',
                  style: GoogleFonts.poppins(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (decision == _LeaveDecision.save) {
      await _savePriorities();
      return false;
    }
    return decision == _LeaveDecision.discard;
  }

  Future<void> _handleCancelPressed() async {
    final shouldPop = await _onWillPop();
    if (shouldPop && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _cleanDoctorName,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.doctor.speciality.isNotEmpty)
                Text(
                  widget.doctor.speciality,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_purple, _plum],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          foregroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 0,
        ),
        body: Column(
          children: [
            // ─── Doctor Meta Strip ────────────────────────────────────────
            _buildMetaStrip(),
            // ─── Rule Progress Banner ─────────────────────────────────────
            _buildRuleBanner(),
            // ─── Priority List ────────────────────────────────────────────
            Expanded(
              child: _priorities.isEmpty && !widget.isReadOnly
                  ? _buildEmptyState()
                  : _buildPriorityList(),
            ),
          ],
        ),
        bottomNavigationBar: !widget.isReadOnly ? _buildBottomBar() : null,
      ),
    );
  }

  // ─── Doctor meta strip (route · qualification · status) ──────────────────

  Widget _buildMetaStrip() {
    final qual = widget.doctor.qualification;
    final route = widget.doctor.routeName;
    final status = widget.doctor.approvalStatus;

    if ((qual == null || qual.isEmpty) &&
        (route == null || route.isEmpty) &&
        status == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (qual != null && qual.isNotEmpty) ...[
            Icon(Icons.school_outlined, size: 13, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(qual,
                style:
                    GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(width: 10),
          ],
          if (route != null && route.isNotEmpty) ...[
            Icon(Icons.route_outlined, size: 13, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Expanded(
              child: Text(route,
                  style:
                      GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis),
            ),
          ] else
            const Spacer(),
          if (status != null) _statusChip(status),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;
    final s = status.toLowerCase();
    if (s == 'approved') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade700;
    } else if (s == 'pending') {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade700;
    } else if (s == 'rejected') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
            fontSize: 9, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.3),
      ),
    );
  }

  // ─── Rule progress banner ─────────────────────────────────────────────────

  Widget _buildRuleBanner() {
    final met = _hasMinBrands && _hasAllPathfinderBrands;
    final progress =
        (_priorities.length / widget.minRequiredBrands).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: met ? Colors.green.shade200 : Colors.orange.shade200,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _hasMinBrands
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 15,
                color: _hasMinBrands
                    ? Colors.green.shade600
                    : Colors.orange.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Min. ${widget.minRequiredBrands} brands required',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _hasMinBrands
                        ? Colors.green.shade800
                        : Colors.orange.shade900,
                  ),
                ),
              ),
              Text(
                '${_priorities.length} / ${widget.minRequiredBrands}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _hasMinBrands
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _hasMinBrands ? Colors.green.shade500 : Colors.orange.shade400,
              ),
            ),
          ),
          if (widget.doctor.pathfinderBrands.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _hasAllPathfinderBrands
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  size: 15,
                  color: _hasAllPathfinderBrands
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mandatory Pathfinder brands:',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _hasAllPathfinderBrands
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: widget.doctor.pathfinderBrands.map((b) {
                          final added = _isBrandAdded(b);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: added
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: added
                                    ? Colors.green.shade300
                                    : Colors.red.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  added ? Icons.check_rounded : Icons.close_rounded,
                                  size: 10,
                                  color: added
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  b,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: added
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Priority reorderable list ────────────────────────────────────────────

  Widget _buildPriorityList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      buildDefaultDragHandles: false,
      itemCount: _priorities.length + (widget.isReadOnly ? 0 : 1),
      onReorder: _onReorder,
      itemBuilder: (ctx, index) {
        // "Add Brands" inline tile always at the bottom
        if (!widget.isReadOnly && index == _priorities.length) {
          return _buildAddBrandTile(key: const ValueKey('__add_brand__'));
        }
        final item = _priorities[index];
        final isPathfinder = _isPathfinderBrand(item.brandCluster);
        return _buildPriorityTile(
          key: ValueKey('p_${item.brandCluster}_$index'),
          item: item,
          index: index,
          isPathfinder: isPathfinder,
        );
      },
    );
  }

  Widget _buildAddBrandTile({required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showAddBrandSheet,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _purple.withOpacity(0.35),
                width: 1.4,
                // dashed effect via multiple borders not natively supported;
                // solid thin border with light purple is clean enough
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: _purple,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  _priorities.isEmpty
                      ? 'Add Brand  (start with P1)'
                      : 'Add Brand  (next: P${_priorities.length + 1})',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _purple,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityTile({
    required Key key,
    required DoctorPriorityItem item,
    required int index,
    required bool isPathfinder,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPathfinder ? Colors.orange.shade300 : Colors.grey.shade200,
          width: isPathfinder ? 1.3 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // ─── P-rank badge ─────────────────────────────────────────
          Container(
            width: 50,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isPathfinder
                  ? Colors.orange.shade50
                  : const Color(0xFFEDE7F6),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
            child: Text(
              'P${item.priorityRank}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isPathfinder ? Colors.deepOrange : _purple,
              ),
            ),
          ),
          // ─── Brand info ───────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.brandCluster,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (isPathfinder) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt_rounded,
                                  size: 11, color: Colors.deepOrange),
                              const SizedBox(width: 2),
                              Text(
                                'PF',
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.brandName != null &&
                      item.brandName!.isNotEmpty &&
                      item.brandName != item.brandCluster) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.brandName!,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // ─── Actions ──────────────────────────────────────────────
          if (!widget.isReadOnly) ...[
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: Colors.red.shade400),
              tooltip: 'Remove',
              onPressed: () => _removePriority(index),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                child: Icon(Icons.drag_handle_rounded,
                    color: Colors.grey.shade400, size: 22),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFFEDE7F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.format_list_numbered_rounded,
                  size: 44, color: _purple),
            ),
            const SizedBox(height: 18),
            Text(
              'No Brands Prioritised Yet',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the button below to select brands.\nMin. ${widget.minRequiredBrands} brands required (P1 – P${widget.minRequiredBrands}+).',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _showAddBrandSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Select Brands',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom save bar ──────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _handleCancelPressed,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (_isSaving || !_canSave) ? null : _savePriorities,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSave ? _purple : Colors.grey.shade400,
                    elevation: _canSave ? 1 : 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded,
                          size: 18, color: Colors.white),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : 'Save Priorities (${_priorities.length})',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Multi-Select Add Brand Bottom Sheet ──────────────────────────────────────

enum _LeaveDecision { save, discard, stay }

class _AddBrandSheet extends StatefulWidget {
  final List<BrandPriorityBrand> allBrands;
  final List<String> pathfinderBrands;
  final bool Function(String cluster) isBrandAdded;
  final int currentPriorityCount;
  final void Function(List<BrandPriorityBrand> selectedBrands) onConfirm;

  const _AddBrandSheet({
    required this.allBrands,
    required this.pathfinderBrands,
    required this.isBrandAdded,
    required this.currentPriorityCount,
    required this.onConfirm,
  });

  @override
  State<_AddBrandSheet> createState() => _AddBrandSheetState();
}

class _AddBrandSheetState extends State<_AddBrandSheet> {
  static const Color _purple = Color(0xFF4A148C);

  late List<BrandPriorityBrand> _filtered;
  final TextEditingController _searchCtrl = TextEditingController();
  // Ordered list to preserve selection sequence → P-rank order
  final List<String> _selectedClusters = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.allBrands;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      final q = query.toLowerCase().trim();
      if (q.isEmpty) {
        _filtered = widget.allBrands;
      } else {
        _filtered = widget.allBrands.where((b) {
          final cluster = b.brandCluster.toLowerCase();
          final name = b.brandName.toLowerCase();
          final comp = (b.composition ?? '').toLowerCase();
          return cluster.contains(q) || name.contains(q) || comp.contains(q);
        }).toList();
      }
    });
  }

  bool _isPathfinder(String cluster) {
    final lower = cluster.trim().toLowerCase();
    return widget.pathfinderBrands.any((b) => b.trim().toLowerCase() == lower);
  }

  void _toggleSelection(String cluster) {
    setState(() {
      if (_selectedClusters.contains(cluster)) {
        _selectedClusters.remove(cluster);
      } else {
        _selectedClusters.add(cluster);
      }
    });
  }

  /// P-rank that this cluster will get when confirmed
  int? _pendingRankFor(String cluster) {
    final idx = _selectedClusters.indexOf(cluster);
    if (idx < 0) return null;
    return widget.currentPriorityCount + idx + 1;
  }

  void _confirmSelection() {
    // Preserve the selection order when handing back to parent
    final selected = _selectedClusters
        .map((c) => widget.allBrands.firstWhere(
              (b) => b.brandCluster == c,
              orElse: () => BrandPriorityBrand(brandCluster: c, brandName: c),
            ))
        .toList();
    Navigator.pop(context);
    widget.onConfirm(selected);
  }

  @override
  Widget build(BuildContext context) {
    final alreadyAddedCount =
        widget.allBrands.where((b) => widget.isBrandAdded(b.brandCluster)).length;
    final availableCount = widget.allBrands.length - alreadyAddedCount;
    final nextRank = widget.currentPriorityCount + 1;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF0F2F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ─── Handle ────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 6),

          // ─── Header ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Brand Clusters',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        _selectedClusters.isNotEmpty
                            ? '${_selectedClusters.length} selected — will be assigned P$nextRank onwards'
                            : '$availableCount brands available · tap to assign P$nextRank, P${nextRank + 1}...',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: _selectedClusters.isNotEmpty
                              ? _purple
                              : Colors.grey.shade500,
                          fontWeight: _selectedClusters.isNotEmpty
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                  color: Colors.grey.shade700,
                ),
              ],
            ),
          ),

          // ─── Search ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                onChanged: _filter,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search brand name or composition...',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade500),
                  prefixIcon:
                      const Icon(Icons.search, color: _purple, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _filter('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF0F2F5),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          // ─── Brand list ────────────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No brands found',
                      style: GoogleFonts.poppins(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, index) {
                      final brand = _filtered[index];
                      final alreadyAdded =
                          widget.isBrandAdded(brand.brandCluster);
                      final isPathfinder = _isPathfinder(brand.brandCluster);
                      final isSelected =
                          _selectedClusters.contains(brand.brandCluster);
                      final pendingRank = _pendingRankFor(brand.brandCluster);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: _buildBrandTile(
                          brand: brand,
                          alreadyAdded: alreadyAdded,
                          isPathfinder: isPathfinder,
                          isSelected: isSelected,
                          pendingRank: pendingRank,
                        ),
                      );
                    },
                  ),
          ),

          // ─── Confirm button ────────────────────────────────────────────
          if (_selectedClusters.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _confirmSelection,
                    icon: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18),
                    label: Text(
                      'Add ${_selectedClusters.length} Brand${_selectedClusters.length > 1 ? "s" : ""} to Priority List',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBrandTile({
    required BrandPriorityBrand brand,
    required bool alreadyAdded,
    required bool isPathfinder,
    required bool isSelected,
    int? pendingRank,
  }) {
    final tileColor = alreadyAdded
        ? Colors.grey.shade50
        : isSelected
            ? const Color(0xFFEDE7F6)
            : Colors.white;

    final borderColor = alreadyAdded
        ? Colors.grey.shade200
        : isSelected
            ? _purple.withOpacity(0.5)
            : isPathfinder
                ? Colors.orange.shade200
                : Colors.grey.shade200;

    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: alreadyAdded ? null : () => _toggleSelection(brand.brandCluster),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // ─── P-rank badge OR checkbox ────────────────────────
              if (isSelected && pendingRank != null)
                // Show P-rank pill when selected
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _purple,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    'P$pendingRank',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                // Checkbox when not selected
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: alreadyAdded
                        ? Colors.grey.shade200
                        : Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: alreadyAdded
                          ? Colors.grey.shade300
                          : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: alreadyAdded
                      ? Icon(Icons.check_rounded,
                          size: 13, color: Colors.grey.shade500)
                      : null,
                ),
              const SizedBox(width: 12),

              // ─── Brand info ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            brand.brandCluster,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: alreadyAdded
                                  ? Colors.grey.shade500
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        if (isPathfinder) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded,
                                    size: 11, color: Colors.deepOrange),
                                const SizedBox(width: 2),
                                Text(
                                  'Required',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (alreadyAdded) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'Added',
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (brand.composition != null &&
                        brand.composition!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        brand.composition!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
