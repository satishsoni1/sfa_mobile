import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/clm_models.dart';
import '../models/dcr_models.dart';

class ClmDatabaseService {
  static final ClmDatabaseService _instance = ClmDatabaseService._();
  factory ClmDatabaseService() => _instance;
  ClmDatabaseService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'vodoclm.db');
    return openDatabase(
      dbPath,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      for (final col in [
        'ALTER TABLE clm_doctors ADD COLUMN birthday TEXT',
        'ALTER TABLE clm_doctors ADD COLUMN anniversary TEXT',
        'ALTER TABLE clm_doctors ADD COLUMN email TEXT',
        'ALTER TABLE clm_doctors ADD COLUMN address TEXT',
        'ALTER TABLE clm_doctors ADD COLUMN next_call_date TEXT',
        'ALTER TABLE clm_doctors ADD COLUMN call_freq_target INTEGER DEFAULT 2',
      ]) {
        try { await db.execute(col); } catch (_) {}
      }
      await _createCallReportsTable(db);
    }
    if (oldVersion < 3) {
      for (final col in [
        'ALTER TABLE clm_doctors ADD COLUMN latitude REAL',
        'ALTER TABLE clm_doctors ADD COLUMN longitude REAL',
        'ALTER TABLE clm_call_reports ADD COLUMN voice_note_path TEXT',
        'ALTER TABLE clm_call_reports ADD COLUMN voice_note_transcript TEXT',
      ]) {
        try { await db.execute(col); } catch (_) {}
      }
    }
    if (oldVersion < 4) {
      await _createDoctorLocationsTable(db);
    }
    if (oldVersion < 5) {
      await _createDcrTables(db);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clm_doctors (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        speciality TEXT,
        category TEXT DEFAULT 'C',
        territory TEXT,
        area TEXT,
        mobile TEXT,
        hospital TEXT,
        priority INTEGER DEFAULT 2,
        brand_ids TEXT DEFAULT '[]',
        last_detailed_at TEXT,
        total_sessions INTEGER DEFAULT 0,
        is_planned INTEGER DEFAULT 0,
        birthday TEXT,
        anniversary TEXT,
        email TEXT,
        address TEXT,
        next_call_date TEXT,
        call_freq_target INTEGER DEFAULT 2,
        latitude REAL,
        longitude REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE clm_brands (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        therapy_area TEXT,
        description TEXT,
        thumbnail_url TEXT,
        thumbnail_local_path TEXT,
        slide_count INTEGER DEFAULT 0,
        is_downloaded INTEGER DEFAULT 0,
        download_progress REAL DEFAULT 0,
        sort_order INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE clm_slides (
        id INTEGER PRIMARY KEY,
        brand_id INTEGER NOT NULL,
        type TEXT DEFAULT 'image',
        title TEXT,
        sequence INTEGER DEFAULT 0,
        remote_url TEXT,
        local_path TEXT,
        duration_secs INTEGER DEFAULT 0,
        checksum TEXT,
        is_downloaded INTEGER DEFAULT 0,
        file_size INTEGER DEFAULT 0,
        FOREIGN KEY (brand_id) REFERENCES clm_brands(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE clm_sessions (
        id TEXT PRIMARY KEY,
        doctor_id INTEGER NOT NULL,
        doctor_name TEXT,
        mr_employee_code TEXT,
        start_time TEXT NOT NULL,
        end_time TEXT,
        brand_ids TEXT DEFAULT '[]',
        is_synced INTEGER DEFAULT 0,
        latitude TEXT,
        longitude TEXT,
        device_info TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE clm_analytics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        slide_id INTEGER NOT NULL,
        brand_id INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        duration_secs INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES clm_sessions(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE clm_media_index (
        slide_id INTEGER PRIMARY KEY,
        local_path TEXT NOT NULL,
        checksum TEXT,
        downloaded_at TEXT,
        file_size INTEGER
      )
    ''');

    // Indexes for common query patterns
    await db.execute('CREATE INDEX idx_slides_brand ON clm_slides(brand_id)');
    await db.execute('CREATE INDEX idx_analytics_session ON clm_analytics(session_id)');
    await db.execute('CREATE INDEX idx_analytics_unsynced ON clm_analytics(is_synced)');
    await db.execute('CREATE INDEX idx_sessions_unsynced ON clm_sessions(is_synced)');
    await db.execute('CREATE INDEX idx_doctors_planned ON clm_doctors(is_planned)');
    await _createCallReportsTable(db);
    await _createDoctorLocationsTable(db);
    await _createDcrTables(db);
  }

  Future<void> _createCallReportsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clm_call_reports (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        doctor_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        brands_discussed TEXT DEFAULT '[]',
        reaction TEXT DEFAULT 'neutral',
        call_notes TEXT DEFAULT '',
        topics_discussed TEXT DEFAULT '[]',
        key_messages TEXT DEFAULT '[]',
        next_call_plan TEXT DEFAULT '',
        next_call_date TEXT,
        samples_given INTEGER DEFAULT 0,
        competitor_mentions TEXT DEFAULT '',
        voice_note_path TEXT,
        voice_note_transcript TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_reports_doctor ON clm_call_reports(doctor_id)');
  }

  Future<void> _createDoctorLocationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clm_doctor_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        label TEXT NOT NULL DEFAULT 'Location',
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        captured_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_doc_locs_doctor ON clm_doctor_locations(doctor_id)',
    );
  }

  // ─── Doctors ────────────────────────────────────────────────────────────────

  Future<void> upsertDoctors(List<ClmDoctor> doctors) async {
    final d = await db;
    final batch = d.batch();
    for (final doc in doctors) {
      batch.insert(
        'clm_doctors',
        doc.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ClmDoctor>> getAllDoctors() async {
    final d = await db;
    final rows = await d.query('clm_doctors', orderBy: 'priority ASC, name ASC');
    return rows.map(ClmDoctor.fromDb).toList();
  }

  Future<List<ClmDoctor>> getPlannedDoctors() async {
    final d = await db;
    final rows = await d.query(
      'clm_doctors',
      where: 'is_planned = 1',
      orderBy: 'priority ASC, name ASC',
    );
    return rows.map(ClmDoctor.fromDb).toList();
  }

  Future<List<ClmDoctor>> searchDoctors({
    String? query,
    String? speciality,
    String? category,
    String? territory,
  }) async {
    final d = await db;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (query != null && query.isNotEmpty) {
      conditions.add('(name LIKE ? OR mobile LIKE ? OR hospital LIKE ?)');
      final q = '%$query%';
      args.addAll([q, q, q]);
    }
    if (speciality != null && speciality.isNotEmpty) {
      conditions.add('speciality = ?');
      args.add(speciality);
    }
    if (category != null && category.isNotEmpty) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (territory != null && territory.isNotEmpty) {
      conditions.add('territory = ?');
      args.add(territory);
    }

    final rows = await d.query(
      'clm_doctors',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'priority ASC, name ASC',
    );
    return rows.map(ClmDoctor.fromDb).toList();
  }

  Future<ClmDoctor?> getDoctor(int id) async {
    final d = await db;
    final rows =
        await d.query('clm_doctors', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : ClmDoctor.fromDb(rows.first);
  }

  Future<void> updateDoctorSession(int doctorId, DateTime lastVisited) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE clm_doctors SET last_detailed_at = ?, total_sessions = total_sessions + 1 WHERE id = ?',
      [lastVisited.toIso8601String(), doctorId],
    );
  }

  Future<List<String>> getDistinctSpecialities() async {
    final d = await db;
    final rows =
        await d.rawQuery('SELECT DISTINCT speciality FROM clm_doctors WHERE speciality != "" ORDER BY speciality');
    return rows.map((r) => r['speciality'] as String).toList();
  }

  Future<List<String>> getDistinctTerritories() async {
    final d = await db;
    final rows = await d.rawQuery(
        'SELECT DISTINCT territory FROM clm_doctors WHERE territory != "" ORDER BY territory');
    return rows.map((r) => r['territory'] as String).toList();
  }

  // ─── Brands ─────────────────────────────────────────────────────────────────

  Future<void> upsertBrands(List<ClmBrand> brands) async {
    final d = await db;
    final batch = d.batch();
    for (final b in brands) {
      batch.insert(
        'clm_brands',
        b.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ClmBrand>> getAllBrands() async {
    final d = await db;
    final rows = await d.query('clm_brands', orderBy: 'sort_order ASC, name ASC');
    return rows.map(ClmBrand.fromDb).toList();
  }

  Future<List<ClmBrand>> getBrandsForDoctor(List<int> brandIds) async {
    if (brandIds.isEmpty) return [];
    final d = await db;
    final placeholders = List.filled(brandIds.length, '?').join(',');
    final rows = await d.rawQuery(
      'SELECT * FROM clm_brands WHERE id IN ($placeholders) ORDER BY sort_order ASC',
      brandIds,
    );
    return rows.map(ClmBrand.fromDb).toList();
  }

  Future<ClmBrand?> getBrand(int id) async {
    final d = await db;
    final rows =
        await d.query('clm_brands', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : ClmBrand.fromDb(rows.first);
  }

  Future<void> updateBrandDownloadProgress(
      int brandId, double progress, bool isDownloaded) async {
    final d = await db;
    await d.update(
      'clm_brands',
      {'download_progress': progress, 'is_downloaded': isDownloaded ? 1 : 0},
      where: 'id = ?',
      whereArgs: [brandId],
    );
  }

  // ─── Slides ──────────────────────────────────────────────────────────────────

  Future<void> upsertSlides(List<ClmSlide> slides) async {
    final d = await db;
    final batch = d.batch();
    for (final s in slides) {
      batch.insert(
        'clm_slides',
        s.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ClmSlide>> getSlidesForBrand(int brandId) async {
    final d = await db;
    final rows = await d.query(
      'clm_slides',
      where: 'brand_id = ?',
      whereArgs: [brandId],
      orderBy: 'sequence ASC',
    );
    return rows.map(ClmSlide.fromDb).toList();
  }

  Future<List<ClmSlide>> getSlidesForBrands(List<int> brandIds) async {
    if (brandIds.isEmpty) return [];
    final d = await db;
    final placeholders = List.filled(brandIds.length, '?').join(',');
    final rows = await d.rawQuery(
      'SELECT * FROM clm_slides WHERE brand_id IN ($placeholders) ORDER BY brand_id ASC, sequence ASC',
      brandIds,
    );
    return rows.map(ClmSlide.fromDb).toList();
  }

  Future<void> updateSlideDownloaded(
      int slideId, String localPath, String checksum) async {
    final d = await db;
    await d.update(
      'clm_slides',
      {
        'local_path': localPath,
        'checksum': checksum,
        'is_downloaded': 1,
      },
      where: 'id = ?',
      whereArgs: [slideId],
    );
    await d.insert(
      'clm_media_index',
      {
        'slide_id': slideId,
        'local_path': localPath,
        'checksum': checksum,
        'downloaded_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getDownloadedSlideCount(int brandId) async {
    final d = await db;
    final result = await d.rawQuery(
      'SELECT COUNT(*) as cnt FROM clm_slides WHERE brand_id = ? AND is_downloaded = 1',
      [brandId],
    );
    return result.first['cnt'] as int? ?? 0;
  }

  Future<int> getPendingDownloadCount(int brandId) async {
    final d = await db;
    final result = await d.rawQuery(
      'SELECT COUNT(*) as cnt FROM clm_slides WHERE brand_id = ? AND is_downloaded = 0',
      [brandId],
    );
    return result.first['cnt'] as int? ?? 0;
  }

  // ─── Sessions ────────────────────────────────────────────────────────────────

  Future<void> insertSession(ClmSession session) async {
    final d = await db;
    await d.insert(
      'clm_sessions',
      session.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSessionEnd(String sessionId, DateTime endTime) async {
    final d = await db;
    await d.update(
      'clm_sessions',
      {'end_time': endTime.toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<ClmSession>> getUnsyncedSessions() async {
    final d = await db;
    final rows = await d
        .query('clm_sessions', where: 'is_synced = 0', orderBy: 'start_time ASC');
    return rows.map(ClmSession.fromDb).toList();
  }

  Future<List<ClmSession>> getRecentSessions({int limit = 20}) async {
    final d = await db;
    final rows = await d.query(
      'clm_sessions',
      orderBy: 'start_time DESC',
      limit: limit,
    );
    return rows.map(ClmSession.fromDb).toList();
  }

  Future<ClmSession?> getSessionById(String sessionId) async {
    final d = await db;
    final rows = await d.query(
      'clm_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    return rows.isEmpty ? null : ClmSession.fromDb(rows.first);
  }

  Future<List<ClmSession>> getSessionsForDoctor(int doctorId,
      {int limit = 10}) async {
    final d = await db;
    final rows = await d.query(
      'clm_sessions',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
      orderBy: 'start_time DESC',
      limit: limit,
    );
    return rows.map(ClmSession.fromDb).toList();
  }

  Future<void> markSessionsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final d = await db;
    final placeholders = List.filled(ids.length, '?').join(',');
    await d.rawUpdate(
      'UPDATE clm_sessions SET is_synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<int> getUnsyncedSessionCount() async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT COUNT(*) as cnt FROM clm_sessions WHERE is_synced = 0');
    return r.first['cnt'] as int? ?? 0;
  }

  // ─── Analytics ───────────────────────────────────────────────────────────────

  Future<void> insertAnalyticsEvent(ClmAnalyticsEvent event) async {
    final d = await db;
    await d.insert('clm_analytics', event.toDb());
  }

  Future<void> insertAnalyticsBatch(List<ClmAnalyticsEvent> events) async {
    final d = await db;
    final batch = d.batch();
    for (final e in events) {
      batch.insert('clm_analytics', e.toDb());
    }
    await batch.commit(noResult: true);
  }

  Future<List<ClmAnalyticsEvent>> getUnsyncedAnalytics() async {
    final d = await db;
    final rows = await d.query(
      'clm_analytics',
      where: 'is_synced = 0',
      orderBy: 'timestamp ASC',
      limit: 500,
    );
    return rows.map(ClmAnalyticsEvent.fromDb).toList();
  }

  Future<void> markAnalyticsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final d = await db;
    final placeholders = List.filled(ids.length, '?').join(',');
    await d.rawUpdate(
      'UPDATE clm_analytics SET is_synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<Map<int, int>> getSlideSecondsForSession(String sessionId) async {
    final d = await db;
    final rows = await d.rawQuery(
      '''SELECT slide_id, SUM(duration_secs) as total
         FROM clm_analytics
         WHERE session_id = ? AND event_type = 'slide_view'
         GROUP BY slide_id''',
      [sessionId],
    );
    return {
      for (final r in rows)
        (r['slide_id'] as int): (r['total'] as num).toInt()
    };
  }

  Future<ClmDoctorStats> getDoctorStats(int doctorId) async {
    final d = await db;

    final sessionRows = await d.rawQuery(
      '''SELECT id, start_time, end_time FROM clm_sessions
         WHERE doctor_id = ? ORDER BY start_time DESC''',
      [doctorId],
    );

    if (sessionRows.isEmpty) {
      return ClmDoctorStats(doctorId: doctorId);
    }

    int totalMins = 0;
    DateTime? latestStart;

    for (final s in sessionRows) {
      final start = DateTime.parse(s['start_time'] as String);
      final end = s['end_time'] != null
          ? DateTime.tryParse(s['end_time'] as String) ?? DateTime.now()
          : DateTime.now();
      totalMins += end.difference(start).inMinutes;
      if (latestStart == null || start.isAfter(latestStart)) {
        latestStart = start;
      }
    }

    final brandRows = await d.rawQuery(
      '''SELECT brand_id, SUM(duration_secs) as total
         FROM clm_analytics a
         JOIN clm_sessions s ON a.session_id = s.id
         WHERE s.doctor_id = ? AND a.event_type = 'slide_view'
         GROUP BY brand_id''',
      [doctorId],
    );

    final brandMap = {
      for (final r in brandRows)
        (r['brand_id'] as int): (r['total'] as num).toInt()
    };

    return ClmDoctorStats(
      doctorId: doctorId,
      totalSessions: sessionRows.length,
      totalMinutes: totalMins,
      brandSecondsMap: brandMap,
      lastSession: latestStart,
    );
  }

  // ─── Dashboard Summary ────────────────────────────────────────────────────────

  Future<Map<String, int>> getTodaySummary(String employeeCode) async {
    final d = await db;
    final today = DateTime.now();
    final dayStart =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final dayEnd =
        DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();

    final sessRows = await d.rawQuery(
      '''SELECT COUNT(*) as cnt FROM clm_sessions
         WHERE mr_employee_code = ? AND start_time BETWEEN ? AND ?''',
      [employeeCode, dayStart, dayEnd],
    );
    final totalMinsRow = await d.rawQuery(
      '''SELECT SUM((julianday(COALESCE(end_time,datetime('now'))) - julianday(start_time)) * 1440) as mins
         FROM clm_sessions
         WHERE mr_employee_code = ? AND start_time BETWEEN ? AND ?''',
      [employeeCode, dayStart, dayEnd],
    );

    return {
      'sessions': sessRows.first['cnt'] as int? ?? 0,
      'total_minutes':
          (totalMinsRow.first['mins'] as double?)?.round() ?? 0,
    };
  }

  Future<int> getPendingUploadsCount() async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT COUNT(*) as cnt FROM clm_sessions WHERE is_synced = 0');
    return r.first['cnt'] as int? ?? 0;
  }

  // ─── Call Reports ────────────────────────────────────────────────────────────

  Future<void> saveCallReport(ClmCallReport report) async {
    final d = await db;
    await d.insert(
      'clm_call_reports',
      report.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Update next call date on doctor record
    if (report.nextCallDate != null) {
      await d.update(
        'clm_doctors',
        {'next_call_date': report.nextCallDate!.toIso8601String()},
        where: 'id = ?',
        whereArgs: [report.doctorId],
      );
    }
  }

  Future<List<ClmCallReport>> getCallReportsForDoctor(int doctorId,
      {int limit = 20}) async {
    final d = await db;
    final rows = await d.query(
      'clm_call_reports',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ClmCallReport.fromDb).toList();
  }

  Future<ClmCallReport?> getCallReportForSession(String sessionId) async {
    final d = await db;
    final rows = await d.query(
      'clm_call_reports',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    return rows.isEmpty ? null : ClmCallReport.fromDb(rows.first);
  }

  Future<List<ClmCallReport>> getUnsyncedCallReports() async {
    final d = await db;
    final rows = await d.query(
      'clm_call_reports',
      where: 'is_synced = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(ClmCallReport.fromDb).toList();
  }

  Future<void> markCallReportsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final d = await db;
    final placeholders = List.filled(ids.length, '?').join(',');
    await d.rawUpdate(
      'UPDATE clm_call_reports SET is_synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  // ─── Doctor Locations ────────────────────────────────────────────────────────

  Future<List<DoctorLocation>> getLocationsForDoctor(int doctorId) async {
    final d = await db;
    final rows = await d.query(
      'clm_doctor_locations',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
      orderBy: 'captured_at ASC',
    );
    return rows.map(DoctorLocation.fromDb).toList();
  }

  Future<int> getDoctorLocationCount(int doctorId) async {
    final d = await db;
    final r = await d.rawQuery(
      'SELECT COUNT(*) as cnt FROM clm_doctor_locations WHERE doctor_id = ?',
      [doctorId],
    );
    return r.first['cnt'] as int? ?? 0;
  }

  /// Inserts a new location and returns its auto-generated id.
  Future<int> insertDoctorLocation(DoctorLocation loc) async {
    final d = await db;
    return d.insert('clm_doctor_locations', loc.toDb());
  }

  Future<void> updateDoctorLocationLabel(int id, String label) async {
    final d = await db;
    await d.update(
      'clm_doctor_locations',
      {'label': label},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDoctorLocation(int id) async {
    final d = await db;
    await d.delete(
      'clm_doctor_locations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Visit History ────────────────────────────────────────────────────────────

  /// Returns the last [limit] visits for a doctor as enriched summaries.
  Future<List<ClmVisitSummary>> getVisitHistory(int doctorId,
      {int limit = 10}) async {
    final d = await db;

    // Fetch sessions
    final sessionRows = await d.query(
      'clm_sessions',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
      orderBy: 'start_time DESC',
      limit: limit,
    );

    if (sessionRows.isEmpty) return [];

    final summaries = <ClmVisitSummary>[];

    for (final row in sessionRows) {
      final sessionId = row['id'] as String;
      final startTime = DateTime.parse(row['start_time'] as String);
      final endTime = row['end_time'] != null
          ? DateTime.tryParse(row['end_time'] as String) ?? DateTime.now()
          : DateTime.now();
      final durationMins = endTime.difference(startTime).inMinutes;

      // Brand names from brand_ids stored in session
      final brandIdsRaw = row['brand_ids'] as String? ?? '[]';
      final brandIds = List<int>.from(json.decode(brandIdsRaw));
      List<String> brandNames = [];
      if (brandIds.isNotEmpty) {
        final placeholders = List.filled(brandIds.length, '?').join(',');
        final brandRows = await d.rawQuery(
          'SELECT name FROM clm_brands WHERE id IN ($placeholders)',
          brandIds,
        );
        brandNames = brandRows.map((r) => r['name'] as String).toList();
      }

      // Slide count from analytics
      final slideCountRow = await d.rawQuery(
        'SELECT COUNT(DISTINCT slide_id) as cnt FROM clm_analytics WHERE session_id = ?',
        [sessionId],
      );
      final slidesShown = slideCountRow.first['cnt'] as int? ?? 0;

      // Call report
      final reportRows = await d.query(
        'clm_call_reports',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );

      DoctorReaction? reaction;
      String? callNotes;
      List<String> topics = [];
      if (reportRows.isNotEmpty) {
        final report = ClmCallReport.fromDb(reportRows.first);
        reaction = report.reaction;
        callNotes = report.callNotes.isNotEmpty ? report.callNotes : null;
        topics = report.topicsDiscussed;
      }

      summaries.add(ClmVisitSummary(
        sessionId: sessionId,
        visitDate: startTime,
        durationMinutes: durationMins,
        brandNames: brandNames,
        reaction: reaction,
        callNotes: callNotes,
        topicsDiscussed: topics,
        slidesShown: slidesShown,
      ));
    }

    return summaries;
  }

  Future<void> updateDoctorNextCallDate(int doctorId, DateTime? date) async {
    final d = await db;
    await d.update(
      'clm_doctors',
      {'next_call_date': date?.toIso8601String()},
      where: 'id = ?',
      whereArgs: [doctorId],
    );
  }

  // ─── Cache Check ─────────────────────────────────────────────────────────────

  Future<bool> hasCachedData() async {
    final d = await db;
    final r = await d.rawQuery('SELECT COUNT(*) as cnt FROM clm_brands');
    return (r.first['cnt'] as int? ?? 0) > 0;
  }

  // ─── Clear All Local Data ─────────────────────────────────────────────────────

  Future<void> clearAllData() async {
    final d = await db;
    await d.transaction((txn) async {
      // Clear in dependency order (children before parents)
      for (final table in [
        'clm_analytics', 'clm_call_reports', 'clm_doctor_locations',
        'clm_sessions', 'clm_media_index', 'clm_slides', 'clm_brands',
        'clm_doctors',
        'dcr_rcpa_competitors', 'dcr_rcpa_entries',
        'dcr_chemist_employees', 'dcr_chemist_visits',
        'dcr_visit_signatures', 'dcr_sample_items',
        'dcr_visit_employees', 'dcr_doctor_visits',
        'dcr_employees', 'dcr_chemists', 'dcr_products',
      ]) {
        await txn.execute('DELETE FROM $table');
      }
    });
  }

  // ─── DCR Table Creation ───────────────────────────────────────────────────────

  Future<void> _createDcrTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dcr_products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        therapy_area TEXT DEFAULT '',
        stock_available INTEGER DEFAULT 0,
        allocation_per_doctor INTEGER DEFAULT 2
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dcr_chemists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        area TEXT DEFAULT '',
        territory TEXT DEFAULT '',
        address TEXT,
        mobile TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dcr_employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        employee_code TEXT DEFAULT '',
        designation TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dcr_doctor_visits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT,
        doctor_id INTEGER NOT NULL,
        doctor_name TEXT DEFAULT '',
        visit_date TEXT NOT NULL,
        visit_start_time TEXT NOT NULL,
        visit_end_time TEXT,
        status TEXT DEFAULT 'draft',
        voice_note_path TEXT,
        voice_note_transcript TEXT,
        attached_letter_path TEXT,
        business_value_pts REAL DEFAULT 0,
        featured_brands TEXT DEFAULT '[]',
        remarks TEXT DEFAULT '',
        is_synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_dcr_dv_date ON dcr_doctor_visits(visit_date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_dcr_dv_session ON dcr_doctor_visits(session_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dcr_visit_employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        visit_id INTEGER NOT NULL,
        employee_id INTEGER,
        employee_code TEXT DEFAULT '',
        employee_name TEXT NOT NULL,
        FOREIGN KEY (visit_id) REFERENCES dcr_doctor_visits(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dcr_sample_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        visit_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER DEFAULT 0,
        allocation_limit INTEGER DEFAULT 2,
        stock_available INTEGER DEFAULT 0,
        FOREIGN KEY (visit_id) REFERENCES dcr_doctor_visits(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_dcr_si_visit ON dcr_sample_items(visit_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dcr_visit_signatures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        visit_id INTEGER NOT NULL UNIQUE,
        signature_path TEXT NOT NULL,
        captured_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dcr_chemist_visits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_visit_id INTEGER,
        chemist_id INTEGER NOT NULL,
        chemist_name TEXT DEFAULT '',
        visit_date TEXT NOT NULL,
        visit_start_time TEXT NOT NULL,
        visit_end_time TEXT,
        status TEXT DEFAULT 'draft',
        product_available INTEGER DEFAULT 0,
        pob_units INTEGER DEFAULT 0,
        remarks TEXT DEFAULT '',
        is_synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_dcr_cv_date ON dcr_chemist_visits(visit_date)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dcr_chemist_employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chemist_visit_id INTEGER NOT NULL,
        employee_id INTEGER,
        employee_code TEXT DEFAULT '',
        employee_name TEXT NOT NULL,
        FOREIGN KEY (chemist_visit_id) REFERENCES dcr_chemist_visits(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dcr_rcpa_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chemist_visit_id INTEGER NOT NULL,
        doctor_id INTEGER NOT NULL,
        doctor_name TEXT DEFAULT '',
        brand_id INTEGER,
        brand_name TEXT NOT NULL,
        rx_qty_per_week INTEGER DEFAULT 0,
        FOREIGN KEY (chemist_visit_id) REFERENCES dcr_chemist_visits(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_dcr_re_cv ON dcr_rcpa_entries(chemist_visit_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dcr_rcpa_competitors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rcpa_entry_id INTEGER NOT NULL,
        competitor_name TEXT NOT NULL,
        sales_qty INTEGER DEFAULT 0,
        FOREIGN KEY (rcpa_entry_id) REFERENCES dcr_rcpa_entries(id) ON DELETE CASCADE
      )
    ''');
  }

  // ─── DCR API Upsert ──────────────────────────────────────────────────────────

  Future<void> upsertDcrProducts(List<Map<String, dynamic>> rows) async {
    final d = await db;
    final batch = d.batch();
    for (final r in rows) {
      batch.insert('dcr_products', {
        'id':                   r['id'],
        'name':                 r['name'] ?? '',
        'therapy_area':         r['therapy_area'] ?? '',
        'stock_available':      r['stock_available'] ?? 0,
        'allocation_per_doctor': r['allocation_per_doctor'] ?? 2,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertDcrChemists(List<Map<String, dynamic>> rows) async {
    final d = await db;
    final batch = d.batch();
    for (final r in rows) {
      batch.insert('dcr_chemists', {
        'id':        r['id'],
        'name':      r['name'] ?? '',
        'area':      r['area'] ?? '',
        'territory': r['territory'] ?? '',
        'address':   r['address'],
        'mobile':    r['mobile'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertDcrEmployees(List<Map<String, dynamic>> rows) async {
    final d = await db;
    final batch = d.batch();
    for (final r in rows) {
      batch.insert('dcr_employees', {
        'id':            r['id'],
        'name':          r['name'] ?? '',
        'employee_code': r['employee_code'] ?? '',
        'designation':   r['role'] ?? r['designation'] ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ─── DCR Products ─────────────────────────────────────────────────────────────

  Future<List<DcrProduct>> getAllDcrProducts() async {
    final d = await db;
    final rows = await d.query('dcr_products', orderBy: 'therapy_area ASC, name ASC');
    return rows.map(DcrProduct.fromDb).toList();
  }

  Future<void> updateDcrProductStock(int id, int newStock) async {
    final d = await db;
    await d.update('dcr_products', {'stock_available': newStock},
        where: 'id = ?', whereArgs: [id]);
  }

  // ─── DCR Chemists ─────────────────────────────────────────────────────────────

  Future<List<DcrChemist>> getAllDcrChemists() async {
    final d = await db;
    final rows = await d.query('dcr_chemists', orderBy: 'name ASC');
    return rows.map(DcrChemist.fromDb).toList();
  }

  Future<int> insertDcrChemist(DcrChemist chemist) async {
    final d = await db;
    return d.insert('dcr_chemists', chemist.toDb());
  }

  Future<List<DcrChemist>> searchDcrChemists(String query) async {
    final d = await db;
    final q = '%$query%';
    final rows = await d.rawQuery(
      'SELECT * FROM dcr_chemists WHERE name LIKE ? OR area LIKE ? ORDER BY name ASC',
      [q, q],
    );
    return rows.map(DcrChemist.fromDb).toList();
  }

  // ─── DCR Employees ────────────────────────────────────────────────────────────

  Future<List<DcrEmployee>> getAllDcrEmployees() async {
    final d = await db;
    final rows = await d.query('dcr_employees', orderBy: 'name ASC');
    return rows.map(DcrEmployee.fromDb).toList();
  }

  // ─── DCR Doctor Visits ────────────────────────────────────────────────────────

  Future<int> insertDcrDoctorVisit(DcrDoctorVisit visit) async {
    final d = await db;
    return d.insert('dcr_doctor_visits', visit.toDb());
  }

  Future<void> updateDcrDoctorVisit(DcrDoctorVisit visit) async {
    final d = await db;
    await d.update('dcr_doctor_visits', visit.toDb(),
        where: 'id = ?', whereArgs: [visit.id]);
  }

  Future<List<DcrDoctorVisit>> getDcrDoctorVisitsForDate(String date) async {
    final d = await db;
    final rows = await d.query('dcr_doctor_visits',
        where: 'visit_date = ?',
        whereArgs: [date],
        orderBy: 'visit_start_time ASC');
    return rows.map(DcrDoctorVisit.fromDb).toList();
  }

  Future<DcrDoctorVisit?> getDcrDoctorVisit(int id) async {
    final d = await db;
    final rows = await d.query('dcr_doctor_visits', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : DcrDoctorVisit.fromDb(rows.first);
  }

  Future<DcrDoctorVisit?> getDcrDoctorVisitForSession(String sessionId) async {
    final d = await db;
    final rows = await d.query('dcr_doctor_visits',
        where: 'session_id = ?', whereArgs: [sessionId], limit: 1);
    return rows.isEmpty ? null : DcrDoctorVisit.fromDb(rows.first);
  }

  Future<void> deleteDcrDoctorVisit(int id) async {
    final d = await db;
    await d.delete('dcr_doctor_visits', where: 'id = ?', whereArgs: [id]);
  }

  // ─── DCR Visit Employees ──────────────────────────────────────────────────────

  Future<void> addDcrVisitEmployee(DcrVisitEmployee emp) async {
    final d = await db;
    await d.insert('dcr_visit_employees', emp.toDb());
  }

  Future<void> removeDcrVisitEmployee(int id) async {
    final d = await db;
    await d.delete('dcr_visit_employees', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DcrVisitEmployee>> getDcrVisitEmployees(int visitId) async {
    final d = await db;
    final rows = await d.query('dcr_visit_employees',
        where: 'visit_id = ?', whereArgs: [visitId]);
    return rows.map(DcrVisitEmployee.fromDb).toList();
  }

  Future<void> clearDcrVisitEmployees(int visitId) async {
    final d = await db;
    await d.delete('dcr_visit_employees', where: 'visit_id = ?', whereArgs: [visitId]);
  }

  // ─── DCR Sample Items ─────────────────────────────────────────────────────────

  Future<int> insertDcrSampleItem(DcrSampleItem item) async {
    final d = await db;
    return d.insert('dcr_sample_items', item.toDb());
  }

  Future<void> updateDcrSampleItem(DcrSampleItem item) async {
    final d = await db;
    await d.update('dcr_sample_items', item.toDb(),
        where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteDcrSampleItem(int id) async {
    final d = await db;
    await d.delete('dcr_sample_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearDcrSampleItems(int visitId) async {
    final d = await db;
    await d.delete('dcr_sample_items', where: 'visit_id = ?', whereArgs: [visitId]);
  }

  Future<List<DcrSampleItem>> getDcrSampleItemsForVisit(int visitId) async {
    final d = await db;
    final rows = await d.query('dcr_sample_items',
        where: 'visit_id = ?', whereArgs: [visitId], orderBy: 'product_name ASC');
    return rows.map(DcrSampleItem.fromDb).toList();
  }

  Future<int> getTotalSamplesForDate(String date) async {
    final d = await db;
    final r = await d.rawQuery('''
      SELECT SUM(si.quantity) as total
      FROM dcr_sample_items si
      JOIN dcr_doctor_visits dv ON si.visit_id = dv.id
      WHERE dv.visit_date = ?
    ''', [date]);
    return (r.first['total'] as num?)?.toInt() ?? 0;
  }

  // ─── DCR Visit Signatures ─────────────────────────────────────────────────────

  Future<void> saveDcrVisitSignature(DcrVisitSignature sig) async {
    final d = await db;
    await d.insert('dcr_visit_signatures', sig.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DcrVisitSignature?> getDcrVisitSignature(int visitId) async {
    final d = await db;
    final rows = await d.query('dcr_visit_signatures',
        where: 'visit_id = ?', whereArgs: [visitId], limit: 1);
    return rows.isEmpty ? null : DcrVisitSignature.fromDb(rows.first);
  }

  Future<void> deleteDcrVisitSignature(int visitId) async {
    final d = await db;
    await d.delete('dcr_visit_signatures',
        where: 'visit_id = ?', whereArgs: [visitId]);
  }

  // ─── DCR Chemist Visits ───────────────────────────────────────────────────────

  Future<int> insertDcrChemistVisit(DcrChemistVisit visit) async {
    final d = await db;
    return d.insert('dcr_chemist_visits', visit.toDb());
  }

  Future<void> updateDcrChemistVisit(DcrChemistVisit visit) async {
    final d = await db;
    await d.update('dcr_chemist_visits', visit.toDb(),
        where: 'id = ?', whereArgs: [visit.id]);
  }

  Future<List<DcrChemistVisit>> getDcrChemistVisitsForDate(String date) async {
    final d = await db;
    final rows = await d.query('dcr_chemist_visits',
        where: 'visit_date = ?',
        whereArgs: [date],
        orderBy: 'visit_start_time ASC');
    return rows.map(DcrChemistVisit.fromDb).toList();
  }

  Future<DcrChemistVisit?> getDcrChemistVisit(int id) async {
    final d = await db;
    final rows =
        await d.query('dcr_chemist_visits', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : DcrChemistVisit.fromDb(rows.first);
  }

  Future<void> deleteDcrChemistVisit(int id) async {
    final d = await db;
    await d.delete('dcr_chemist_visits', where: 'id = ?', whereArgs: [id]);
  }

  // ─── DCR Chemist Employees ────────────────────────────────────────────────────

  Future<void> addDcrChemistEmployee(DcrChemistEmployee emp) async {
    final d = await db;
    await d.insert('dcr_chemist_employees', emp.toDb());
  }

  Future<void> removeDcrChemistEmployee(int id) async {
    final d = await db;
    await d.delete('dcr_chemist_employees', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DcrChemistEmployee>> getDcrChemistEmployees(
      int chemistVisitId) async {
    final d = await db;
    final rows = await d.query('dcr_chemist_employees',
        where: 'chemist_visit_id = ?', whereArgs: [chemistVisitId]);
    return rows.map(DcrChemistEmployee.fromDb).toList();
  }

  Future<void> clearDcrChemistEmployees(int chemistVisitId) async {
    final d = await db;
    await d.delete('dcr_chemist_employees',
        where: 'chemist_visit_id = ?', whereArgs: [chemistVisitId]);
  }

  // ─── DCR RCPA Entries ─────────────────────────────────────────────────────────

  Future<int> insertDcrRcpaEntry(DcrRcpaEntry entry) async {
    final d = await db;
    return d.insert('dcr_rcpa_entries', entry.toDb());
  }

  Future<void> updateDcrRcpaEntry(DcrRcpaEntry entry) async {
    final d = await db;
    await d.update('dcr_rcpa_entries', entry.toDb(),
        where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<void> deleteDcrRcpaEntry(int id) async {
    final d = await db;
    await d.delete('dcr_rcpa_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearDcrRcpaEntriesForVisit(int chemistVisitId) async {
    final d = await db;
    await d.delete('dcr_rcpa_entries',
        where: 'chemist_visit_id = ?', whereArgs: [chemistVisitId]);
  }

  Future<List<DcrRcpaEntry>> getDcrRcpaEntriesForVisit(
      int chemistVisitId) async {
    final d = await db;
    final rows = await d.query('dcr_rcpa_entries',
        where: 'chemist_visit_id = ?',
        whereArgs: [chemistVisitId],
        orderBy: 'doctor_name ASC, brand_name ASC');
    return rows.map(DcrRcpaEntry.fromDb).toList();
  }

  // ─── DCR RCPA Competitors ─────────────────────────────────────────────────────

  Future<int> insertDcrRcpaCompetitor(DcrRcpaCompetitor comp) async {
    final d = await db;
    return d.insert('dcr_rcpa_competitors', comp.toDb());
  }

  Future<void> updateDcrRcpaCompetitor(DcrRcpaCompetitor comp) async {
    final d = await db;
    await d.update('dcr_rcpa_competitors', comp.toDb(),
        where: 'id = ?', whereArgs: [comp.id]);
  }

  Future<void> deleteDcrRcpaCompetitor(int id) async {
    final d = await db;
    await d.delete('dcr_rcpa_competitors', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearDcrRcpaCompetitorsForEntry(int rcpaEntryId) async {
    final d = await db;
    await d.delete('dcr_rcpa_competitors',
        where: 'rcpa_entry_id = ?', whereArgs: [rcpaEntryId]);
  }

  Future<List<DcrRcpaCompetitor>> getDcrRcpaCompetitorsForEntry(
      int rcpaEntryId) async {
    final d = await db;
    final rows = await d.query('dcr_rcpa_competitors',
        where: 'rcpa_entry_id = ?', whereArgs: [rcpaEntryId]);
    return rows.map(DcrRcpaCompetitor.fromDb).toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
