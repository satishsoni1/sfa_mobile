import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/clm_models.dart';
import 'clm_database_service.dart';

class ClmSyncService {
  static final ClmSyncService _instance = ClmSyncService._();
  factory ClmSyncService() => _instance;
  ClmSyncService._();

  static const String _baseUrl = 'https://zorvia.globalspace.in/api';
  static const String _prefLastSync = 'clm_last_master_sync';

  final ClmDatabaseService _db = ClmDatabaseService();
  final _statusController = StreamController<ClmSyncStatus>.broadcast();

  Stream<ClmSyncStatus> get statusStream => _statusController.stream;

  ClmSyncStatus _status = const ClmSyncStatus();
  ClmSyncStatus get currentStatus => _status;

  bool _isSyncing = false;

  void _emit(ClmSyncStatus s) {
    _status = s;
    _statusController.add(s);
  }

  // ─── Auth Token ──────────────────────────────────────────────────────────────

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  // ─── Network Check ────────────────────────────────────────────────────────────

  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ─── Master Sync ──────────────────────────────────────────────────────────────

  /// Downloads doctors, brands, and slide metadata from the server.
  Future<bool> syncMasterData({bool forceFullSync = false}) async {
    if (_isSyncing) return false;
    if (!await isOnline()) {
      _emit(_status.copyWith(
          state: SyncState.error, message: 'No internet connection'));
      return false;
    }

    _isSyncing = true;
    _emit(const ClmSyncStatus(state: SyncState.syncing, message: 'Syncing master data…', progress: 0.05));

    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      // 1. Doctors
      _emit(_status.copyWith(message: 'Downloading doctors…', progress: 0.1));
      await _syncDoctors(token);

      // 2. Brands
      _emit(_status.copyWith(message: 'Downloading brands…', progress: 0.35));
      await _syncBrands(token);

      // 3. Slides metadata
      _emit(_status.copyWith(message: 'Downloading slide index…', progress: 0.6));
      await _syncSlideMetadata(token);

      // 4. Save sync timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefLastSync, DateTime.now().toIso8601String());

      final pending = await _db.getPendingUploadsCount();
      _emit(ClmSyncStatus(
        state: SyncState.success,
        message: 'Master sync complete',
        progress: 1.0,
        lastSyncAt: DateTime.now(),
        pendingUploads: pending,
      ));
      return true;
    } catch (e) {
      _emit(_status.copyWith(
          state: SyncState.error, message: 'Sync failed: ${e.toString()}'));
      debugPrint('[CLM Sync] Master sync error: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncDoctors(String token) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/clm/doctors'),
      headers: _headers(token),
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) return;
    final body = json.decode(res.body);
    final list = (body['data'] ?? body) as List;
    final doctors = list
        .cast<Map<String, dynamic>>()
        .map(ClmDoctor.fromJson)
        .toList();
    await _db.upsertDoctors(doctors);
  }

  Future<void> _syncBrands(String token) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/clm/brands'),
      headers: _headers(token),
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) return;
    final body = json.decode(res.body);
    final list = (body['data'] ?? body) as List;
    final brands =
        list.cast<Map<String, dynamic>>().map(ClmBrand.fromJson).toList();
    await _db.upsertBrands(brands);
  }

  Future<void> _syncSlideMetadata(String token) async {
    final brands = await _db.getAllBrands();
    for (final brand in brands) {
      try {
        final res = await http.get(
          Uri.parse('$_baseUrl/clm/brands/${brand.id}/slides'),
          headers: _headers(token),
        ).timeout(const Duration(seconds: 20));

        if (res.statusCode != 200) continue;
        final body = json.decode(res.body);
        final list = (body['data'] ?? body) as List;
        final slides =
            list.cast<Map<String, dynamic>>().map(ClmSlide.fromJson).toList();
        await _db.upsertSlides(slides);
      } catch (_) {
        continue;
      }
    }
  }

  // ─── Media Download ──────────────────────────────────────────────────────────

  /// Downloads all media for a specific brand. Reports per-slide progress.
  Future<void> downloadBrandMedia(
    int brandId, {
    ValueChanged<double>? onProgress,
  }) async {
    if (!await isOnline()) return;

    final token = await _getToken();
    if (token == null) return;

    final slides = await _db.getSlidesForBrand(brandId);
    final pending = slides.where((s) => !s.isDownloaded).toList();
    if (pending.isEmpty) {
      await _db.updateBrandDownloadProgress(brandId, 1.0, true);
      onProgress?.call(1.0);
      return;
    }

    final mediaDir = await _getMediaDirectory();
    final brandDir = Directory(p.join(mediaDir.path, 'brand_$brandId'));
    await brandDir.create(recursive: true);

    int done = 0;
    for (final slide in pending) {
      try {
        await _downloadSlide(slide, brandDir, token);
        done++;
        final progress = done / pending.length;
        onProgress?.call(progress);
        await _db.updateBrandDownloadProgress(
            brandId, progress, done == pending.length);
      } catch (e) {
        debugPrint('[CLM Sync] Slide download failed: ${slide.id} – $e');
      }
    }
  }

  Future<void> _downloadSlide(
      ClmSlide slide, Directory brandDir, String token) async {
    final url = slide.remoteUrl;
    if (url == null || url.isEmpty) return;

    final ext = _extensionFromUrl(url, slide.type);
    final filename = 'slide_${slide.id}$ext';
    final filePath = p.join(brandDir.path, filename);

    final file = File(filePath);
    if (file.existsSync()) {
      // Already on disk — mark downloaded
      await _db.updateSlideDownloaded(slide.id, filePath, slide.checksum);
      return;
    }

    final res = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(minutes: 5));

    if (res.statusCode == 200) {
      await file.writeAsBytes(res.bodyBytes);
      await _db.updateSlideDownloaded(slide.id, filePath, slide.checksum);
    }
  }

  String _extensionFromUrl(String url, String type) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path;
      final ext = p.extension(path);
      if (ext.isNotEmpty) return ext;
    }
    switch (type) {
      case 'video':
        return '.mp4';
      case 'html':
        return '.zip';
      default:
        return '.jpg';
    }
  }

  Future<Directory> _getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'clm', 'media'));
    await dir.create(recursive: true);
    return dir;
  }

  // ─── Upload Analytics ────────────────────────────────────────────────────────

  Future<bool> uploadPendingAnalytics() async {
    if (!await isOnline()) return false;

    final token = await _getToken();
    if (token == null) return false;

    // Sessions
    final sessions = await _db.getUnsyncedSessions();
    if (sessions.isNotEmpty) {
      try {
        final payload = sessions.map((s) => s.toSyncJson()).toList();
        final res = await http.post(
          Uri.parse('$_baseUrl/clm/sync/sessions'),
          headers: _headers(token),
          body: json.encode({'sessions': payload}),
        ).timeout(const Duration(seconds: 30));

        if (res.statusCode == 200 || res.statusCode == 201) {
          await _db.markSessionsSynced(sessions.map((s) => s.id).toList());
        }
      } catch (e) {
        debugPrint('[CLM Sync] Session upload error: $e');
      }
    }

    // Analytics events
    final events = await _db.getUnsyncedAnalytics();
    if (events.isNotEmpty) {
      try {
        final payload = events.map((e) => e.toSyncJson()).toList();
        final res = await http.post(
          Uri.parse('$_baseUrl/clm/sync/analytics'),
          headers: _headers(token),
          body: json.encode({'events': payload}),
        ).timeout(const Duration(seconds: 30));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final ids = events
              .where((e) => e.dbId != null)
              .map((e) => e.dbId!)
              .toList();
          await _db.markAnalyticsSynced(ids);
        }
      } catch (e) {
        debugPrint('[CLM Sync] Analytics upload error: $e');
      }
    }

    final remaining = await _db.getPendingUploadsCount();
    _emit(_status.copyWith(
      state: SyncState.success,
      message: remaining == 0 ? 'All data synced' : '$remaining sessions pending',
      pendingUploads: remaining,
      lastSyncAt: DateTime.now(),
    ));
    return true;
  }

  // ─── Full Sync ────────────────────────────────────────────────────────────────

  Future<void> fullSync() async {
    await syncMasterData();
    await uploadPendingAnalytics();
  }

  // ─── Last Sync Timestamp ──────────────────────────────────────────────────────

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_prefLastSync);
    return s != null ? DateTime.tryParse(s) : null;
  }

  void dispose() {
    _statusController.close();
  }
}
