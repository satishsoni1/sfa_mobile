import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/clm_models.dart';
import 'clm_database_service.dart';

class ClmAnalyticsService {
  static final ClmAnalyticsService _instance = ClmAnalyticsService._();
  factory ClmAnalyticsService() => _instance;
  ClmAnalyticsService._();

  final ClmDatabaseService _db = ClmDatabaseService();
  static const _uuid = Uuid();

  // Active slide tracking
  final Map<int, DateTime> _slideStartMap = {};

  // ─── Session Management ───────────────────────────────────────────────────────

  Future<ClmSession> createSession({
    required ClmDoctor doctor,
    required List<int> brandIds,
    String? latitude,
    String? longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final employeeCode = prefs.getString('employee_code') ?? '';
    final deviceInfo = 'Flutter/Android';

    final session = ClmSession(
      id: _uuid.v4(),
      doctorId: doctor.id,
      doctorName: doctor.name,
      mrEmployeeCode: employeeCode,
      startTime: DateTime.now(),
      brandIds: brandIds,
      isSynced: false,
      latitude: latitude,
      longitude: longitude,
      deviceInfo: deviceInfo,
    );

    await _db.insertSession(session);
    return session;
  }

  Future<void> endSession(String sessionId) async {
    final endTime = DateTime.now();
    await _db.updateSessionEnd(sessionId, endTime);
  }

  // ─── Slide Tracking ───────────────────────────────────────────────────────────

  void markSlideEntered(int slideId) {
    _slideStartMap[slideId] = DateTime.now();
  }

  Future<void> markSlideExited(
    String sessionId,
    ClmSlide slide, {
    bool skipped = false,
  }) async {
    final start = _slideStartMap.remove(slide.id);
    final now = DateTime.now();
    final duration = start != null ? now.difference(start).inSeconds : 0;

    await _db.insertAnalyticsEvent(ClmAnalyticsEvent(
      sessionId: sessionId,
      slideId: slide.id,
      brandId: slide.brandId,
      eventType: skipped ? 'skip' : 'slide_view',
      timestamp: now,
      durationSecs: duration,
    ));
  }

  Future<void> recordTap(
      String sessionId, ClmSlide slide, String tapType) async {
    await _db.insertAnalyticsEvent(ClmAnalyticsEvent(
      sessionId: sessionId,
      slideId: slide.id,
      brandId: slide.brandId,
      eventType: 'tap_$tapType',
      timestamp: DateTime.now(),
    ));
  }

  Future<void> recordVideoComplete(
      String sessionId, ClmSlide slide) async {
    await _db.insertAnalyticsEvent(ClmAnalyticsEvent(
      sessionId: sessionId,
      slideId: slide.id,
      brandId: slide.brandId,
      eventType: 'video_complete',
      timestamp: DateTime.now(),
      durationSecs: slide.durationSecs,
    ));
  }

  // ─── Batch Flush ──────────────────────────────────────────────────────────────

  /// Call on session end to flush any open slide timers.
  Future<void> flushOpenSlides(String sessionId, List<ClmSlide> slides) async {
    final events = <ClmAnalyticsEvent>[];
    final now = DateTime.now();

    for (final entry in _slideStartMap.entries) {
      final slide = slides.firstWhere(
        (s) => s.id == entry.key,
        orElse: () => ClmSlide(
            id: entry.key,
            brandId: 0,
            type: 'image',
            title: '',
            sequence: 0),
      );
      final duration = now.difference(entry.value).inSeconds;
      events.add(ClmAnalyticsEvent(
        sessionId: sessionId,
        slideId: slide.id,
        brandId: slide.brandId,
        eventType: 'slide_view',
        timestamp: now,
        durationSecs: duration,
      ));
    }
    _slideStartMap.clear();

    if (events.isNotEmpty) {
      await _db.insertAnalyticsBatch(events);
    }
  }

  // ─── Stats Queries ────────────────────────────────────────────────────────────

  Future<ClmDoctorStats> getDoctorStats(int doctorId) =>
      _db.getDoctorStats(doctorId);

  Future<Map<int, int>> getSessionSlideTimings(String sessionId) =>
      _db.getSlideSecondsForSession(sessionId);

  Future<Map<String, int>> getTodaySummary(String employeeCode) =>
      _db.getTodaySummary(employeeCode);

  Future<List<ClmSession>> getRecentSessions({int limit = 20}) =>
      _db.getRecentSessions(limit: limit);

  Future<List<ClmSession>> getDoctorSessions(int doctorId) =>
      _db.getSessionsForDoctor(doctorId);

  Future<int> getPendingUploadsCount() => _db.getPendingUploadsCount();

  /// Record an arbitrary event (star, unstar, share, etc.) for a slide.
  void trackEvent({
    required String sessionId,
    required ClmSlide slide,
    required String eventType,
  }) {
    _db.insertAnalyticsEvent(ClmAnalyticsEvent(
      sessionId: sessionId,
      slideId: slide.id,
      brandId: slide.brandId,
      eventType: eventType,
      timestamp: DateTime.now(),
    ));
  }
}
