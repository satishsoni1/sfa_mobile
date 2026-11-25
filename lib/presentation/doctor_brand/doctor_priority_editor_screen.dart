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
  static const Color _primaryPurple = Color(0xFF4A148C);

  late List<DoctorPriorityItem> _priorities;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Copy existing priorities
    _priorities = widget.doctor.priorities
        .map((p) => DoctorPriorityItem(
              priorityRank: p.priorityRank,
              brandCluster: p.brandCluster,
              brandName: p.brandName,
            ))
        .toList();
    _reindexPriorities();
  }

  void _reindexPriorities() {
    for (int i = 0; i < _priorities.length; i++) {
      _priorities[i].priorityRank = i + 1;
    }
  }

  bool _isBrandAdded(String cluster) {
    final lower = cluster.trim().toLowerCase();
    return _priorities
        .any((p) => p.brandCluster.trim().toLowerCase() == lower);
  }

  bool _isPathfinderBrand(String cluster) {
    final lower = cluster.trim().toLowerCase();
    return widget.doctor.pathfinderBrands
        .any((b) => b.trim().toLowerCase() == lower);
  }

  List<String> get _missingPathfinderBrands {
    final missing = <String>[];
    for (final b in widget.doctor.pathfinderBrands) {
      if (!_isBrandAdded(b)) {
        missing.add(b);
      }
    }
    return missing;
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
        onSelectBrand: (brand) {
          setState(() {
            _priorities.add(
              DoctorPriorityItem(
                priorityRank: _priorities.length + 1,
                brandCluster: brand.brandCluster,
                brandName: brand.brandName,
              ),
            );
            _reindexPriorities();
          });
        },
      ),
    );
  }

  Future<void> _savePriorities() async {
    if (!_hasMinBrands) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Minimum ${widget.minRequiredBrands} brand priorities required (current: ${_priorities.length}).',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (!_hasAllPathfinderBrands) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'All Pathfinder brands must be included. Missing: ${_missingPathfinderBrands.join(", ")}',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = _priorities.map((p) => p.toJson()).toList();
      await ApiService().saveDoctorBrandPriority(widget.doctor.doctorId, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Priorities saved for Dr. ${widget.doctor.doctorName}!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(
          "Doctor Brand Priority",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!widget.isReadOnly)
            TextButton.icon(
              onPressed: _showAddBrandSheet,
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: Text(
                "Add Brand",
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildDoctorHeader(),
          _buildRuleStatusBanner(),
          Expanded(
            child: _priorities.isEmpty
                ? _buildEmptyState()
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _priorities.length,
                    onReorder: _onReorder,
                    itemBuilder: (ctx, index) {
                      final item = _priorities[index];
                      final isPathfinder = _isPathfinderBrand(item.brandCluster);
                      return _buildPriorityTile(
                        key: ValueKey('item_${item.brandCluster}_$index'),
                        item: item,
                        index: index,
                        isPathfinder: isPathfinder,
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomSheet: !widget.isReadOnly ? _buildBottomBar() : null,
    );
  }

  Widget _buildDoctorHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.doctor.pathfinderBrandCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 12, color: Colors.deepOrange),
                      const SizedBox(width: 2),
                      Text(
                        "${widget.doctor.pathfinderBrandCount} PF",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Text(
                  widget.doctor.doctorName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (widget.doctor.approvalStatus != null)
                _buildStatusChip(widget.doctor.approvalStatus!),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                widget.doctor.speciality,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _primaryPurple,
                ),
              ),
              if (widget.doctor.qualification != null && widget.doctor.qualification!.isNotEmpty)
                Text(
                  " • ${widget.doctor.qualification}",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                ),
              if (widget.doctor.visitCategory != null && widget.doctor.visitCategory!.isNotEmpty)
                Text(
                  " • ${widget.doctor.visitCategory}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade700,
                  ),
                ),
            ],
          ),
          if (widget.doctor.routeName != null && widget.doctor.routeName!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.route_outlined, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  widget.doctor.routeName!,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRuleStatusBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _hasMinBrands ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: _hasMinBrands ? Colors.green.shade600 : Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                "Minimum ${widget.minRequiredBrands} brands (Current: ${_priorities.length})",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _hasMinBrands ? Colors.green.shade800 : Colors.orange.shade900,
                ),
              ),
            ],
          ),
          if (widget.doctor.pathfinderBrands.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _hasAllPathfinderBrands ? Icons.check_circle : Icons.warning_amber_rounded,
                  size: 16,
                  color: _hasAllPathfinderBrands ? Colors.green.shade600 : Colors.red.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pathfinder Brands (${widget.doctor.pathfinderBrands.length} required):",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _hasAllPathfinderBrands ? Colors.green.shade800 : Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: widget.doctor.pathfinderBrands.map((b) {
                          final added = _isBrandAdded(b);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: added ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: added ? Colors.green.shade300 : Colors.red.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  added ? Icons.check : Icons.close,
                                  size: 11,
                                  color: added ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  b,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: added ? Colors.green.shade800 : Colors.red.shade800,
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

  Widget _buildPriorityTile({
    required Key key,
    required DoctorPriorityItem item,
    required int index,
    required bool isPathfinder,
  }) {
    return Card(
      key: key,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPathfinder ? Colors.amber.shade300 : Colors.grey.shade200,
          width: isPathfinder ? 1.4 : 1.0,
        ),
      ),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _primaryPurple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _primaryPurple.withOpacity(0.25)),
          ),
          child: Text(
            "P${item.priorityRank}",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: _primaryPurple,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.brandCluster,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (isPathfinder)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 10, color: Colors.amber.shade900),
                    const SizedBox(width: 2),
                    Text(
                      "Pathfinder",
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: item.brandName != null && item.brandName != item.brandCluster
            ? Text(
                item.brandName!,
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
              )
            : null,
        trailing: !widget.isReadOnly
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.red.shade400),
                    tooltip: "Remove",
                    onPressed: () => _removePriority(index),
                  ),
                  const Icon(Icons.drag_handle, color: Colors.grey),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.format_list_numbered, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            "No Brands Prioritized Yet",
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            "Tap '+ Add Brand' above to select P1..P${widget.minRequiredBrands}",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAddBrandSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text("Add First Brand", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _savePriorities,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSave ? _primaryPurple : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      "Save Priorities (${_priorities.length})",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

class _AddBrandSheet extends StatefulWidget {
  final List<BrandPriorityBrand> allBrands;
  final List<String> pathfinderBrands;
  final bool Function(String cluster) isBrandAdded;
  final ValueChanged<BrandPriorityBrand> onSelectBrand;

  const _AddBrandSheet({
    required this.allBrands,
    required this.pathfinderBrands,
    required this.isBrandAdded,
    required this.onSelectBrand,
  });

  @override
  State<_AddBrandSheet> createState() => _AddBrandSheetState();
}

class _AddBrandSheetState extends State<_AddBrandSheet> {
  late List<BrandPriorityBrand> _filtered;
  final TextEditingController _searchCtrl = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Select Brand Cluster",
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: "Search brand name or composition...",
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF4A148C)),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      "No brands found",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, index) {
                      final brand = _filtered[index];
                      final alreadyAdded = widget.isBrandAdded(brand.brandCluster);
                      final isPathfinder = _isPathfinder(brand.brandCluster);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isPathfinder
                                ? Colors.amber.shade300
                                : Colors.grey.shade200,
                          ),
                        ),
                        color: alreadyAdded
                            ? Colors.grey.shade100
                            : isPathfinder
                                ? Colors.amber.shade50.withOpacity(0.4)
                                : Colors.white,
                        child: ListTile(
                          onTap: alreadyAdded
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  widget.onSelectBrand(brand);
                                },
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  brand.brandCluster,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: alreadyAdded ? Colors.grey : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              if (isPathfinder)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star, size: 10, color: Colors.amber.shade900),
                                      const SizedBox(width: 2),
                                      Text(
                                        "Required",
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          subtitle: brand.composition != null && brand.composition!.isNotEmpty
                              ? Text(
                                  brand.composition!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: alreadyAdded
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Added",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.add_circle_outline,
                                  color: Color(0xFF4A148C),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
