import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/models/clm_models.dart';
import '../../providers/clm_provider.dart';
import 'clm_player_screen.dart';

class ClmCartScreen extends StatefulWidget {
  final ClmDoctor doctor;
  const ClmCartScreen({super.key, required this.doctor});

  @override
  State<ClmCartScreen> createState() => _ClmCartScreenState();
}

class _ClmCartScreenState extends State<ClmCartScreen> {
  static const _purple = Color(0xFF4A148C);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: _buildAppBar(),
      body: Consumer<ClmProvider>(
        builder: (_, prov, child) => Column(
          children: [
            _buildDoctorHeader(),
            Expanded(
              child: prov.cart.isEmpty
                  ? _buildEmptyCart(context, prov)
                  : _buildCartList(prov),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('Presentation Cart',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      backgroundColor: _purple,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        Consumer<ClmProvider>(
          builder: (_, prov, child) => prov.cart.isNotEmpty
              ? TextButton.icon(
                  onPressed: () {
                    prov.clearCart();
                    prov.buildCartForDoctor(widget.doctor);
                  },
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
                  label: const Text('Reset',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ─── Doctor Header ────────────────────────────────────────────────────────────

  Widget _buildDoctorHeader() {
    final doc = widget.doctor;
    return Container(
      color: _purple,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(doc.initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text('${doc.speciality} · ${doc.area}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Cat ${doc.category}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Empty Cart ───────────────────────────────────────────────────────────────

  Widget _buildEmptyCart(BuildContext context, ClmProvider prov) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_add, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No brands in cart',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
          const SizedBox(height: 6),
          Text('Add brands to start your presentation',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showAddBrandSheet(context, prov),
            icon: const Icon(Icons.add),
            label: const Text('Add Brands'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Cart List ────────────────────────────────────────────────────────────────

  Widget _buildCartList(ClmProvider prov) {
    return Column(
      children: [
        // Summary bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.slideshow_outlined, size: 16, color: _purple),
              const SizedBox(width: 8),
              Text('${prov.cartSlideCount} slides across ${prov.cart.length} brands',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddBrandSheet(context, prov),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    foregroundColor: _purple,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 0)),
              ),
            ],
          ),
        ),
        // Hint
        Container(
          color: _purple.withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.drag_indicator,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('Drag to reorder brands · Tap to expand slides',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
        // Reorderable list
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            itemCount: prov.cart.length,
            onReorder: prov.reorderCart,
            itemBuilder: (context, i) {
              final item = prov.cart[i];
              return _CartBrandCard(
                key: ValueKey('cart_${item.brand.id}'),
                item: item,
                onRemove: () => prov.removeBrandFromCart(item.brand.id),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Add Brand Sheet ──────────────────────────────────────────────────────────

  Future<void> _showAddBrandSheet(
      BuildContext context, ClmProvider prov) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _AddBrandSheet(doctor: widget.doctor),
      ),
    );
  }

  // ─── Bottom Bar ───────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Consumer<ClmProvider>(
      builder: (_, prov, child) {
        final ready = prov.cart.isNotEmpty && prov.cartSlideCount > 0;
        return SafeArea(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: ready ? () => _startPresentation(prov) : null,
                icon: const Icon(Icons.play_circle_filled, size: 22),
                label: Text(
                  ready
                      ? 'Start Presentation  (${prov.cartSlideCount} slides)'
                      : 'Add brands to start',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startPresentation(ClmProvider prov) async {
    await prov.startSession(widget.doctor);
    if (!mounted) return;

    final slides = prov.getFlatSlideList();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: ClmPlayerScreen(
            doctor: widget.doctor,
            slides: slides,
            session: prov.activeSession!,
          ),
        ),
      ),
    );

    // End session when player is popped
    await prov.endSession();
  }
}

// ─── Cart Brand Card ──────────────────────────────────────────────────────────

class _CartBrandCard extends StatefulWidget {
  final ClmCartItem item;
  final VoidCallback onRemove;
  const _CartBrandCard({super.key, required this.item, required this.onRemove});

  @override
  State<_CartBrandCard> createState() => _CartBrandCardState();
}

class _CartBrandCardState extends State<_CartBrandCard> {
  static const _purple = Color(0xFF4A148C);
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Brand header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _expanded
                    ? _purple.withValues(alpha: 0.04)
                    : Colors.transparent,
                borderRadius: _expanded
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: item.cartSequence,
                    child: Icon(Icons.drag_handle,
                        color: Colors.grey.shade400, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: _purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.medication_outlined,
                        color: _purple, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.brand.name,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text('${item.slides.length} slides · ${item.brand.therapyArea}',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onRemove,
                    icon: Icon(Icons.remove_circle_outline,
                        color: Colors.red.shade300, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Slide list
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: item.sortedSlides
                    .map((s) => _slideRow(s))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slideRow(ClmSlide slide) {
    final icons = {
      'video': Icons.play_circle_outline,
      'html': Icons.web_outlined,
      'image': Icons.image_outlined,
    };
    final colors = {
      'video': Colors.red.shade400,
      'html': Colors.blue.shade400,
      'image': Colors.green.shade400,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icons[slide.type] ?? Icons.image_outlined,
              size: 14,
              color: colors[slide.type] ?? Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slide.title.isNotEmpty
                  ? slide.title
                  : 'Slide ${slide.sequence + 1}',
              style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ),
          if (!slide.isDownloaded)
            Icon(Icons.cloud_download_outlined,
                size: 13, color: Colors.amber.shade600),
          if (slide.isDownloaded)
            Icon(Icons.check_circle_outline,
                size: 13, color: Colors.green.shade400),
        ],
      ),
    );
  }
}

// ─── Add Brand Sheet ──────────────────────────────────────────────────────────

class _AddBrandSheet extends StatefulWidget {
  final ClmDoctor doctor;
  const _AddBrandSheet({required this.doctor});

  @override
  State<_AddBrandSheet> createState() => _AddBrandSheetState();
}

class _AddBrandSheetState extends State<_AddBrandSheet> {
  static const _purple = Color(0xFF4A148C);
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Brands',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search brands…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<ClmProvider>(
                builder: (_, prov, child) {
                  var brands = prov.allBrands;
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    brands = brands
                        .where((b) =>
                            b.name.toLowerCase().contains(q) ||
                            b.therapyArea.toLowerCase().contains(q))
                        .toList();
                  }
                  final cartIds =
                      prov.cart.map((c) => c.brand.id).toSet();

                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: brands.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final brand = brands[i];
                      final inCart = cartIds.contains(brand.id);
                      return _BrandTile(
                        brand: brand,
                        inCart: inCart,
                        onToggle: () async {
                          if (inCart) {
                            prov.removeBrandFromCart(brand.id);
                          } else {
                            final slides =
                                await prov.getSlidesForBrand(brand.id);
                            prov.addBrandToCart(brand, slides);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Done'),
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

class _BrandTile extends StatelessWidget {
  final ClmBrand brand;
  final bool inCart;
  final VoidCallback onToggle;
  const _BrandTile(
      {required this.brand,
      required this.inCart,
      required this.onToggle});

  static const _purple = Color(0xFF4A148C);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: inCart
              ? _purple.withValues(alpha: 0.06)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: inCart
                  ? _purple.withValues(alpha: 0.3)
                  : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.medication_outlined,
                  color: _purple, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(brand.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                      '${brand.therapyArea} · ${brand.slideCount} slides',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                  color: inCart ? _purple : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: inCart ? _purple : Colors.grey.shade400,
                      width: 1.5)),
              child: inCart
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
