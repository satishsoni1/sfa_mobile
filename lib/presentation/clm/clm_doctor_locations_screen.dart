import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../data/models/clm_models.dart';
import '../../data/services/clm_geo_service.dart';
import '../../providers/clm_provider.dart';

class ClmDoctorLocationsScreen extends StatefulWidget {
  final ClmDoctor doctor;
  const ClmDoctorLocationsScreen({super.key, required this.doctor});

  @override
  State<ClmDoctorLocationsScreen> createState() =>
      _ClmDoctorLocationsScreenState();
}

class _ClmDoctorLocationsScreenState extends State<ClmDoctorLocationsScreen> {
  static const _purple = Color(0xFF4A148C);
  static const int _maxLocations = 3;

  final _geo = ClmGeoService();

  List<DoctorLocation> _locations = [];
  Position? _currentPos;
  bool _loadingLocations = true;
  bool _tagging = false;
  StreamSubscription<Position>? _posSub;

  @override
  void initState() {
    super.initState();
    _load();
    _startPositionStream();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prov = context.read<ClmProvider>();
    final locs = await prov.getLocationsForDoctor(widget.doctor.id);
    if (!mounted) return;
    setState(() {
      _locations = locs;
      _loadingLocations = false;
    });
  }

  Future<void> _startPositionStream() async {
    final perm = await _geo.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;
    final pos = await _geo.getCurrentPosition();
    if (mounted && pos != null) { setState(() => _currentPos = pos); }
    _posSub = _geo.getPositionStream().listen((p) {
      if (mounted) setState(() => _currentPos = p);
    });
  }

  Future<void> _tagCurrentLocation() async {
    if (_locations.length >= _maxLocations) return;

    setState(() => _tagging = true);
    final pos = await _geo.getCurrentPosition();
    setState(() => _tagging = false);

    if (!mounted) return;
    if (pos == null) {
      _showSnack('Could not get GPS position. Try again.');
      return;
    }

    // Default label
    final defaultLabel = 'Location ${_locations.length + 1}';
    final label = await _showLabelDialog(defaultLabel);
    if (!mounted || label == null) return;

    final loc = DoctorLocation(
      doctorId: widget.doctor.id,
      label: label.trim().isEmpty ? defaultLabel : label.trim(),
      latitude: pos.latitude,
      longitude: pos.longitude,
      capturedAt: DateTime.now(),
    );

    final prov = context.read<ClmProvider>();
    final added = await prov.addDoctorLocation(loc);
    if (!mounted) return;

    if (!added) {
      _showSnack('Maximum $_maxLocations locations already tagged.');
      return;
    }
    _showSnack('Location tagged successfully.');
    await _load();
  }

  Future<String?> _showLabelDialog(String defaultLabel) async {
    final ctrl = TextEditingController(text: defaultLabel);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Location Label',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Clinic, Hospital, Home',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editLabel(DoctorLocation loc) async {
    final ctrl = TextEditingController(text: loc.label);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Rename Location',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _purple, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    final trimmed = result.trim();
    if (trimmed.isEmpty || trimmed == loc.label) return;
    await context.read<ClmProvider>().updateDoctorLocationLabel(loc.id!, trimmed);
    await _load();
  }

  Future<void> _delete(DoctorLocation loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Location',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Remove "${loc.label}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<ClmProvider>().deleteDoctorLocation(loc.id!);
    await _load();
    if (mounted) _showSnack('"${loc.label}" removed.');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text('Tagged Locations',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildDoctorHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildDoctorHeader() {
    final d = widget.doctor;
    return Container(
      color: _purple,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: Text(d.initials,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            Text('${d.speciality}  ·  ${d.hospital ?? d.area}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        // Slot counter pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_locations.length} / $_maxLocations',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loadingLocations) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_locations.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _locations.length,
      itemBuilder: (_, i) => _buildLocationCard(_locations[i], i),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.location_off_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text('No Locations Tagged',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          Text(
            'Tap the + button below to tag your current GPS position for this doctor.\nUp to $_maxLocations locations can be saved.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ]),
      ),
    );
  }

  Widget _buildLocationCard(DoctorLocation loc, int index) {
    final distLabel = _currentPos != null
        ? _geo.formatDistance(_geo.distanceBetween(
            _currentPos!.latitude, _currentPos!.longitude,
            loc.latitude, loc.longitude))
        : null;

    final withinRange = _currentPos != null &&
        _geo.isWithinRadius(
            _currentPos!.latitude, _currentPos!.longitude,
            loc.latitude, loc.longitude);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: withinRange
              ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: withinRange ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Index badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                  color: _purple,
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(loc.label,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                if (withinRange)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('In Range',
                        style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(
                '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.access_time_outlined, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(_formatDate(loc.capturedAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                if (distLabel != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.near_me_outlined, size: 12,
                      color: withinRange
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(distLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: withinRange
                              ? const Color(0xFF2E7D32)
                              : Colors.grey.shade600)),
                ],
              ]),
            ]),
          ),
          // Actions
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade500),
            tooltip: 'Rename',
            onPressed: () => _editLabel(loc),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: 'Delete',
            onPressed: () => _delete(loc),
          ),
        ]),
      ),
    );
  }

  Widget _buildFab() {
    final canAdd = _locations.length < _maxLocations;
    return FloatingActionButton.extended(
      onPressed: canAdd && !_tagging ? _tagCurrentLocation : null,
      backgroundColor: canAdd ? _purple : Colors.grey.shade300,
      foregroundColor: Colors.white,
      icon: _tagging
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.add_location_alt_outlined),
      label: Text(
        _tagging
            ? 'Getting GPS…'
            : canAdd
                ? 'Tag Current Location'
                : 'Max Locations Reached',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }
}
