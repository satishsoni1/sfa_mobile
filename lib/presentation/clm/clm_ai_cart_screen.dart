import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/models/clm_models.dart';
import '../../providers/clm_provider.dart';
import 'clm_player_screen.dart';

// ─── Mode Enum ────────────────────────────────────────────────────────────────

enum _CartMode { ai, manual }

// ─── Manual Brand Item ────────────────────────────────────────────────────────

class _ManualItem {
  final ClmBrand brand;
  final List<ClmSlide> slides;
  bool selected;
  int? aiScore;

  _ManualItem({
    required this.brand,
    required this.slides,
    this.selected = false,
    this.aiScore,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ClmAiCartScreen extends StatefulWidget {
  final ClmDoctor doctor;
  final Position? checkInPosition;
  const ClmAiCartScreen({super.key, required this.doctor, this.checkInPosition});

  @override
  State<ClmAiCartScreen> createState() => _ClmAiCartScreenState();
}

class _ClmAiCartScreenState extends State<ClmAiCartScreen>
    with TickerProviderStateMixin {
  static const _purple = Color(0xFF4A148C);
  static const _aiBlue = Color(0xFF0277BD);
  static const _manualGreen = Color(0xFF2E7D32);

  // ─── State ─────────────────────────────────────────────────────────────────

  AiDoctorInsight? _insight;
  bool _loading = true;
  _CartMode _mode = _CartMode.ai;

  // Manual mode
  final List<_ManualItem> _allItems = [];
  final List<int> _selectedOrder = []; // brand IDs in playback order
  String _search = '';

  // AI mode UI toggles
  bool _showAllTips = false;
  bool _briefingExpanded = true;

  // Animations
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAnalysis());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─── Analysis ──────────────────────────────────────────────────────────────

  Future<void> _runAnalysis() async {
    final prov = context.read<ClmProvider>();
    final insight = await prov.getAiInsightForDoctor(widget.doctor);
    if (!mounted) return;

    // Build manual items from ALL brands with AI score context
    final allBrands = prov.allBrands;
    for (final brand in allBrands) {
      final slides = await prov.getSlidesForBrand(brand.id);
      final rec = _recFor(insight, brand.id);
      _allItems.add(_ManualItem(
        brand: brand,
        slides: slides,
        selected: rec?.isSelected ?? false,
        aiScore: rec?.score,
      ));
    }

    // Sort: AI-selected first by score, then unselected alphabetically
    _allItems.sort((a, b) {
      final aSel = a.selected ? 1 : 0;
      final bSel = b.selected ? 1 : 0;
      if (aSel != bSel) return bSel.compareTo(aSel);
      final aScore = a.aiScore ?? 0;
      final bScore = b.aiScore ?? 0;
      if (aScore != bScore) return bScore.compareTo(aScore);
      return a.brand.name.compareTo(b.brand.name);
    });

    // Init selected order from AI
    _selectedOrder.addAll(
        insight.brandRecs.where((r) => r.isSelected).map((r) => r.brand.id));

    setState(() {
      _insight = insight;
      _loading = false;
    });
  }

  AiBrandRec? _recFor(AiDoctorInsight insight, int brandId) {
    for (final r in insight.brandRecs) {
      if (r.brand.id == brandId) return r;
    }
    return null;
  }

  // ─── Mode Switching ────────────────────────────────────────────────────────

  void _switchMode(_CartMode m) {
    if (m == _mode || _insight == null) return;
    if (m == _CartMode.manual) {
      // Sync manual selection from current AI state
      _syncManualFromAi();
    }
    setState(() => _mode = m);
  }

  void _syncManualFromAi() {
    _selectedOrder.clear();
    for (final item in _allItems) {
      final rec = _recFor(_insight!, item.brand.id);
      item.selected = rec?.isSelected ?? false;
    }
    // Rebuild order: AI recommended first
    for (final rec in _insight!.brandRecs.where((r) => r.isSelected)) {
      _selectedOrder.add(rec.brand.id);
    }
  }

  void _resetManualToAi() {
    setState(_syncManualFromAi);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Reset to AI recommendations'),
          duration: Duration(seconds: 2)),
    );
  }

  // ─── Manual Mode Helpers ────────────────────────────────────────────────────

  void _toggleManual(_ManualItem item) {
    setState(() {
      item.selected = !item.selected;
      if (item.selected) {
        if (!_selectedOrder.contains(item.brand.id)) {
          _selectedOrder.add(item.brand.id);
        }
      } else {
        _selectedOrder.remove(item.brand.id);
      }
    });
  }

  void _reorderSelected(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final id = _selectedOrder.removeAt(oldIndex);
      _selectedOrder.insert(newIndex, id);
    });
  }

  List<_ManualItem> get _filteredUnselected {
    final q = _search.toLowerCase();
    return _allItems.where((i) {
      if (i.selected) return false;
      if (q.isEmpty) return true;
      return i.brand.name.toLowerCase().contains(q) ||
          i.brand.therapyArea.toLowerCase().contains(q);
    }).toList();
  }

  // ─── Play ──────────────────────────────────────────────────────────────────

  int get _selectedCount => _mode == _CartMode.ai
      ? (_insight?.brandRecs.where((r) => r.isSelected).length ?? 0)
      : _selectedOrder.length;

  int get _totalSlides {
    if (_mode == _CartMode.ai) {
      return _insight?.brandRecs
              .where((r) => r.isSelected)
              .fold<int>(0, (s, r) => s + r.slides.length) ??
          0;
    }
    return _selectedOrder.fold<int>(0, (s, id) {
      final item = _itemById(id);
      return s + (item?.slides.length ?? 0);
    });
  }

  _ManualItem? _itemById(int brandId) {
    for (final i in _allItems) {
      if (i.brand.id == brandId) return i;
    }
    return null;
  }

  Future<void> _play() async {
    final prov = context.read<ClmProvider>();

    if (_mode == _CartMode.ai && _insight != null) {
      prov.applyAiCart(_insight!);
    } else {
      prov.clearCart();
      for (final id in _selectedOrder) {
        final item = _itemById(id);
        if (item != null && item.slides.isNotEmpty) {
          prov.addBrandToCart(item.brand, item.slides);
        }
      }
    }

    if (!mounted) return;
    if (prov.cartSlideCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No downloaded slides. Sync content first.')));
      return;
    }

    await prov.startSession(widget.doctor, position: widget.checkInPosition);
    if (!mounted) return;

    final slides = prov.getFlatSlideList();
    final session = prov.activeSession;
    if (session == null) return;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: ClmPlayerScreen(
            doctor: widget.doctor,
            slides: slides,
            session: session,
          ),
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (!_loading) _buildModeToggle(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _loading
                  ? _buildLoadingState()
                  : _mode == _CartMode.ai
                      ? _buildAiBody()
                      : _buildManualBody(),
            ),
          ),
        ],
      ),
      floatingActionButton:
          (!_loading && _selectedCount > 0) ? _buildPlayFab() : null,
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final color =
        _mode == _CartMode.ai ? _purple : _manualGreen;
    return AppBar(
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white),
          child: Text(_mode == _CartMode.ai
              ? 'AI Pre-Call Briefing'
              : 'Manual Override'),
        ),
        Text(widget.doctor.name,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
      ]),
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        if (!_loading && _mode == _CartMode.ai)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(children: [
              ScaleTransition(
                  scale: _pulse,
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.amber, size: 14)),
              const SizedBox(width: 4),
              Text('AI Ready',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        if (!_loading && _mode == _CartMode.manual)
          TextButton.icon(
            onPressed: _resetManualToAi,
            icon: const Icon(Icons.auto_awesome, size: 14, color: Colors.white70),
            label: const Text('Reset to AI',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ),
      ],
    );
  }

  // ─── Mode Toggle ───────────────────────────────────────────────────────────

  Widget _buildModeToggle() {
    return Container(
      color: _mode == _CartMode.ai ? _purple : _manualGreen,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(children: [
        Expanded(
          child: _ModeToggleBtn(
            label: 'AI Auto',
            icon: Icons.auto_awesome,
            active: _mode == _CartMode.ai,
            activeColor: _purple,
            onTap: () => _switchMode(_CartMode.ai),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ModeToggleBtn(
            label: 'Manual Override',
            icon: Icons.tune,
            active: _mode == _CartMode.manual,
            activeColor: _manualGreen,
            onTap: () => _switchMode(_CartMode.manual),
          ),
        ),
      ]),
    );
  }

  // ─── Loading ───────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      key: const ValueKey('loading'),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        ScaleTransition(
          scale: _pulse,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [_aiBlue, _purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(
                    color: _aiBlue.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2)
              ],
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 20),
        Text('AI analysing ${widget.doctor.name}…',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 8),
        Text('Checking visit history, reactions & product affinity',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(_aiBlue),
            minHeight: 3,
          ),
        ),
      ]),
    );
  }

  // ─── AI Body ───────────────────────────────────────────────────────────────

  Widget _buildAiBody() {
    final insight = _insight!;
    return CustomScrollView(
      key: const ValueKey('ai'),
      slivers: [
        SliverToBoxAdapter(child: _buildDoctorHeader(insight)),
        SliverToBoxAdapter(child: _buildCollapsibleBriefing(insight)),
        SliverToBoxAdapter(child: _buildHighlightsSection(insight)),
        SliverToBoxAdapter(child: _buildScriptTipsSection(insight)),
        SliverToBoxAdapter(child: _buildAiBrandSection(insight)),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildDoctorHeader(AiDoctorInsight insight) {
    final lvlColor = _levelColor(insight.engagementLevel);
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: _purple.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: lvlColor, width: 3)),
            child: CircleAvatar(
              backgroundColor: _purple.withValues(alpha: 0.1),
              child: Text(widget.doctor.initials,
                  style: TextStyle(
                      color: _purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                  color: lvlColor, borderRadius: BorderRadius.circular(6)),
              child: Text('${insight.engagementScore}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(widget.doctor.name,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            Text('${widget.doctor.speciality} · ${widget.doctor.area}',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            if (widget.doctor.hospital != null &&
                widget.doctor.hospital!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(widget.doctor.hospital!,
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _chip('Cat ${widget.doctor.category}',
                  _catColor(widget.doctor.category)),
              _chip(insight.engagementLevel, lvlColor),
              _chip(widget.doctor.daysSinceLabel, Colors.grey.shade600),
            ]),
          ]),
        ),
        _EngagementArc(score: insight.engagementScore, color: lvlColor),
      ]),
    );
  }

  Widget _buildCollapsibleBriefing(AiDoctorInsight insight) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF01579B), Color(0xFF0277BD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        // Header row (always visible)
        InkWell(
          onTap: () =>
              setState(() => _briefingExpanded = !_briefingExpanded),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.psychology, color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('AI Pre-Call Summary',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              Icon(
                  _briefingExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: Colors.white54,
                  size: 20),
            ]),
          ),
        ),
        // Expandable body
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _briefingExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(insight.preCallSummary,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 12, height: 1.5)),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _buildHighlightsSection(AiDoctorInsight insight) {
    if (insight.highlights.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Row(children: [
          const Icon(Icons.lightbulb, color: _purple, size: 15),
          const SizedBox(width: 6),
          Text('Key Highlights',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          const SizedBox(width: 6),
          Text('· tap for detail',
              style:
                  TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ]),
      ),
      SizedBox(
        height: 88,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 14, right: 6),
          itemCount: insight.highlights.length,
          itemBuilder: (_, i) =>
              _HighlightCard(highlight: insight.highlights[i]),
        ),
      ),
      const SizedBox(height: 14),
    ]);
  }

  Widget _buildScriptTipsSection(AiDoctorInsight insight) {
    if (insight.scriptTips.isEmpty) return const SizedBox.shrink();
    final visible = _showAllTips
        ? insight.scriptTips
        : insight.scriptTips.take(3).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: _purple.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _showAllTips = !_showAllTips),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.record_voice_over,
                    color: _purple, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Script Tips & Talking Points',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${insight.scriptTips.length} tips',
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              Icon(_showAllTips ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade400, size: 20),
            ]),
          ),
        ),
        const Divider(height: 1),
        ...visible.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                      color: _aiBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Center(
                      child: Text('${e.key + 1}',
                          style: const TextStyle(
                              fontSize: 9,
                              color: _aiBlue,
                              fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(e.value,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            height: 1.5,
                            fontStyle: FontStyle.italic))),
              ]),
            )),
        if (!_showAllTips && insight.scriptTips.length > 3)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: GestureDetector(
              onTap: () => setState(() => _showAllTips = true),
              child: Text(
                  '+${insight.scriptTips.length - 3} more tips…',
                  style: const TextStyle(
                      fontSize: 11,
                      color: _aiBlue,
                      fontWeight: FontWeight.w600)),
            ),
          )
        else
          const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildAiBrandSection(AiDoctorInsight insight) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.playlist_play, color: _purple, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('AI Recommended Cart',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
              Text('Toggle to include/exclude · Switch to Manual for full control',
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ]),
          ),
        ]),
      ),

      // Ranked brand cards (reorderable)
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: insight.brandRecs.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = insight.brandRecs.removeAt(oldIndex);
            insight.brandRecs.insert(newIndex, item);
            // Update ranks
          });
        },
        itemBuilder: (_, i) {
          final rec = insight.brandRecs[i];
          return _AiBrandCard(
            key: ValueKey('ai_brand_${rec.brand.id}'),
            rec: rec,
            rank: i + 1,
            onToggle: (v) => setState(() => rec.isSelected = v),
          );
        },
      ),

      // Add extra brand
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: _addBrandHint(),
      ),
    ]);
  }

  Widget _addBrandHint() {
    // Brands NOT in AI recommendations
    final aiIds =
        _insight!.brandRecs.map((r) => r.brand.id).toSet();
    final extras = _allItems.where((i) => !aiIds.contains(i.brand.id)).toList();
    if (extras.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showAddExtraBrands(extras),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _purple.withValues(alpha: 0.2),
              style: BorderStyle.solid),
        ),
        child: Row(children: [
          Icon(Icons.add_circle_outline, color: _purple, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Text('Add More Brands',
                style: TextStyle(
                    fontSize: 12,
                    color: _purple,
                    fontWeight: FontWeight.w600)),
            Text('${extras.length} additional brands available',
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade500)),
          ])),
          Icon(Icons.chevron_right,
              color: Colors.grey.shade400, size: 18),
        ]),
      ),
    );
  }

  void _showAddExtraBrands(List<_ManualItem> extras) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExtraBrandsSheet(
        extras: extras,
        alreadyAdded:
            _insight!.brandRecs.map((r) => r.brand.id).toSet(),
        onAdd: (item) {
          setState(() {
            _insight!.brandRecs.add(AiBrandRec(
              brand: item.brand,
              score: item.aiScore ?? 30,
              reason: 'Manually added to cart.',
              slides: item.slides,
              isSelected: true,
            ));
          });
        },
      ),
    );
  }

  // ─── Manual Body ───────────────────────────────────────────────────────────

  Widget _buildManualBody() {
    final selectedItems = _selectedOrder
        .map(_itemById)
        .whereType<_ManualItem>()
        .toList();
    final unselectedItems = _filteredUnselected;

    return CustomScrollView(
      key: const ValueKey('manual'),
      slivers: [
        // Selected count banner
        SliverToBoxAdapter(
          child: _buildManualHeader(selectedItems.length),
        ),

        // ─ Selected brands (reorderable) ──────────────────────────────────
        if (selectedItems.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Row(children: [
                const Icon(Icons.play_circle_outline,
                    size: 15, color: _manualGreen),
                const SizedBox(width: 6),
                Text('Playback Queue (${selectedItems.length})',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
                const SizedBox(width: 6),
                Text('· drag to reorder',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade400)),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: selectedItems.length * 72.0 + 8,
              child: ReorderableListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                itemCount: selectedItems.length,
                onReorder: _reorderSelected,
                proxyDecorator: (child, _, anim) => Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
                itemBuilder: (_, i) {
                  final item = selectedItems[i];
                  return _SelectedBrandTile(
                    key: ValueKey('sel_${item.brand.id}'),
                    item: item,
                    rank: i + 1,
                    onRemove: () => _toggleManual(item),
                  );
                },
              ),
            ),
          ),
        ],

        // ─ Search & Available ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                const Icon(Icons.library_books_outlined,
                    size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                Text('Available Brands',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
              ]),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search brands…',
                  hintStyle: TextStyle(
                      fontSize: 12, color: Colors.grey.shade400),
                  prefixIcon:
                      const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ]),
          ),
        ),

        SliverList.separated(
          itemCount: unselectedItems.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 6),
          itemBuilder: (ctx, i) {
            final item = unselectedItems[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _AvailableBrandTile(
                item: item,
                onAdd: () => _toggleManual(item),
              ),
            );
          },
        ),

        if (unselectedItems.isEmpty && _search.isNotEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('No brands match "$_search"',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13)),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildManualHeader(int selected) {
    return Container(
      color: _manualGreen,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.tune, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('Manual Override Active',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text('$selected brand${selected != 1 ? 's' : ''} selected · '
                '${_totalSlides} slides · You have full control',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  // ─── Play FAB ──────────────────────────────────────────────────────────────

  Widget _buildPlayFab() {
    final color =
        _mode == _CartMode.ai ? _purple : _manualGreen;
    final label = _mode == _CartMode.ai
        ? 'Play AI Cart  ·  $_selectedCount brand${_selectedCount != 1 ? 's' : ''}, $_totalSlides slides'
        : 'Play Manual  ·  $_selectedCount brand${_selectedCount != 1 ? 's' : ''}, $_totalSlides slides';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _play,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 24),
        label: Text(label,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Color _levelColor(String level) {
    switch (level) {
      case 'High': return const Color(0xFF1B5E20);
      case 'Medium': return const Color(0xFFE65100);
      case 'Low': return const Color(0xFFBF360C);
      default: return const Color(0xFFB71C1C);
    }
  }

  Color _catColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'A': return Colors.red.shade600;
      case 'B': return Colors.orange.shade600;
      default: return Colors.blue.shade600;
    }
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Mode Toggle Button ───────────────────────────────────────────────────────

class _ModeToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ModeToggleBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 14,
                color: active ? activeColor : Colors.white70),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? activeColor : Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// ─── Engagement Arc ───────────────────────────────────────────────────────────

class _EngagementArc extends StatelessWidget {
  final int score;
  final Color color;
  const _EngagementArc({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          value: score / 100,
          strokeWidth: 5,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$score',
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold)),
          Text('%',
              style:
                  TextStyle(fontSize: 8, color: Colors.grey.shade500)),
        ]),
      ]),
    );
  }
}

// ─── Highlight Card ───────────────────────────────────────────────────────────

class _HighlightCard extends StatelessWidget {
  final AiKeyHighlight highlight;
  const _HighlightCard({required this.highlight});

  Color get _color {
    switch (highlight.type) {
      case AiHighlightType.birthday:
      case AiHighlightType.anniversary:
        return const Color(0xFFAD1457);
      case AiHighlightType.lastReaction:
        return const Color(0xFF1B5E20);
      case AiHighlightType.objection:
        return const Color(0xFFB71C1C);
      case AiHighlightType.overdueVisit:
        return const Color(0xFFBF360C);
      case AiHighlightType.productAffinity:
        return const Color(0xFF4A148C);
      case AiHighlightType.competitor:
        return const Color(0xFF00695C);
      default:
        return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _detail(context),
      child: Container(
        width: 118,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
                color: _color.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Text(highlight.emoji,
              style: const TextStyle(fontSize: 20)),
          Text(highlight.label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  void _detail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Text(highlight.emoji,
                style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(highlight.label,
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 14),
          Text(highlight.detail,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.6)),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ─── AI Brand Card (reorderable) ──────────────────────────────────────────────

class _AiBrandCard extends StatelessWidget {
  final AiBrandRec rec;
  final int rank;
  final ValueChanged<bool> onToggle;

  const _AiBrandCard({
    super.key,
    required this.rec,
    required this.rank,
    required this.onToggle,
  });

  Color get _rankColor {
    if (rank == 1) return const Color(0xFF4A148C);
    if (rank == 2) return const Color(0xFF1565C0);
    return Colors.grey.shade600;
  }

  Color get _scoreColor {
    if (rec.score >= 75) return const Color(0xFF1B5E20);
    if (rec.score >= 50) return const Color(0xFFE65100);
    return const Color(0xFFB71C1C);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: rec.isSelected ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rec.isSelected
              ? _rankColor.withValues(alpha: 0.3)
              : Colors.grey.shade200,
          width: rec.isSelected ? 1.5 : 1,
        ),
        boxShadow: rec.isSelected
            ? [
                BoxShadow(
                    color: _rankColor.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ]
            : null,
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(children: [
            // Drag handle
            Icon(Icons.drag_handle,
                color: Colors.grey.shade300, size: 20),
            const SizedBox(width: 8),

            // Rank badge
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                  color: rec.isSelected
                      ? _rankColor.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  shape: BoxShape.circle),
              child: Center(
                  child: Text('#$rank',
                      style: TextStyle(
                          fontSize: 9,
                          color: rec.isSelected
                              ? _rankColor
                              : Colors.grey.shade500,
                          fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(rec.brand.name,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: rec.isSelected
                            ? Colors.black87
                            : Colors.grey.shade400)),
                Text(rec.brand.therapyArea,
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500)),
              ]),
            ),

            // Score ring
            SizedBox(
              width: 42,
              height: 42,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: rec.score / 100,
                  strokeWidth: 4,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_scoreColor),
                ),
                Text('${rec.score}',
                    style: TextStyle(
                        fontSize: 9,
                        color: _scoreColor,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(width: 6),

            Switch(
              value: rec.isSelected,
              onChanged: onToggle,
              activeThumbColor: _rankColor,
              activeTrackColor: _rankColor.withValues(alpha: 0.3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        ),

        if (rec.isSelected) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFF4F6FB),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Icon(Icons.auto_awesome,
                      size: 11, color: Color(0xFF0277BD)),
                  const SizedBox(width: 5),
                  Expanded(
                      child: Text(rec.reason,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              height: 1.4))),
                ]),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${rec.slides.length}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A148C))),
                Text('slides',
                    style: TextStyle(
                        fontSize: 9, color: Colors.grey.shade500)),
              ]),
            ]),
          ),
          if (rec.slides.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...rec.slides.take(3).map((s) => _slideChip(s, _rankColor)),
                  if (rec.slides.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('+${rec.slides.length - 3} more',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600)),
                    ),
                ],
              ),
            ),
        ],
      ]),
    );
  }

  Widget _slideChip(ClmSlide s, Color color) {
    final icon = s.type == 'video'
        ? Icons.videocam_outlined
        : s.type == 'html'
            ? Icons.web_outlined
            : Icons.image_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
            s.title.length > 16
                ? '${s.title.substring(0, 16)}…'
                : s.title,
            style: TextStyle(fontSize: 9, color: color)),
      ]),
    );
  }
}

// ─── Selected Brand Tile (manual reorderable) ─────────────────────────────────

class _SelectedBrandTile extends StatelessWidget {
  final _ManualItem item;
  final int rank;
  final VoidCallback onRemove;

  const _SelectedBrandTile({
    super.key,
    required this.item,
    required this.rank,
    required this.onRemove,
  });

  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        // Drag handle
        Icon(Icons.drag_handle,
            color: Colors.grey.shade300, size: 22),
        const SizedBox(width: 10),

        // Rank
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              shape: BoxShape.circle),
          child: Center(
              child: Text('$rank',
                  style: const TextStyle(
                      fontSize: 10,
                      color: _green,
                      fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 10),

        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Text(item.brand.name,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w700)),
            Text(
                '${item.slides.length} slides · ${item.brand.therapyArea}',
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade500)),
          ]),
        ),

        // AI score badge if available
        if (item.aiScore != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
                color: const Color(0xFF0277BD).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text('AI ${item.aiScore}',
                style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF0277BD),
                    fontWeight: FontWeight.bold)),
          ),

        // Remove
        GestureDetector(
          onTap: onRemove,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.close,
                size: 14, color: Colors.red.shade400),
          ),
        ),
      ]),
    );
  }
}

// ─── Available Brand Tile (manual add) ───────────────────────────────────────

class _AvailableBrandTile extends StatelessWidget {
  final _ManualItem item;
  final VoidCallback onAdd;

  const _AvailableBrandTile(
      {super.key, required this.item, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4)
        ],
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.medication_outlined,
              color: Colors.grey.shade500, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(item.brand.name,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            Text(
                '${item.brand.therapyArea} · ${item.slides.length} slides',
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade500)),
          ]),
        ),
        if (item.aiScore != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
                color: const Color(0xFF0277BD).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6)),
            child: Text('AI ${item.aiScore}',
                style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF0277BD),
                    fontWeight: FontWeight.w600)),
          ),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.add,
                size: 16, color: Color(0xFF2E7D32)),
          ),
        ),
      ]),
    );
  }
}

// ─── Extra Brands Sheet (AI mode "Add More") ──────────────────────────────────

class _ExtraBrandsSheet extends StatefulWidget {
  final List<_ManualItem> extras;
  final Set<int> alreadyAdded;
  final ValueChanged<_ManualItem> onAdd;

  const _ExtraBrandsSheet(
      {required this.extras,
      required this.alreadyAdded,
      required this.onAdd});

  @override
  State<_ExtraBrandsSheet> createState() => _ExtraBrandsSheetState();
}

class _ExtraBrandsSheetState extends State<_ExtraBrandsSheet> {
  final Set<int> _justAdded = {};

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(children: [
              Expanded(
                  child: Text('Add to AI Cart',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold))),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done')),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
              itemCount: widget.extras.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final item = widget.extras[i];
                final added = widget.alreadyAdded.contains(item.brand.id) ||
                    _justAdded.contains(item.brand.id);
                return _AddableTile(
                  item: item,
                  added: added,
                  onAdd: () {
                    setState(() => _justAdded.add(item.brand.id));
                    widget.onAdd(item);
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _AddableTile extends StatelessWidget {
  final _ManualItem item;
  final bool added;
  final VoidCallback onAdd;

  const _AddableTile(
      {required this.item, required this.added, required this.onAdd});

  static const _purple = Color(0xFF4A148C);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: added ? _purple.withValues(alpha: 0.06) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: added
                ? _purple.withValues(alpha: 0.3)
                : Colors.grey.shade200),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.medication_outlined,
              color: _purple, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(item.brand.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            Text(
                '${item.brand.therapyArea} · ${item.slides.length} slides',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
          ]),
        ),
        GestureDetector(
          onTap: added ? null : onAdd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: added ? _purple : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                    color: added ? _purple : Colors.grey.shade400,
                    width: 1.5)),
            child: added
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : const Icon(Icons.add, color: Colors.transparent, size: 14),
          ),
        ),
      ]),
    );
  }
}
