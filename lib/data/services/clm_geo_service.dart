import 'dart:async';

import 'package:geolocator/geolocator.dart';

class ClmGeoService {
  static const double kDefaultRadiusMeters = 50.0;

  static final ClmGeoService _instance = ClmGeoService._();
  factory ClmGeoService() => _instance;
  ClmGeoService._();

  // ─── Permissions ─────────────────────────────────────────────────────────────

  Future<LocationPermission> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermission.denied;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm;
  }

  Future<bool> get hasPermission async {
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  // ─── Current Position ─────────────────────────────────────────────────────────

  Future<Position?> getCurrentPosition() async {
    final perm = await requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Position Stream ──────────────────────────────────────────────────────────

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    );
  }

  // ─── Distance ─────────────────────────────────────────────────────────────────

  double distanceBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

  bool isWithinRadius(
    double userLat,
    double userLng,
    double docLat,
    double docLng, {
    double radiusMeters = kDefaultRadiusMeters,
  }) {
    final dist = distanceBetween(userLat, userLng, docLat, docLng);
    return dist <= radiusMeters;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
