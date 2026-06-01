import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/models/clm_models.dart';
import '../../providers/clm_provider.dart';
import 'clm_call_report_screen.dart';

class ClmPlayerScreen extends StatefulWidget {
  final ClmDoctor doctor;
  final List<ClmSlide> slides;
  final ClmSession session;

  const ClmPlayerScreen({
    super.key,
    required this.doctor,
    required this.slides,
    required this.session,
  });

  @override
  State<ClmPlayerScreen> createState() => _ClmPlayerScreenState();
}

class _ClmPlayerScreenState extends State<ClmPlayerScreen>
    with TickerProviderStateMixin {
  static const _purple = Color(0xFF4A148C);

  late PageController _pageCtrl;
  late AnimationController _overlayCtrl;
  late Animation<double> _overlayAnim;

  int _currentIndex = 0;
  bool _showOverlay = true;
  bool _checkingOut = false;
  Timer? _overlayTimer;
  Timer? _sessionTimer;
  int _elapsedSeconds = 0;

  final Map<int, VideoPlayerController> _videoControllers = {};
  final Map<int, WebViewController> _webControllers = {};
  final Set<int> _starredSlideIds = {};

  ClmProvider get _prov => context.read<ClmProvider>();

  @override
  void initState() {
    super.initState();

    _pageCtrl = PageController();

    _overlayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _overlayAnim = CurvedAnimation(parent: _overlayCtrl, curve: Curves.easeInOut);
    _overlayCtrl.value = 1.0;

    _sessionTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => _elapsedSeconds++));

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _recordSlideEnter(0);
    _scheduleOverlayHide();
    _preloadAround(0);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _overlayCtrl.dispose();
    _overlayTimer?.cancel();
    _sessionTimer?.cancel();
    for (final c in _videoControllers.values) c.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─── Analytics ────────────────────────────────────────────────────────────────

  void _recordSlideEnter(int index) {
    if (index >= widget.slides.length) return;
    _prov.analyticsService.markSlideEntered(widget.slides[index].id);
  }

  Future<void> _recordSlideExit(int index, {bool skipped = false}) async {
    if (index >= widget.slides.length) return;
    await _prov.analyticsService.markSlideExited(
      widget.session.id,
      widget.slides[index],
      skipped: skipped,
    );
  }

  // ─── Navigation ───────────────────────────────────────────────────────────────

  void _goTo(int index, {bool skipped = false}) {
    if (index < 0 || index >= widget.slides.length) return;
    _recordSlideExit(_currentIndex, skipped: skipped);
    _videoControllers[_currentIndex]?.pause();
    setState(() => _currentIndex = index);
    _pageCtrl.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    _recordSlideEnter(index);
    _preloadAround(index);
    _showOverlayBriefly();
  }

  void _next() => _goTo(_currentIndex + 1, skipped: false);
  void _prev() => _goTo(_currentIndex - 1, skipped: true);

  Future<void> _exitPresentation() async {
    if (_checkingOut) return;
    setState(() => _checkingOut = true);
    try {
      await _recordSlideExit(_currentIndex);
      await _prov.analyticsService.flushOpenSlides(widget.session.id, widget.slides);
      await _prov.endSession();

      if (!mounted) return;
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      final brands = _prov.cart.map((c) => c.brand).toList();
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: _prov,
            child: ClmCallReportScreen(
              doctor: widget.doctor,
              session: widget.session,
              brands: brands,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _checkingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not end session: $e'),
              backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  // ─── Overlay ──────────────────────────────────────────────────────────────────

  bool get _currentSlideIsHtml =>
      _currentIndex < widget.slides.length &&
      widget.slides[_currentIndex].type == 'html';

  void _scheduleOverlayHide() {
    _overlayTimer?.cancel();
    // HTML slides: WebView absorbs taps so keep overlay permanently visible
    if (_currentSlideIsHtml) {
      if (!_showOverlay) {
        setState(() => _showOverlay = true);
        _overlayCtrl.forward();
      }
      return;
    }
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _overlayCtrl.reverse();
        setState(() => _showOverlay = false);
      }
    });
  }

  void _showOverlayBriefly() {
    setState(() => _showOverlay = true);
    _overlayCtrl.forward();
    _scheduleOverlayHide();
  }

  void _onTapScreen() {
    // HTML slides: WebView intercepts taps; overlay is always visible; nothing to toggle
    if (_currentSlideIsHtml) return;
    if (_showOverlay) {
      _overlayCtrl.reverse();
      setState(() => _showOverlay = false);
      _overlayTimer?.cancel();
    } else {
      _showOverlayBriefly();
    }
  }

  // ─── Preloading ───────────────────────────────────────────────────────────────

  void _preloadAround(int index) {
    for (int i = index; i <= index + 2 && i < widget.slides.length; i++) {
      _preloadSlide(i);
    }
  }

  void _preloadSlide(int index) {
    final slide = widget.slides[index];
    if (slide.type == 'video' &&
        slide.localPath != null &&
        !_videoControllers.containsKey(index)) {
      final ctrl = VideoPlayerController.file(File(slide.localPath!))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        }).catchError((_) {});
      _videoControllers[index] = ctrl;
    }
  }

  // ─── Starring ─────────────────────────────────────────────────────────────────

  void _toggleStar() {
    final slide = widget.slides[_currentIndex];
    setState(() {
      if (_starredSlideIds.contains(slide.id)) {
        _starredSlideIds.remove(slide.id);
      } else {
        _starredSlideIds.add(slide.id);
      }
    });
    // Track as analytics event
    _prov.analyticsService.trackEvent(
      sessionId: widget.session.id,
      slide: slide,
      eventType: _starredSlideIds.contains(slide.id) ? 'star' : 'unstar',
    );
    _showOverlayBriefly();
  }

  // ─── Share ────────────────────────────────────────────────────────────────────

  void _showShareSheet() {
    _overlayTimer?.cancel();
    final slide = widget.slides[_currentIndex];
    final brandName = _prov.cart
        .firstWhere(
          (c) => c.slides.any((s) => s.id == slide.id),
          orElse: () => _prov.cart.first,
        )
        .brand
        .name;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(
        slideTitle: slide.title,
        brandName: brandName,
        doctorName: widget.doctor.name,
        slideLocalPath: slide.localPath,
        onDismiss: () => _showOverlayBriefly(),
      ),
    ).whenComplete(_showOverlayBriefly);
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTapScreen,
        onHorizontalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -300) _next();
          if ((d.primaryVelocity ?? 0) > 300) _prev();
        },
        child: Stack(
          children: [
            // Slide PageView
            PageView.builder(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.slides.length,
              itemBuilder: (_, i) => _buildSlide(widget.slides[i], i),
            ),

            // Top overlay
            FadeTransition(opacity: _overlayAnim, child: _buildTopOverlay()),

            // Bottom overlay
            FadeTransition(opacity: _overlayAnim, child: _buildBottomOverlay()),

            // Nav arrows
            if (_showOverlay) ...[
              if (_currentIndex > 0)
                Positioned(
                  left: 8, top: 0, bottom: 0,
                  child: Center(child: _navArrow(Icons.chevron_left, _prev)),
                ),
              if (_currentIndex < widget.slides.length - 1)
                Positioned(
                  right: 8, top: 0, bottom: 0,
                  child: Center(child: _navArrow(Icons.chevron_right, _next)),
                ),
            ],

            // Always-visible "End Detailing" button — never hidden by overlay auto-hide
            // Sits above WebView so it is always tappable on HTML slides
            Positioned(
              bottom: 16,
              right: 16,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _exitPresentation,
                child: AnimatedOpacity(
                  opacity: _checkingOut ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade800.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3))
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_checkingOut)
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      else
                        const Icon(Icons.stop_circle_outlined,
                            color: Colors.white, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        _checkingOut ? 'Ending…' : 'End Detailing',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Slide renderers ─────────────────────────────────────────────────────────

  Widget _buildSlide(ClmSlide slide, int index) {
    if (!slide.canPlay) return _buildPlaceholder(slide);
    switch (slide.type) {
      case 'video': return _buildVideoSlide(slide, index);
      case 'html':  return _buildHtmlSlide(slide, index);
      default:      return _buildImageSlide(slide);
    }
  }

  Widget _buildImageSlide(ClmSlide slide) {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      child: Image.file(
        File(slide.localPath!),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _buildPlaceholder(slide),
      ),
    );
  }

  Widget _buildVideoSlide(ClmSlide slide, int index) {
    final ctrl = _videoControllers[index];
    if (ctrl == null || !ctrl.value.isInitialized) return _buildLoadingPlaceholder(slide);
    if (index == _currentIndex && !ctrl.value.isPlaying) ctrl.play();

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: ctrl.value.aspectRatio,
            child: VideoPlayer(ctrl),
          ),
        ),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: ctrl,
          builder: (_, value, _) {
            if (!value.isInitialized) return const SizedBox.shrink();
            final progress = value.duration.inMilliseconds > 0
                ? value.position.inMilliseconds / value.duration.inMilliseconds
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 3,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHtmlSlide(ClmSlide slide, int index) {
    if (!_webControllers.containsKey(index)) {
      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadFile(slide.localPath!);
      _webControllers[index] = ctrl;
    }
    return WebViewWidget(controller: _webControllers[index]!);
  }

  Widget _buildPlaceholder(ClmSlide slide) => Container(
        color: Colors.black,
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.download_for_offline_outlined, size: 56, color: Colors.white38),
            const SizedBox(height: 12),
            Text(slide.title.isNotEmpty ? slide.title : 'Slide not downloaded',
                style: const TextStyle(color: Colors.white60, fontSize: 14)),
            const SizedBox(height: 6),
            const Text('Download this brand to view slides',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
      );

  Widget _buildLoadingPlaceholder(ClmSlide slide) => Container(
        color: Colors.black,
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const CircularProgressIndicator(color: Colors.white54),
            const SizedBox(height: 16),
            Text(slide.title, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ]),
        ),
      );

  // ─── Top Overlay ─────────────────────────────────────────────────────────────

  Widget _buildTopOverlay() {
    final slide = widget.slides[_currentIndex];
    final total = widget.slides.length;
    final mins = _elapsedSeconds ~/ 60;
    final secs = _elapsedSeconds % 60;
    final isStarred = _starredSlideIds.contains(slide.id);

    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
          ),
        ),
        child: Row(children: [
          // Close → end session → call report
          _checkingOut
              ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ))
              : _overlayButton(Icons.close, _exitPresentation),
          const SizedBox(width: 8),

          // Doctor + slide title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.doctor.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                Text(
                  slide.title.isNotEmpty ? slide.title : 'Slide ${_currentIndex + 1}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Like/unlike current brand
          Consumer<ClmProvider>(
            builder: (_, prov, child) {
              final currentBrandId = _currentBrandId(prov);
              if (currentBrandId == null) return const SizedBox.shrink();
              final liked = prov.isBrandLiked(currentBrandId);
              return _overlayIconButton(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                () => prov.toggleBrandLike(currentBrandId),
                color: liked ? Colors.pink.shade300 : Colors.white70,
              );
            },
          ),
          const SizedBox(width: 2),

          // Star (like) slide button
          _overlayIconButton(
            isStarred ? Icons.star_rounded : Icons.star_border_rounded,
            _toggleStar,
            color: isStarred ? Colors.amber : Colors.white70,
          ),
          const SizedBox(width: 4),

          // Share button
          _overlayIconButton(Icons.share_outlined, _showShareSheet),
          const SizedBox(width: 8),

          // Session timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(Icons.timer_outlined, color: Colors.white70, size: 12),
              const SizedBox(width: 3),
              Text(
                '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ]),
          ),
          const SizedBox(width: 6),

          // Slide counter
          Text('${_currentIndex + 1}/$total',
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _overlayButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _overlayIconButton(IconData icon, VoidCallback onTap,
      {Color color = Colors.white70}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  // ─── Bottom Overlay ───────────────────────────────────────────────────────────

  Widget _buildBottomOverlay() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProgressDots(),
            const SizedBox(height: 8),
            _buildBrandPills(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDots() {
    final total = widget.slides.length;
    if (total > 20) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: ((_currentIndex + 1) / total).clamp(0.0, 1.0),
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          minHeight: 4,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == _currentIndex;
        final starred = _starredSlideIds.contains(widget.slides[i].id);
        return GestureDetector(
          onTap: () => _goTo(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: starred
                  ? Colors.amber
                  : active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBrandPills() {
    final prov = context.read<ClmProvider>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: prov.cart.map((item) {
          final isCurrentBrand =
              item.slides.any((s) => s.id == widget.slides[_currentIndex].id);
          final isLiked = prov.isBrandLiked(item.brand.id);
          return GestureDetector(
            onTap: () => _jumpToBrand(item),
            onLongPress: () => prov.toggleBrandLike(item.brand.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCurrentBrand
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: isLiked
                    ? Border.all(color: Colors.pink.shade300, width: 1.5)
                    : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isLiked) ...[
                  Icon(Icons.favorite, size: 9, color: isCurrentBrand
                      ? Colors.pink.shade400
                      : Colors.pink.shade300),
                  const SizedBox(width: 3),
                ],
                Text(
                  item.brand.name,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isCurrentBrand ? _purple : Colors.white70,
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  int? _currentBrandId(ClmProvider prov) {
    if (_currentIndex >= widget.slides.length) return null;
    final slideId = widget.slides[_currentIndex].id;
    for (final item in prov.cart) {
      if (item.slides.any((s) => s.id == slideId)) return item.brand.id;
    }
    return null;
  }

  void _jumpToBrand(ClmCartItem item) {
    final firstSlide = item.sortedSlides.isNotEmpty ? item.sortedSlides.first : null;
    if (firstSlide == null) return;
    final idx = widget.slides.indexWhere((s) => s.id == firstSlide.id);
    if (idx >= 0 && idx != _currentIndex) _goTo(idx, skipped: true);
    _showOverlayBriefly();
  }

  Widget _navArrow(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

// ─── Share Sheet ──────────────────────────────────────────────────────────────

class _ShareSheet extends StatelessWidget {
  final String slideTitle;
  final String brandName;
  final String doctorName;
  final String? slideLocalPath;
  final VoidCallback onDismiss;

  const _ShareSheet({
    required this.slideTitle,
    required this.brandName,
    required this.doctorName,
    required this.slideLocalPath,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Share Content',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text('$brandName · $slideTitle',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 20),
          Row(children: [
            _shareOption(
              context,
              icon: Icons.messenger_outlined,
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () => _shareWhatsApp(context),
            ),
            const SizedBox(width: 12),
            _shareOption(
              context,
              icon: Icons.email_outlined,
              label: 'Email',
              color: Colors.blue.shade600,
              onTap: () => _shareEmail(context),
            ),
            const SizedBox(width: 12),
            _shareOption(
              context,
              icon: Icons.share_outlined,
              label: 'Share',
              color: Colors.grey.shade700,
              onTap: () => _shareGeneral(context),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200)),
            child: Row(children: [
              Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sharing is subject to company content-sharing policy. '
                  'Only approved materials may be shared with healthcare professionals.',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _shareOption(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ]),
        ),
      ),
    );
  }

  String get _shareText =>
      'Hi Dr. $doctorName,\n\nPlease find the information about *$brandName* – $slideTitle.\n\nRegards';

  void _shareWhatsApp(BuildContext context) {
    final encoded = Uri.encodeComponent(_shareText);
    launchUrl(
      Uri.parse('https://wa.me/?text=$encoded'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _shareEmail(BuildContext context) {
    final subject = Uri.encodeComponent('$brandName – $slideTitle');
    final body = Uri.encodeComponent(_shareText);
    launchUrl(Uri.parse('mailto:?subject=$subject&body=$body'));
  }

  void _shareGeneral(BuildContext context) {
    if (slideLocalPath != null) {
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(slideLocalPath!)],
          text: _shareText,
          subject: '$brandName – $slideTitle',
        ),
      );
    } else {
      SharePlus.instance.share(
        ShareParams(text: _shareText, subject: '$brandName – $slideTitle'),
      );
    }
  }
}
