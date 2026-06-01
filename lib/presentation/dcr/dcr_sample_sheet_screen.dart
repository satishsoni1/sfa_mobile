import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../data/models/dcr_models.dart';
import '../../providers/dcr_provider.dart';

// ─── Return type ──────────────────────────────────────────────────────────────

class DcrSampleSheetResult {
  final List<DcrSampleItem> items;
  final String? signaturePath;
  const DcrSampleSheetResult({required this.items, this.signaturePath});
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class DcrSampleSheetScreen extends StatefulWidget {
  final List<DcrSampleItem> initialItems;
  final String? initialSignaturePath;
  final int? visitId;

  const DcrSampleSheetScreen({
    super.key,
    required this.initialItems,
    this.initialSignaturePath,
    this.visitId,
  });

  @override
  State<DcrSampleSheetScreen> createState() => _DcrSampleSheetScreenState();
}

class _DcrSampleSheetScreenState extends State<DcrSampleSheetScreen> {
  static const _purple = Color(0xFF4A148C);

  // productId → quantity for added items
  final List<_SampleEntry> _entries = [];
  List<DcrProduct> _products = [];
  bool _loading = true;

  // Signature
  late final SignatureController _sigCtrl;
  String? _savedSignaturePath;
  bool _sigSaving = false;

  @override
  void initState() {
    super.initState();
    _sigCtrl = SignatureController(
      penColor: Colors.black,
      penStrokeWidth: 2.5,
      exportBackgroundColor: Colors.white,
    );
    _sigCtrl.addListener(() => setState(() {}));
    _savedSignaturePath = widget.initialSignaturePath;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _sigCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prov = context.read<DcrProvider>();
    final prods = prov.products;
    // Build entries from initialItems, matching against current products
    final entries = widget.initialItems
        .map((item) {
          final prod = prods.where((p) => p.id == item.productId).firstOrNull;
          if (prod == null) return null;
          return _SampleEntry(product: prod, qty: item.quantity);
        })
        .whereType<_SampleEntry>()
        .toList();

    if (mounted) {
      setState(() {
        _products = prods;
        _entries.addAll(entries);
        _loading = false;
      });
    }
  }

  // ─── Product picker bottom sheet ──────────────────────────────────────────────

  Future<void> _pickProduct() async {
    final alreadyAdded = _entries.map((e) => e.product.id).toSet();
    final available = _products.where((p) => !alreadyAdded.contains(p.id)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All products already added.')));
      return;
    }

    DcrProduct? picked;
    final searchCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final query = searchCtrl.text.toLowerCase();
          final filtered = query.isEmpty
              ? available
              : available
                  .where((p) =>
                      p.name.toLowerCase().contains(query) ||
                      p.therapyArea.toLowerCase().contains(query))
                  .toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            maxChildSize: 0.92,
            builder: (_, scroll) => Column(children: [
              const SizedBox(height: 10),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Select Product',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (_) => setSheet(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search by name or therapy area…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('No products match.',
                            style: TextStyle(
                                color: Colors.grey.shade500)))
                    : ListView.builder(
                        controller: scroll,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final prod = filtered[i];
                          final outOfStock = prod.stockAvailable == 0;
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: outOfStock
                                  ? Colors.grey.shade200
                                  : _purple.withValues(alpha: 0.1),
                              child: Text(
                                prod.name[0].toUpperCase(),
                                style: TextStyle(
                                    color: outOfStock
                                        ? Colors.grey
                                        : _purple,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12),
                              ),
                            ),
                            title: Text(prod.name,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: outOfStock
                                        ? Colors.grey.shade400
                                        : null)),
                            subtitle: Row(children: [
                              if (prod.therapyArea.isNotEmpty)
                                Text(prod.therapyArea,
                                    style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: outOfStock
                                      ? Colors.red.withValues(alpha: 0.1)
                                      : Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  outOfStock
                                      ? 'Out of stock'
                                      : 'Stock: ${prod.stockAvailable}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: outOfStock
                                          ? Colors.red
                                          : Colors.green.shade700,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('Limit: ${prod.allocationPerDoctor}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500)),
                            ]),
                            enabled: !outOfStock,
                            onTap: outOfStock
                                ? null
                                : () {
                                    picked = prod;
                                    Navigator.pop(ctx);
                                  },
                          );
                        },
                      ),
              ),
            ]),
          );
        },
      ),
    );

    if (picked != null) {
      setState(() => _entries.add(_SampleEntry(product: picked!, qty: 1)));
    }
  }

  // ─── Qty stepper helpers ──────────────────────────────────────────────────────

  void _increment(_SampleEntry e) {
    final max = e.product.allocationPerDoctor <= e.product.stockAvailable
        ? e.product.allocationPerDoctor
        : e.product.stockAvailable;
    if (e.qty < max) setState(() => e.qty++);
  }

  void _decrement(_SampleEntry e) {
    if (e.qty > 0) setState(() => e.qty--);
  }

  void _remove(_SampleEntry e) {
    setState(() => _entries.remove(e));
  }

  // ─── Signature ────────────────────────────────────────────────────────────────

  Future<void> _saveSignature() async {
    if (_sigCtrl.isEmpty) return;
    setState(() => _sigSaving = true);
    try {
      final Uint8List? bytes = await _sigCtrl.toPngBytes();
      if (bytes == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final sigDir = Directory(p.join(dir.path, 'dcr', 'signatures'));
      await sigDir.create(recursive: true);
      final path = p.join(
          sigDir.path, 'sig_${DateTime.now().millisecondsSinceEpoch}.png');
      await File(path).writeAsBytes(bytes);
      if (mounted) setState(() => _savedSignaturePath = path);
    } finally {
      if (mounted) setState(() => _sigSaving = false);
    }
  }

  // ─── Confirm ──────────────────────────────────────────────────────────────────

  Future<void> _confirm() async {
    String? sigPath = _savedSignaturePath;
    if (_sigCtrl.isNotEmpty && sigPath == null) {
      await _saveSignature();
      sigPath = _savedSignaturePath;
    }
    final items = _entries
        .where((e) => e.qty > 0)
        .map((e) => DcrSampleItem(
              visitId: widget.visitId ?? 0,
              productId: e.product.id,
              productName: e.product.name,
              quantity: e.qty,
              allocationLimit: e.product.allocationPerDoctor,
              stockAvailable: e.product.stockAvailable,
            ))
        .toList();
    if (mounted) {
      Navigator.pop(context, DcrSampleSheetResult(items: items, signaturePath: sigPath));
    }
  }

  int get _totalUnits => _entries.fold(0, (s, e) => s + e.qty);

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text('Samples & Signature',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // ── Header strip ────────────────────────────────────────────────
              Container(
                color: _purple,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Text('${_entries.length} product${_entries.length != 1 ? 's' : ''} · $_totalUnits unit${_totalUnits != 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  ElevatedButton.icon(
                    onPressed: _pickProduct,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ]),
              ),
              // ── Scrollable content ──────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(children: [
                    if (_entries.isEmpty) _buildEmptyState(),
                    ..._entries.map(_buildProductRow),
                    const SizedBox(height: 20),
                    _buildSignatureSection(),
                  ]),
                ),
              ),
            ]),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        Icon(Icons.medication_outlined, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No products added yet',
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        Text('Tap "Add Product" above to select from the catalogue',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
      ]),
    );
  }

  // ─── Product row ──────────────────────────────────────────────────────────────

  Widget _buildProductRow(_SampleEntry e) {
    final max = e.product.allocationPerDoctor <= e.product.stockAvailable
        ? e.product.allocationPerDoctor
        : e.product.stockAvailable;
    final atMax = e.qty >= max;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: e.qty > 0
              ? _purple.withValues(alpha: 0.3)
              : Colors.grey.shade200,
          width: e.qty > 0 ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 6,
            height: 44,
            decoration: BoxDecoration(
              color: e.qty > 0 ? _purple : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(e.product.name,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 3),
              Row(children: [
                if (e.product.therapyArea.isNotEmpty) ...[
                  Text(e.product.therapyArea,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500)),
                  const SizedBox(width: 8),
                ],
                Text('Stock: ${e.product.stockAvailable}',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500)),
                const SizedBox(width: 8),
                Text('Limit: ${e.product.allocationPerDoctor}',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500)),
                if (atMax) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Max',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
            ]),
          ),
          // Stepper
          _stepBtn(Icons.remove,
              e.qty > 0 ? () => _decrement(e) : null, Colors.grey.shade500),
          SizedBox(
            width: 36,
            child: Text('${e.qty}',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: e.qty > 0 ? _purple : Colors.grey.shade400)),
          ),
          _stepBtn(
              Icons.add, atMax ? null : () => _increment(e), _purple),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _remove(e),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.delete_outline,
                  size: 16, color: Colors.red.shade300),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onPressed, Color color) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: (onPressed != null ? color : Colors.grey.shade300)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16,
            color: onPressed != null ? color : Colors.grey.shade300),
      ),
    );
  }

  // ─── Signature section ────────────────────────────────────────────────────────

  Widget _buildSignatureSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.draw_outlined, size: 16, color: _purple),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Doctor Signature',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          Text('Confirms sample receipt',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 4),
        Text('Have the doctor sign below to confirm receipt of samples.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 12),
        if (_savedSignaturePath != null) ...[
          // Show captured signature image
          Row(children: [
            const Icon(Icons.verified_outlined, size: 16, color: Colors.green),
            const SizedBox(width: 6),
            const Text('Signature captured',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _savedSignaturePath = null;
                _sigCtrl.clear();
              }),
              child: const Text('Re-sign',
                  style: TextStyle(fontSize: 12, color: Colors.red)),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_savedSignaturePath!),
              height: 100,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
        ] else ...[
          // Signature pad
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (_sigCtrl.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _sigCtrl.clear()),
                child: Text('Clear',
                    style: TextStyle(
                        fontSize: 12, color: Colors.red.shade400)),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
          ]),
          Container(
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(
                  color: _sigCtrl.isNotEmpty
                      ? _purple.withValues(alpha: 0.5)
                      : Colors.grey.shade300,
                  width: 1.5),
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade50,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Signature(
                controller: _sigCtrl,
                backgroundColor: Colors.transparent,
                width: double.infinity,
                height: 140,
              ),
            ),
          ),
          if (_sigCtrl.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: Text('Sign here →',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400)),
              ),
            ),
        ],
      ]),
    );
  }

  // ─── Bottom bar ───────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _confirm,
            icon: _sigSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_outlined),
            label: Text(
              _totalUnits > 0
                  ? 'Confirm – $_totalUnits Unit${_totalUnits != 1 ? 's' : ''}'
                  : 'Confirm (No Samples)',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Local state helper ───────────────────────────────────────────────────────

class _SampleEntry {
  final DcrProduct product;
  int qty;
  _SampleEntry({required this.product, required this.qty});
}
