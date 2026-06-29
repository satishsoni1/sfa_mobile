import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/models/data_bank_models.dart';
import '../../providers/data_bank_provider.dart';

class DataBankViewerScreen extends StatefulWidget {
  final DataBankMaterial material;
  const DataBankViewerScreen({super.key, required this.material});

  @override
  State<DataBankViewerScreen> createState() => _DataBankViewerScreenState();
}

class _DataBankViewerScreenState extends State<DataBankViewerScreen> {
  static const _purple = Color(0xFF4A148C);

  // ─── Analytics tracking ───────────────────────────────────────────────────────
  String? _logId;
  final _stopwatch = Stopwatch();
  Timer? _heartbeat;
  bool _markedComplete = false;

  // ─── Video ────────────────────────────────────────────────────────────────────
  VideoPlayerController? _videoCtrl;
  bool _videoInitialized = false;
  bool _videoError = false;

  // ─── WebView (PDF / link) ─────────────────────────────────────────────────────
  WebViewController? _webCtrl;
  bool _webLoading = true;

  // ─── UI state ─────────────────────────────────────────────────────────────────
  bool _showControls = true;
  Timer? _hideCtrlTimer;

  DataBankMaterial get _m => widget.material;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final prov = context.read<DataBankProvider>();
    _logId = await prov.startView(_m.id);
    _stopwatch.start();

    // Heartbeat every 30s to save progress
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) => _saveProgress());

    switch (_m.type) {
      case DataBankMaterialType.video:
        await _initVideo();
        break;
      case DataBankMaterialType.pdf:
      case DataBankMaterialType.link:
        _initWebView();
        break;
      case DataBankMaterialType.image:
        break;
    }
  }

  Future<void> _initVideo() async {
    try {
      // Use local file if downloaded, else stream from network
      final VideoPlayerController ctrl;
      if (_m.isDownloaded && _m.localPath != null) {
        ctrl = VideoPlayerController.file(File(_m.localPath!));
      } else {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(_m.sourceUrl));
      }
      await ctrl.initialize();
      ctrl.addListener(_onVideoProgress);
      setState(() {
        _videoCtrl = ctrl;
        _videoInitialized = true;
      });
    } catch (_) {
      setState(() => _videoError = true);
    }
  }

  void _initWebView() {
    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _webLoading = false),
        onWebResourceError: (_) => setState(() => _webLoading = false),
      ));

    // Offline-first: load from local file if downloaded
    if (_m.isDownloaded && _m.localPath != null) {
      ctrl.loadFile(_m.localPath!);
    } else {
      ctrl.loadRequest(Uri.parse(_m.sourceUrl));
    }

    setState(() => _webCtrl = ctrl);
  }

  void _onVideoProgress() {
    if (_videoCtrl == null || !_videoCtrl!.value.isInitialized) return;
    final total = _videoCtrl!.value.duration.inSeconds;
    final current = _videoCtrl!.value.position.inSeconds;
    if (total > 0 && current / total >= 0.85 && !_markedComplete) {
      _markComplete();
    }
  }

  Future<void> _saveProgress() async {
    if (_logId == null || !mounted) return;
    final secs = _stopwatch.elapsed.inSeconds;
    await context.read<DataBankProvider>().updateView(_logId!, secs, _markedComplete);
  }

  Future<void> _markComplete() async {
    if (_markedComplete) return;
    _markedComplete = true;
    await _saveProgress();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white),
          SizedBox(width: 8),
          Text('Marked as complete!'),
        ]),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _heartbeat?.cancel();
    _hideCtrlTimer?.cancel();
    _saveProgress();
    _videoCtrl?.removeListener(_onVideoProgress);
    _videoCtrl?.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Content area
            _buildContent(),

            // Overlay controls
            if (_showControls || _m.type != DataBankMaterialType.video)
              _buildTopBar(),

            // Bottom info panel (non-video)
            if (_m.type != DataBankMaterialType.video)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _buildInfoPanel(),
              ),

            // Video overlay controls
            if (_m.type == DataBankMaterialType.video && _videoInitialized)
              GestureDetector(
                onTap: _toggleVideoControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: _buildVideoControls(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Content ──────────────────────────────────────────────────────────────────

  Widget _buildContent() {
    switch (_m.type) {
      case DataBankMaterialType.video:
        return _buildVideoPlayer();
      case DataBankMaterialType.pdf:
      case DataBankMaterialType.link:
        return _buildWebView();
      case DataBankMaterialType.image:
        return _buildImageViewer();
    }
  }

  Widget _buildVideoPlayer() {
    if (_videoError) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.videocam_off_outlined,
              size: 56, color: Colors.white54),
          const SizedBox(height: 16),
          const Text('Unable to load video',
              style: TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => launchUrl(Uri.parse(_m.sourceUrl)),
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open in Browser'),
            style: ElevatedButton.styleFrom(backgroundColor: _purple,
                foregroundColor: Colors.white),
          ),
        ]),
      );
    }
    if (!_videoInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: _toggleVideoControls,
      child: Center(
        child: AspectRatio(
          aspectRatio: _videoCtrl!.value.aspectRatio,
          child: VideoPlayer(_videoCtrl!),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return Stack(children: [
      if (_webCtrl != null)
        Positioned.fill(child: WebViewWidget(controller: _webCtrl!)),
      if (_webLoading)
        const Positioned.fill(
          child: ColoredBox(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
    ]);
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          _m.sourceUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.broken_image_outlined,
                size: 64, color: Colors.white54),
          ),
        ),
      ),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              _m.title,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600,
                  fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          // Bookmark
          Consumer<DataBankProvider>(
            builder: (_, prov, _) => IconButton(
              icon: Icon(
                _m.isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: _m.isBookmarked ? Colors.amber : Colors.white,
              ),
              onPressed: () => prov.toggleBookmark(_m),
            ),
          ),
          // Open externally
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
            onPressed: () => launchUrl(Uri.parse(_m.sourceUrl),
                mode: LaunchMode.externalApplication),
          ),
        ]),
      ),
    );
  }

  // ─── Video Controls ───────────────────────────────────────────────────────────

  Widget _buildVideoControls() {
    if (_videoCtrl == null) return const SizedBox.shrink();
    final pos = _videoCtrl!.value.position;
    final dur = _videoCtrl!.value.duration;
    final isPlaying = _videoCtrl!.value.isPlaying;

    return Container(
      color: Colors.transparent,
      child: Column(children: [
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Progress slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
              ),
              child: Slider(
                value: pos.inSeconds.toDouble().clamp(0, dur.inSeconds.toDouble()),
                max: dur.inSeconds.toDouble(),
                onChanged: (v) =>
                    _videoCtrl!.seekTo(Duration(seconds: v.toInt())),
              ),
            ),
            Row(children: [
              Text(_fmtDuration(pos),
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              const Spacer(),
              Text(_fmtDuration(dur),
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
            const SizedBox(height: 8),
            // Play controls
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                icon: const Icon(Icons.replay_10_rounded,
                    color: Colors.white, size: 28),
                onPressed: () => _videoCtrl!.seekTo(
                    pos - const Duration(seconds: 10)),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  if (isPlaying) { _videoCtrl!.pause(); }
                  else { _videoCtrl!.play(); }
                  setState(() {});
                },
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_10_rounded,
                    color: Colors.white, size: 28),
                onPressed: () => _videoCtrl!.seekTo(
                    pos + const Duration(seconds: 10)),
              ),
            ]),
            const SizedBox(height: 8),
            // Mark complete button
            if (!_markedComplete)
              TextButton.icon(
                onPressed: _markComplete,
                icon: const Icon(Icons.check_circle_outline_rounded,
                    color: Colors.white70, size: 16),
                label: const Text('Mark as Complete',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              )
            else
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 16),
                const SizedBox(width: 6),
                Text('Completed',
                    style: TextStyle(
                        color: Colors.green.shade300, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
          ]),
        ),
      ]),
    );
  }

  void _toggleVideoControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _hideCtrlTimer?.cancel();
      _hideCtrlTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _videoCtrl?.value.isPlaying == true) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  // ─── Info Panel (non-video) ───────────────────────────────────────────────────

  Widget _buildInfoPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12, offset: const Offset(0, -4))
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_m.title,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Icon(_m.type.icon, size: 12, color: _m.type.color),
                const SizedBox(width: 4),
                Text(_m.type.label,
                    style: TextStyle(fontSize: 11, color: _m.type.color,
                        fontWeight: FontWeight.w600)),
                if (_m.fileSizeLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(_m.fileSizeLabel,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ]),
            ]),
          ),
          // Mark complete / Done badge
          if (!_markedComplete)
            ElevatedButton.icon(
              onPressed: _markComplete,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Done', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade300)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: Colors.green),
                const SizedBox(width: 5),
                Text('Completed',
                    style: TextStyle(
                        fontSize: 12, color: Colors.green.shade700,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
        // Tags
        if (_m.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 4,
            children: _m.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(tag,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade600)),
                )).toList(),
          ),
        ],
      ]),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }
}
