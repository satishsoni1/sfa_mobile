import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/data_bank_models.dart';
import '../../providers/data_bank_provider.dart';
import 'data_bank_material_list_screen.dart';
import 'data_bank_viewer_screen.dart';

class DataBankHomeScreen extends StatefulWidget {
  const DataBankHomeScreen({super.key});

  @override
  State<DataBankHomeScreen> createState() => _DataBankHomeScreenState();
}

class _DataBankHomeScreenState extends State<DataBankHomeScreen> {
  static const _purple = Color(0xFF4A148C);
  final _searchCtrl = TextEditingController();
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataBankProvider>().init();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Consumer<DataBankProvider>(
        builder: (_, prov, child) {
          return CustomScrollView(
            slivers: [
              _buildAppBar(prov),
              if (_searchActive && _searchCtrl.text.isNotEmpty)
                _buildSearchResults(prov)
              else ...[
                _buildStatsBar(prov),
                if (prov.mandatoryPendingCount > 0)
                  _buildMandatoryAlert(prov),
                _buildFeaturedStrip(prov),
                _buildCategoriesGrid(prov),
                _buildRecentlyViewed(prov),
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ],
          );
        },
      ),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────────────

  Widget _buildAppBar(DataBankProvider prov) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: _purple,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_outlined),
          onPressed: prov.refresh,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFF9C27B0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.library_books_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        Text('Data Bank',
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 12)),
                      ]),
                      Text('Training & Resources',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchCtrl,
                    onTap: () => setState(() => _searchActive = true),
                    onChanged: (v) {
                      prov.search(v);
                      setState(() {});
                    },
                    onSubmitted: prov.search,
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search materials, topics, products…',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13),
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF4A148C)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                prov.clearSearch();
                                setState(() => _searchActive = false);
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        title: Text('Data Bank',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: Colors.white)),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
      ),
    );
  }

  // ─── Stats Bar ────────────────────────────────────────────────────────────────

  Widget _buildStatsBar(DataBankProvider prov) {
    final stats = prov.userStats;
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          _statItem('${stats.totalViewed}', 'Viewed',
              Icons.visibility_outlined, Colors.blue),
          _divider(),
          _statItem('${stats.totalCompleted}', 'Completed',
              Icons.check_circle_outline, Colors.green),
          _divider(),
          _statItem('${stats.mandatoryPending}', 'Mandatory\nPending',
              Icons.priority_high_rounded, Colors.red),
          _divider(),
          _statItem('${stats.totalViewTimeMinutes}m', 'Learning\nTime',
              Icons.timer_outlined, Colors.orange),
        ]),
      ),
    );
  }

  Widget _statItem(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade500, height: 1.3)),
      ]),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 40, color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  // ─── Mandatory Alert ──────────────────────────────────────────────────────────

  Widget _buildMandatoryAlert(DataBankProvider prov) {
    final count = prov.mandatoryPendingCount;
    return SliverToBoxAdapter(
      child: GestureDetector(
        onTap: () => _openMandatoryList(prov),
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.red.shade500],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle),
              child: const Icon(Icons.priority_high_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('$count Mandatory Item${count != 1 ? 's' : ''} Pending',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text('Complete required training to stay compliant',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 16),
          ]),
        ),
      ),
    );
  }

  void _openMandatoryList(DataBankProvider prov) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: const DataBankMaterialListScreen(mandatoryOnly: true),
        ),
      ),
    );
  }

  // ─── Featured Strip ───────────────────────────────────────────────────────────

  Widget _buildFeaturedStrip(DataBankProvider prov) {
    if (prov.featured.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(children: [
            Container(width: 3, height: 16,
                decoration: BoxDecoration(
                    color: _purple, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 8),
            Text('Featured',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Text('${prov.featured.length} items',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: prov.featured.length,
            itemBuilder: (_, i) =>
                _buildFeaturedCard(prov.featured[i], prov),
          ),
        ),
      ]),
    );
  }

  Widget _buildFeaturedCard(DataBankMaterial m, DataBankProvider prov) {
    final typeColor = m.type.color;
    return GestureDetector(
      onTap: () => _openViewer(m, prov),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 8, offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Colour header
          Container(
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [typeColor, typeColor.withValues(alpha: 0.7)],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Stack(children: [
              Center(child: Icon(m.type.icon, color: Colors.white, size: 32)),
              if (m.isNew)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('NEW',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              if (m.isMandatory)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('MANDATORY',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(m.title,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Icon(m.type.icon, size: 11, color: typeColor),
                const SizedBox(width: 3),
                Text(m.type.label,
                    style: TextStyle(fontSize: 10, color: typeColor,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                if (m.userCompleted)
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: Colors.green)
                else if (m.userDurationSeconds > 0)
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      value: m.userProgressFraction,
                      strokeWidth: 2,
                      color: Colors.orange,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ─── Categories Grid ──────────────────────────────────────────────────────────

  Widget _buildCategoriesGrid(DataBankProvider prov) {
    if (prov.isLoading && prov.categories.isEmpty) {
      return const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()));
    }
    return SliverToBoxAdapter(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Row(children: [
            Container(width: 3, height: 16,
                decoration: BoxDecoration(
                    color: _purple, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 8),
            Text('Browse by Category',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.55,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: prov.categories.length,
          itemBuilder: (_, i) => _buildCategoryCard(prov.categories[i], prov),
        ),
      ]),
    );
  }

  Widget _buildCategoryCard(DataBankCategory cat, DataBankProvider prov) {
    final color = cat.color;
    return GestureDetector(
      onTap: () => _openCategory(cat, prov),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 8, offset: const Offset(0, 3))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(cat.icon, color: color, size: 20),
              ),
              const Spacer(),
              if (cat.mandatoryCount > 0)
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                      color: Colors.red.shade600, shape: BoxShape.circle),
                  child: Center(
                    child: Text('${cat.mandatoryCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
            const Spacer(),
            Text(cat.name,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${cat.materialCount} item${cat.materialCount != 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade500)),
          ]),
        ),
      ),
    );
  }

  void _openCategory(DataBankCategory cat, DataBankProvider prov) {
    prov.loadCategory(cat);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: DataBankMaterialListScreen(category: cat),
        ),
      ),
    );
  }

  // ─── Recently Viewed ──────────────────────────────────────────────────────────

  Widget _buildRecentlyViewed(DataBankProvider prov) {
    final recent = prov.mandatory
        .where((m) => m.userLastViewedAt != null)
        .toList()
      ..sort((a, b) =>
          (b.userLastViewedAt ?? DateTime(0)).compareTo(a.userLastViewedAt ?? DateTime(0)));

    if (recent.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(children: [
            Container(width: 3, height: 16,
                decoration: BoxDecoration(
                    color: Colors.teal, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 8),
            Text('Continue Learning',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ),
        ...recent.take(3).map((m) => _buildMaterialListTile(m, prov)),
      ]),
    );
  }

  Widget _buildMaterialListTile(DataBankMaterial m, DataBankProvider prov) {
    return GestureDetector(
      onTap: () => _openViewer(m, prov),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6, offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: m.type.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(m.type.icon, color: m.type.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(m.title,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              if (m.userLastViewedAt != null)
                Text(
                  'Last viewed ${DateFormat("d MMM").format(m.userLastViewedAt!)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: m.userProgressFraction,
                backgroundColor: Colors.grey.shade200,
                color: m.userCompleted ? Colors.green : Colors.orange,
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          m.userCompleted
              ? const Icon(Icons.check_circle_rounded,
                  size: 20, color: Colors.green)
              : const Icon(Icons.play_circle_outline_rounded,
                  size: 20, color: Color(0xFF4A148C)),
        ]),
      ),
    );
  }

  // ─── Search Results ───────────────────────────────────────────────────────────

  Widget _buildSearchResults(DataBankProvider prov) {
    if (prov.isSearching) {
      return const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()));
    }
    if (prov.searchResults.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.search_off_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No materials found',
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Try different keywords or browse by category',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ]),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: _buildMaterialListTile(prov.searchResults[i], prov),
        ),
        childCount: prov.searchResults.length,
      ),
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
