import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/data_bank_models.dart';
import '../../providers/data_bank_provider.dart';
import 'data_bank_viewer_screen.dart';

class DataBankMaterialListScreen extends StatefulWidget {
  final DataBankCategory? category;
  final bool mandatoryOnly;

  const DataBankMaterialListScreen({
    super.key,
    this.category,
    this.mandatoryOnly = false,
  });

  @override
  State<DataBankMaterialListScreen> createState() =>
      _DataBankMaterialListScreenState();
}

class _DataBankMaterialListScreenState
    extends State<DataBankMaterialListScreen> {
  static const _purple = Color(0xFF4A148C);

  DataBankMaterialType? _filterType;
  String _sort = 'date'; // date | title | views | progress

  @override
  Widget build(BuildContext context) {
    final catColor = widget.category?.color ?? Colors.red.shade700;
    final title = widget.mandatoryOnly
        ? 'Mandatory Training'
        : (widget.category?.name ?? 'Materials');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text(title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: widget.mandatoryOnly ? Colors.red.shade700 : catColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            onPressed: _showSortSheet,
          ),
        ],
      ),
      body: Consumer<DataBankProvider>(
        builder: (_, prov, child) {
          final raw = widget.mandatoryOnly
              ? prov.mandatory
              : prov.currentList;

          final filtered = _applyFilter(raw);
          final sorted = _applySort(filtered);

          return Column(children: [
            // Category description + filter chips
            if (widget.category != null)
              _buildCategoryHeader(widget.category!, sorted.length),
            _buildFilterChips(),
            if (widget.mandatoryOnly)
              _buildMandatoryProgress(prov),
            Expanded(
              child: prov.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : sorted.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
                          itemCount: sorted.length,
                          itemBuilder: (_, i) =>
                              _buildMaterialCard(sorted[i], prov, catColor),
                        ),
            ),
          ]);
        },
      ),
    );
  }

  List<DataBankMaterial> _applyFilter(List<DataBankMaterial> list) {
    if (_filterType == null) return list;
    return list.where((m) => m.type == _filterType).toList();
  }

  List<DataBankMaterial> _applySort(List<DataBankMaterial> list) {
    final copy = List<DataBankMaterial>.from(list);
    switch (_sort) {
      case 'title':
        copy.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'views':
        copy.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        break;
      case 'progress':
        copy.sort((a, b) {
          if (a.userCompleted && !b.userCompleted) return 1;
          if (!a.userCompleted && b.userCompleted) return -1;
          return b.userProgressFraction.compareTo(a.userProgressFraction);
        });
        break;
      default:
        copy.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    }
    // Always mandatory first
    final mandatory = copy.where((m) => m.isMandatory).toList();
    final rest = copy.where((m) => !m.isMandatory).toList();
    return [...mandatory, ...rest];
  }

  // ─── Category Header ──────────────────────────────────────────────────────────

  Widget _buildCategoryHeader(DataBankCategory cat, int count) {
    return Container(
      color: cat.color,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cat.description,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20)),
          child: Text('$count items',
              style: const TextStyle(color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  // ─── Mandatory Progress Bar ───────────────────────────────────────────────────

  Widget _buildMandatoryProgress(DataBankProvider prov) {
    final total = prov.mandatory.length;
    if (total == 0) return const SizedBox.shrink();
    final done = prov.mandatory.where((m) => m.userCompleted).length;
    final frac = done / total;
    return Container(
      color: Colors.red.shade700,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$done / $total completed',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          Text('${(frac * 100).round()}%',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ]),
    );
  }

  // ─── Filter Chips ─────────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _filterChip(null, 'All', Icons.apps_rounded),
          const SizedBox(width: 6),
          ...DataBankMaterialType.values.map((t) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _filterChip(t, t.label, t.icon),
              )),
        ]),
      ),
    );
  }

  Widget _filterChip(DataBankMaterialType? type, String label, IconData icon) {
    final selected = _filterType == type;
    final color = type?.color ?? _purple;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: selected ? Colors.white : Colors.grey.shade600),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey.shade700)),
        ]),
      ),
    );
  }

  // ─── Material Card ────────────────────────────────────────────────────────────

  Widget _buildMaterialCard(
      DataBankMaterial m, DataBankProvider prov, Color catColor) {
    final typeColor = m.type.color;
    return GestureDetector(
      onTap: () => _openViewer(m, prov),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: m.isMandatory && !m.userCompleted
              ? Border.all(color: Colors.red.shade300, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8, offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Type icon box
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(m.type.icon, color: typeColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Badges row
                  Row(children: [
                    if (m.isMandatory) ...[
                      _badge('MANDATORY', Colors.red.shade700),
                      const SizedBox(width: 4),
                    ],
                    if (m.isNew) _badge('NEW', Colors.amber.shade700),
                    if (m.isFeatured) ...[
                      if (m.isNew) const SizedBox(width: 4),
                      _badge('FEATURED', catColor),
                    ],
                  ]),
                  if (m.isMandatory || m.isNew || m.isFeatured)
                    const SizedBox(height: 4),
                  Text(m.title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13, color: Colors.black87),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(m.description,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600,
                          height: 1.4),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            // Meta row
            Row(children: [
              Icon(m.type.icon, size: 12, color: typeColor),
              const SizedBox(width: 4),
              Text(m.type.label,
                  style: TextStyle(fontSize: 10, color: typeColor,
                      fontWeight: FontWeight.w600)),
              if (m.fileSizeLabel.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(Icons.insert_drive_file_outlined,
                    size: 11, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text(m.fileSizeLabel,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
              if (m.durationLabel != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.timer_outlined, size: 11, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text(m.durationLabel!,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
              const Spacer(),
              Icon(Icons.visibility_outlined,
                  size: 11, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Text('${m.viewCount}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              const SizedBox(width: 8),
              Text(DateFormat('d MMM').format(m.publishedAt),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ]),
            // Progress bar
            if (m.userDurationSeconds > 0 || m.userCompleted) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: m.userProgressFraction,
                      minHeight: 4,
                      backgroundColor: Colors.grey.shade200,
                      color: m.userCompleted ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                m.userCompleted
                    ? Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 3),
                        Text('Done',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600)),
                      ])
                    : Text(
                        '${(m.userProgressFraction * 100).round()}%',
                        style: TextStyle(
                            fontSize: 10, color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600)),
              ]),
            ],
            // Tags
            if (m.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 5, runSpacing: 4,
                children: m.tags.take(4).map((tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(tag,
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey.shade600)),
                    )).toList(),
              ),
            ],
            // Download row (skip for links — always online)
            if (m.type != DataBankMaterialType.link) ...[
              const SizedBox(height: 10),
              _buildDownloadRow(m, prov),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildDownloadRow(DataBankMaterial m, DataBankProvider prov) {
    final progress = prov.downloadProgress[m.id];
    final isDownloading = progress != null;

    if (isDownloading) {
      return Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress, minHeight: 4,
              backgroundColor: Colors.grey.shade200,
              color: Colors.deepPurple,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(progress * 100).round()}%',
            style: TextStyle(
                fontSize: 10, color: Colors.deepPurple.shade700,
                fontWeight: FontWeight.w600)),
      ]);
    }

    if (m.isDownloaded) {
      return Row(children: [
        const Icon(Icons.offline_pin_rounded, size: 13, color: Colors.green),
        const SizedBox(width: 4),
        Text('Available offline',
            style: TextStyle(
                fontSize: 10, color: Colors.green.shade700,
                fontWeight: FontWeight.w500)),
        const Spacer(),
        GestureDetector(
          onTap: () => prov.deleteDownload(m),
          child: Text('Remove',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ),
      ]);
    }

    return GestureDetector(
      onTap: () => prov.downloadMaterial(m),
      child: Row(children: [
        Icon(Icons.download_outlined, size: 13, color: Colors.deepPurple.shade400),
        const SizedBox(width: 4),
        Text('Download for offline',
            style: TextStyle(
                fontSize: 10, color: Colors.deepPurple.shade400,
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        Text('(${m.fileSizeLabel})',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
      );

  // ─── Empty State ──────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.folder_open_outlined,
            size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No materials found',
            style: TextStyle(
                color: Colors.grey.shade500, fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Check back later or try a different filter',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      ]),
    );
  }

  // ─── Sort Sheet ───────────────────────────────────────────────────────────────

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Wrap(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Sort By',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 15)),
        ),
        ...[
          ('date', 'Newest First', Icons.calendar_today_outlined),
          ('title', 'Title A–Z', Icons.sort_by_alpha_rounded),
          ('views', 'Most Viewed', Icons.visibility_outlined),
          ('progress', 'Progress', Icons.linear_scale_rounded),
        ].map((e) => ListTile(
              leading: Icon(e.$3,
                  color: _sort == e.$1 ? _purple : Colors.grey.shade500),
              title: Text(e.$2,
                  style: TextStyle(
                      fontWeight: _sort == e.$1 ? FontWeight.bold : FontWeight.normal,
                      color: _sort == e.$1 ? _purple : Colors.black87)),
              trailing: _sort == e.$1
                  ? const Icon(Icons.check_rounded, color: Color(0xFF4A148C))
                  : null,
              onTap: () {
                setState(() => _sort = e.$1);
                Navigator.pop(context);
              },
            )),
        const SizedBox(height: 12),
      ]),
    );
  }

  void _openViewer(DataBankMaterial m, DataBankProvider prov) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: DataBankViewerScreen(material: m),
        ),
      ),
    );
  }
}
