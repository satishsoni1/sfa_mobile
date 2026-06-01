import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../data/models/clm_models.dart';
import '../../data/services/clm_geo_service.dart';
import '../../providers/clm_provider.dart';
import 'clm_ai_cart_screen.dart';
import 'clm_doctor_locations_screen.dart';

class ClmCheckInScreen extends StatefulWidget {
  final ClmDoctor doctor;
  const ClmCheckInScreen({super.key, required this.doctor});

  @override
  State<ClmCheckInScreen> createState() => _ClmCheckInScreenState();
}

class _ClmCheckInScreenState extends State<ClmCheckInScreen>
    with TickerProviderStateMixin {
  static const _purple = Color(0xFF4A148C);
  static const _green = Color(0xFF2E7D32);
  static const _red = Color(0xFFC62828);

  final _geo = ClmGeoService();

  List<DoctorLocation> _taggedLocations = [];
  DoctorLocation? _nearestLocation;

  StreamSubscription<Position>? _posSub;
  Position? _currentPos;
  double? _distanceMeters;
  bool _permDenied = false;
  bool _locating = true;
  bool _checkingIn = false;

  // Radar pulse animation
  late AnimationController _radarCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _loadTaggedLocations();
    _startTracking();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _radarCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTaggedLocations() async {
    final locs = await context.read<ClmProvider>().getLocationsForDoctor(widget.doctor.id);
    if (!mounted) return;
    setState(() {
      _taggedLocations = locs;
      // Recompute nearest if position already known
      if (_currentPos != null) _recalcNearest(_currentPos!);
    });
  }

  void _recalcNearest(Position p) {
    if (_taggedLocations.isEmpty) {
      _nearestLocation = null;
      _distanceMeters = null;
      return;
    }
    DoctorLocation nearest = _taggedLocations.first;
    double minDist = _geo.distanceBetween(
        p.latitude, p.longitude, nearest.latitude, nearest.longitude);
    for (final loc in _taggedLocations.skip(1)) {
      final d = _geo.distanceBetween(p.latitude, p.longitude, loc.latitude, loc.longitude);
      if (d < minDist) {
        minDist = d;
        nearest = loc;
      }
    }
    _nearestLocation = nearest;
    _distanceMeters = minDist;
  }

  Future<void> _startTracking() async {
    final perm = await _geo.requestPermission();
    if (!mounted) return;

    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      setState(() {
        _permDenied = true;
        _locating = false;
      });
      return;
    }

    // Fetch first position immediately
    final pos = await _geo.getCurrentPosition();
    if (!mounted) return;
    if (pos != null) _updatePosition(pos);
    setState(() => _locating = false);

    // Then stream updates
    _posSub = _geo.getPositionStream().listen((p) {
      if (mounted) _updatePosition(p);
    });
  }

  void _updatePosition(Position p) {
    _currentPos = p;
    _recalcNearest(p);
    setState(() {});
  }

  bool get _withinRange {
    if (_distanceMeters == null) return false;
    return _distanceMeters! <= ClmGeoService.kDefaultRadiusMeters;
  }

  bool get _doctorHasLocation => _taggedLocations.isNotEmpty;

  Future<void> _checkIn() async {
    setState(() => _checkingIn = true);
    final prov = context.read<ClmProvider>();
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: ClmAiCartScreen(
            doctor: widget.doctor,
            checkInPosition: _currentPos,
          ),
        ),
      ),
    );
  }

  Future<void> _demoOverride() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Demo Override',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: const Text(
            'Skip geo-fence check for demo/testing purposes?\n\n'
            'In production, this button is hidden.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _purple),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Override', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _checkIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text('Doctor Check-In',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: 'Manage Locations',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<ClmProvider>(),
                    child: ClmDoctorLocationsScreen(doctor: widget.doctor),
                  ),
                ),
              );
              // Reload locations when returning
              if (mounted) await _loadTaggedLocations();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDoctorCard(),
          Expanded(child: _buildRadarSection()),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ─── Doctor Card ──────────────────────────────────────────────────────────────

  Widget _buildDoctorCard() {
    final d = widget.doctor;
    return Container(
      color: _purple,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: Text(d.initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            Text('${d.speciality}  ·  ${d.category} Category',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (d.hospital != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.location_city_outlined,
                    color: Colors.white54, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(d.hospital!,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  // ─── Radar Section ────────────────────────────────────────────────────────────

  Widget _buildRadarSection() {
    if (_permDenied) return _buildPermDenied();
    if (_locating) return _buildLocating();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRadarWidget(),
          const SizedBox(height: 28),
          _buildDistanceDisplay(),
          const SizedBox(height: 12),
          _buildStatusText(),
        ],
      ),
    );
  }

  Widget _buildRadarWidget() {
    final size = 220.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple rings
          AnimatedBuilder(
            animation: _radarCtrl,
            builder: (context2, child2) {
              return Stack(
                alignment: Alignment.center,
                children: [0.0, 0.33, 0.66].map((offset) {
                  final progress =
                      (_radarCtrl.value + offset) % 1.0;
                  return Opacity(
                    opacity: (1.0 - progress).clamp(0.0, 0.6),
                    child: Container(
                      width: size * progress,
                      height: size * progress,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _withinRange ? _green : _purple,
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          // Static range ring at 50 m
          Container(
            width: size * 0.7,
            height: size * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: (_withinRange ? _green : Colors.grey.shade400)
                    .withValues(alpha: 0.4),
                width: 1,
                strokeAlign: BorderSide.strokeAlignCenter,
              ),
            ),
          ),
          // Centre dot (user)
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context3, child3) => Container(
              width: 20 + _pulseCtrl.value * 6,
              height: 20 + _pulseCtrl.value * 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_withinRange ? _green : _purple)
                    .withValues(alpha: 0.15 + _pulseCtrl.value * 0.15),
              ),
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _withinRange ? _green : _purple,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 10),
          ),
          // Doctor marker
          if (_distanceMeters != null)
            _DoctorMarker(
              distanceMeters: _distanceMeters!,
              radiusSize: size,
              withinRange: _withinRange,
            ),
        ],
      ),
    );
  }

  Widget _buildDistanceDisplay() {
    if (!_doctorHasLocation) {
      return _infoChip(
          Icons.location_off_outlined, 'No locations tagged', Colors.grey);
    }
    if (_distanceMeters == null) {
      return _infoChip(
          Icons.gps_not_fixed, 'Acquiring GPS…', Colors.blueGrey);
    }
    final color = _withinRange ? _green : _red;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text(
          _geo.formatDistance(_distanceMeters!),
          style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        Text(
          'from ${_nearestLocation?.label ?? widget.doctor.name}',
          style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7)),
        ),
      ]),
    );
  }

  Widget _buildStatusText() {
    if (!_doctorHasLocation) {
      return const Text(
          'No locations tagged for this doctor.\nTag a location or use demo override.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey));
    }
    if (_distanceMeters == null) {
      return Text('Locating you…',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500));
    }
    return Text(
      _withinRange
          ? 'You are within 50 m — ready to check in!'
          : 'Move within ${ClmGeoService.kDefaultRadiusMeters.round()} m of the tagged location to check in.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        color: _withinRange ? _green : Colors.grey.shade600,
        fontWeight: _withinRange ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildLocating() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text('Acquiring location…',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      ]),
    );
  }

  Widget _buildPermDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.location_off, size: 56, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text('Location Permission Required',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 16),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Please enable location permissions in app settings to use geo-fencing check-in.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Geolocator.openAppSettings(),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(backgroundColor: _purple,
                foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: color, fontSize: 13)),
      ]),
    );
  }

  // ─── Bottom Bar ───────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: (_withinRange || !_doctorHasLocation) && !_checkingIn
                ? _checkIn
                : null,
            icon: _checkingIn
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _checkingIn
                  ? 'Starting…'
                  : _withinRange
                      ? 'Check In & Start Detailing'
                      : 'Too Far Away',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _withinRange || !_doctorHasLocation ? _green : Colors.grey.shade300,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _demoOverride,
          child: Text('Demo Override (testing only)',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  decoration: TextDecoration.underline)),
        ),
      ]),
    );
  }
}

// ─── Doctor Marker Positioned on Radar ───────────────────────────────────────

class _DoctorMarker extends StatelessWidget {
  final double distanceMeters;
  final double radiusSize;
  final bool withinRange;

  const _DoctorMarker({
    required this.distanceMeters,
    required this.radiusSize,
    required this.withinRange,
  });

  @override
  Widget build(BuildContext context) {
    // Map distance to radar canvas: 50 m = 35% of radar radius
    // Beyond 50 m clamp to edge of ring
    const maxRadarRadius = 0.85;
    final frac = (distanceMeters / ClmGeoService.kDefaultRadiusMeters).clamp(0.0, maxRadarRadius);
    final angle = -math.pi / 4; // fixed NE direction for visual
    final offsetX = (radiusSize / 2) * frac * math.cos(angle);
    final offsetY = (radiusSize / 2) * frac * math.sin(angle);

    return Transform.translate(
      offset: Offset(offsetX, offsetY),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: withinRange ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: (withinRange
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828))
                  .withValues(alpha: 0.5),
              blurRadius: 6,
            )
          ],
        ),
        child: const Icon(Icons.medical_services_outlined,
            color: Colors.white, size: 10),
      ),
    );
  }
}
