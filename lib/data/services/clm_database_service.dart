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
      await _seedDcrDemoData(db);
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
    await _seedDcrDemoData(db);
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

  // ─── Demo Seeder ─────────────────────────────────────────────────────────────

  Future<bool> isDemoSeeded() async {
    final d = await db;
    final r = await d.rawQuery('SELECT COUNT(*) as cnt FROM clm_doctors');
    return (r.first['cnt'] as int? ?? 0) > 0;
  }

  Future<void> seedDemoData() async {
    final d = await db;
    final dir = await getApplicationDocumentsDirectory();

    // ── Brands ─────────────────────────────────────────────────────────────────
    final brands = [
      {'id': 1, 'name': 'CardioMax', 'therapy_area': 'Cardiovascular',
        'description': 'First-line ARB for hypertension & heart failure',
        'slide_count': 4, 'sort_order': 0},
      {'id': 2, 'name': 'NeuroVite', 'therapy_area': 'Neurology',
        'description': 'Neuroprotective B-complex for peripheral neuropathy',
        'slide_count': 4, 'sort_order': 1},
      {'id': 3, 'name': 'GlucoShield', 'therapy_area': 'Diabetology',
        'description': 'SGLT2 inhibitor for T2DM with CV protection',
        'slide_count': 3, 'sort_order': 2},
    ];
    for (final b in brands) {
      await d.insert('clm_brands', b, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // ── Slides (HTML, written to disk) ────────────────────────────────────────
    final slideData = [
      // CardioMax
      _slide(101, 1, 0, 'Mechanism of Action',    _htmlMoa('CardioMax',  '#C62828', 'Angiotensin II Receptor Blocker (ARB)', 'Selectively blocks AT1 receptors → reduces vasoconstriction → lowers BP by 15–20 mmHg systolic.')),
      _slide(102, 1, 1, 'Clinical Evidence',       _htmlEvidence('CardioMax', '#C62828', [('ONTARGET Trial', '25% reduction in CV events vs placebo'), ('TRANSCEND Trial', 'Renal protection in diabetic nephropathy'), ('PRoFESS Trial', 'Stroke recurrence reduction by 13%')])),
      _slide(103, 1, 2, 'Dosage & Administration', _htmlDosage('CardioMax', '#C62828', '40–80 mg once daily', 'Can be uptitrated to 160 mg. No food interaction. Safe in mild–moderate renal impairment.')),
      _slide(104, 1, 3, 'Patient Benefits',        _htmlBenefits('CardioMax', '#C62828', ['24-hour BP control with once-daily dosing', 'Renoprotective in diabetic patients', 'Well tolerated – no cough (unlike ACEi)', 'Cardioprotective in post-MI patients'])),
      // NeuroVite
      _slide(201, 2, 0, 'Product Overview',        _htmlMoa('NeuroVite', '#1565C0', 'Neurotropic B-Complex (B1 + B6 + B12)', 'High-dose benfotiamine (B1) restores nerve conduction; methylcobalamin (B12) promotes axonal regeneration.')),
      _slide(202, 2, 1, 'Research Evidence',       _htmlEvidence('NeuroVite', '#1565C0', [('BENDIP Trial', '50 mg B1 × 3 – significant NDS improvement at 6 wks'), ('NATHAN I', 'B1 vs placebo: 2× faster nerve regeneration'), ('Meta-analysis (2022)', '73% symptom improvement in DPN within 12 weeks')])),
      _slide(203, 2, 2, 'Indication & Dosing',    _htmlDosage('NeuroVite', '#1565C0', '1 tablet twice daily with meals', 'For diabetic & alcoholic neuropathy. Minimum 3-month course. Safe in CKD patients.')),
      _slide(204, 2, 3, 'Symptom Relief Profile', _htmlBenefits('NeuroVite', '#1565C0', ['Reduces burning & tingling within 2 weeks', 'Improves nerve conduction velocity', 'Enhances balance & coordination', 'Safe long-term use with no organ toxicity'])),
      // GlucoShield
      _slide(301, 3, 0, 'Mechanism of Action',    _htmlMoa('GlucoShield', '#2E7D32', 'SGLT2 Inhibitor', 'Blocks sodium-glucose co-transporter 2 in proximal tubule → glucosuria → HbA1c ↓ 0.7–1.2% + weight ↓ 2–3 kg.')),
      _slide(302, 3, 1, 'CV & Renal Benefits',    _htmlEvidence('GlucoShield', '#2E7D32', [('EMPA-REG', '38% reduction in CV death'), ('CANVAS Program', '33% reduction in renal progression'), ('CREDENCE Trial', '30% reduction in ESRD risk')])),
      _slide(303, 3, 2, 'Dosing Guidance',        _htmlDosage('GlucoShield', '#2E7D32', '10 mg once daily (↑ to 25 mg)', 'Take in the morning. Ensure adequate hydration. Avoid if eGFR < 30. Monitor for UTI/genital infections.')),
    ];

    for (final s in slideData) {
      final htmlDir = Directory(p.join(dir.path, 'clm', 'media', 'brand_${s['brand_id']}'));
      await htmlDir.create(recursive: true);
      final filePath = p.join(htmlDir.path, 'slide_${s['id']}.html');
      await File(filePath).writeAsString(s['_html'] as String);

      await d.insert('clm_slides', {
        'id': s['id'],
        'brand_id': s['brand_id'],
        'type': 'html',
        'title': s['title'],
        'sequence': s['sequence'],
        'remote_url': 'https://demo.vodoclm.internal/slides/${s['id']}.html',
        'local_path': filePath,
        'duration_secs': 30,
        'is_downloaded': 1,
        'file_size': (s['_html'] as String).length,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Update brand slide counts (already set in seed, but confirm downloaded=1)
    for (final b in brands) {
      await d.update('clm_brands',
          {'is_downloaded': 1, 'download_progress': 1.0},
          where: 'id = ?', whereArgs: [b['id']]);
    }

    // ── Doctors ────────────────────────────────────────────────────────────────
    final now = DateTime.now();
    final doctors = [
      _doctor(1,  'Dr. Amit Shah',      'Cardiologist',       'A', 'TER-001', 'Ahmedabad',  'Sterling Hospital',  1, [1],    now.subtract(const Duration(days: 3)),  true,  '06-15', null,   'dr.amit.shah@sterling.in',  2, 23.0469, 72.5513),
      _doctor(2,  'Dr. Priya Mehta',    'Diabetologist',      'A', 'TER-001', 'Ahmedabad',  'Apollo Hospitals',   1, [1, 3], now.subtract(const Duration(days: 7)),  true,  '11-02', '03-20','priya.mehta@apollo.com',    2, 23.0334, 72.5848),
      _doctor(3,  'Dr. Rajesh Kumar',   'Neurologist',        'B', 'TER-002', 'Gandhinagar','CIMS Hospital',      2, [2],    now.subtract(const Duration(days: 14)), false, '08-28', null,   'rkumar@cims.org',           2, 23.2156, 72.6369),
      _doctor(4,  'Dr. Sunita Patel',   'Oncologist',         'B', 'TER-002', 'Surat',      'HCG Cancer Centre',  2, [1, 2], now.subtract(const Duration(days: 21)), true,  '01-10', '07-05','sunita.p@hcg.in',           3, 21.1702, 72.8311),
      _doctor(5,  'Dr. Vikram Nair',    'Gastroenterologist', 'C', 'TER-001', 'Vadodara',   'Baroda Medical',     2, [3],    now.subtract(const Duration(days: 5)),  false, null,    null,   null,                        1, 22.3072, 73.1812),
      _doctor(6,  'Dr. Anita Roy',      'Pulmonologist',      'A', 'TER-003', 'Rajkot',     'KIMS Hospital',      1, [2],    now.subtract(const Duration(days: 30)), true,  '05-22', '09-14','anita.roy@kims.com',        2, 22.3039, 70.8022),
      _doctor(7,  'Dr. Sanjay Gupta',   'Rheumatologist',     'B', 'TER-003', 'Rajkot',     'Civil Hospital',     2, [1, 2], null,                                   false, '12-31', null,   'sgupta@civilhosp.in',       2, 22.3115, 70.7957),
      _doctor(8,  'Dr. Meera Krishnan', 'Endocrinologist',    'C', 'TER-002', 'Surat',      'Sunshine Hospital',  3, [3],    now.subtract(const Duration(days: 60)), false, '03-08', '06-21','meera.k@sunshine.in',       1, 21.1958, 72.8238),
    ];
    for (final doc in doctors) {
      await d.insert('clm_doctors', doc, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Seed a few historical call reports for Dr. Amit Shah & Dr. Priya Mehta
    final reportSeed = [
      {'id': 'demo-rpt-1', 'session_id': 'demo-sess-1', 'doctor_id': 1, 'created_at': now.subtract(const Duration(days: 30)).toIso8601String(), 'brands_discussed': '[1]', 'reaction': 'positive', 'call_notes': 'Doctor showed strong interest in CardioMax. Asked about renal dosing.', 'topics_discussed': '["Renal dosing","ARB mechanism","Patient case"]', 'key_messages': '["24h BP control","No cough side effect"]', 'next_call_plan': 'Share ONTARGET trial reprint', 'next_call_date': now.subtract(const Duration(days: 3)).toIso8601String(), 'samples_given': 5, 'competitor_mentions': 'Losartan mentioned', 'is_synced': 0},
      {'id': 'demo-rpt-2', 'session_id': 'demo-sess-2', 'doctor_id': 1, 'created_at': now.subtract(const Duration(days: 14)).toIso8601String(), 'brands_discussed': '[1]', 'reaction': 'receptive', 'call_notes': 'Followed up on trial reprint. He is considering switching 3 patients.', 'topics_discussed': '["ONTARGET trial","Switching patients","Tolerability"]', 'key_messages': '["CV death reduction","Renoprotection"]', 'next_call_plan': 'Bring patient case study', 'next_call_date': now.add(const Duration(days: 7)).toIso8601String(), 'samples_given': 5, 'competitor_mentions': '', 'is_synced': 0},
      {'id': 'demo-rpt-3', 'session_id': 'demo-sess-3', 'doctor_id': 2, 'created_at': now.subtract(const Duration(days: 21)).toIso8601String(), 'brands_discussed': '[1,3]', 'reaction': 'neutral', 'call_notes': 'Presented both CardioMax and GlucoShield. Interest in SGLT2 data.', 'topics_discussed': '["EMPA-REG","CV protection","Dual therapy"]', 'key_messages': '["CV death reduction","Glucosuria","Weight loss"]', 'next_call_plan': 'GlucoShield 25mg starter pack', 'next_call_date': now.add(const Duration(days: 3)).toIso8601String(), 'samples_given': 10, 'competitor_mentions': 'Jardiance comparison raised', 'is_synced': 0},
    ];
    for (final r in reportSeed) {
      await d.insert('clm_call_reports', r, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ── Seeder helpers ──────────────────────────────────────────────────────────

  Map<String, dynamic> _slide(int id, int brandId, int seq, String title, String html) =>
      {'id': id, 'brand_id': brandId, 'sequence': seq, 'title': title, '_html': html};

  Map<String, dynamic> _doctor(
    int id, String name, String spec, String cat, String territory,
    String area, String hospital, int priority, List<int> brandIds,
    DateTime? lastDetailed, bool isPlanned,
    String? birthday, String? anniversary, String? email, int callFreq,
    double? lat, double? lng,
  ) => {
    'id': id, 'name': name, 'speciality': spec, 'category': cat,
    'territory': territory, 'area': area, 'mobile': '98${id.toString().padLeft(8, '0')}',
    'hospital': hospital, 'priority': priority,
    'brand_ids': '[${brandIds.join(',')}]',
    'last_detailed_at': lastDetailed?.toIso8601String(),
    'total_sessions': isPlanned ? 2 : 0,
    'is_planned': isPlanned ? 1 : 0,
    'birthday': birthday,
    'anniversary': anniversary,
    'email': email,
    'call_freq_target': callFreq,
    'latitude': lat,
    'longitude': lng,
  };

  // ── HTML slide templates ────────────────────────────────────────────────────

  static String _base(String brand, String accentHex, String content) => '''
<!DOCTYPE html><html><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:'Segoe UI',sans-serif;background:#f8f9ff;color:#1a1a2e;height:100vh;display:flex;flex-direction:column;overflow:hidden}
  .header{background:$accentHex;padding:18px 24px;display:flex;align-items:center;gap:14px}
  .brand{font-size:22px;font-weight:700;color:#fff;letter-spacing:1px}
  .subtitle{font-size:12px;color:rgba(255,255,255,0.75);margin-top:2px}
  .body{flex:1;padding:20px 24px;overflow:hidden}
  h2{font-size:18px;font-weight:700;color:$accentHex;margin-bottom:14px;padding-bottom:8px;border-bottom:2px solid ${accentHex}22}
  p{font-size:13px;line-height:1.7;color:#333;margin-bottom:10px}
  .card{background:#fff;border-radius:10px;padding:14px 16px;margin-bottom:10px;border-left:4px solid $accentHex;box-shadow:0 2px 8px rgba(0,0,0,0.06)}
  .badge{display:inline-block;background:${accentHex}1a;color:$accentHex;font-size:11px;font-weight:600;padding:3px 10px;border-radius:20px;margin-bottom:10px}
  .row{display:flex;gap:10px;margin-bottom:10px}
  .col{flex:1;background:#fff;border-radius:10px;padding:14px;box-shadow:0 2px 8px rgba(0,0,0,0.06);text-align:center}
  .num{font-size:28px;font-weight:700;color:$accentHex}
  .lbl{font-size:11px;color:#888;margin-top:2px}
  ul{list-style:none;padding:0}
  ul li{font-size:13px;padding:8px 12px;margin-bottom:6px;background:#fff;border-radius:8px;box-shadow:0 1px 4px rgba(0,0,0,0.05);display:flex;align-items:center;gap:8px}
  ul li::before{content:"✓";color:$accentHex;font-weight:700;font-size:14px}
</style></head><body>
<div class="header"><div><div class="brand">$brand</div></div></div>
<div class="body">$content</div>
</body></html>''';

  static String _htmlMoa(String brand, String accent, String className, String desc) =>
    _base(brand, accent, '''
<span class="badge">$className</span>
<h2>Mechanism of Action</h2>
<div class="card"><p>$desc</p></div>
<div class="row">
  <div class="col"><div class="num">↓20%</div><div class="lbl">Systolic BP</div></div>
  <div class="col"><div class="num">↓15%</div><div class="lbl">Diastolic BP</div></div>
  <div class="col"><div class="num">24h</div><div class="lbl">Coverage</div></div>
</div>''');

  static String _htmlEvidence(String brand, String accent, List<(String, String)> trials) {
    final cards = trials.map((t) =>
      '<div class="card"><p><strong>${t.$1}</strong><br>${t.$2}</p></div>').join('');
    return _base(brand, accent, '<h2>Clinical Evidence</h2>$cards');
  }

  static String _htmlDosage(String brand, String accent, String dose, String notes) =>
    _base(brand, accent, '''
<h2>Dosage &amp; Administration</h2>
<div class="card" style="text-align:center;padding:20px">
  <div class="num" style="font-size:24px">$dose</div>
  <div class="lbl" style="margin-top:6px">Recommended Dose</div>
</div>
<div class="card"><p>$notes</p></div>''');

  static String _htmlBenefits(String brand, String accent, List<String> points) {
    final items = points.map((pt) => '<li>$pt</li>').join('');
    return _base(brand, accent, '<h2>Key Benefits</h2><ul>$items</ul>');
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

  Future<void> _seedDcrDemoData(Database db) async {
    // Products matching existing brands
    final products = [
      {'id': 1, 'name': 'CardioMax 80mg Tabs', 'therapy_area': 'Cardiovascular',
       'stock_available': 120, 'allocation_per_doctor': 5},
      {'id': 2, 'name': 'CardioMax 160mg Tabs', 'therapy_area': 'Cardiovascular',
       'stock_available': 60, 'allocation_per_doctor': 3},
      {'id': 3, 'name': 'NeuroVite B-Complex', 'therapy_area': 'Neurology',
       'stock_available': 80, 'allocation_per_doctor': 4},
      {'id': 4, 'name': 'GlucoShield 10mg Tabs', 'therapy_area': 'Diabetology',
       'stock_available': 100, 'allocation_per_doctor': 4},
      {'id': 5, 'name': 'GlucoShield 25mg Tabs', 'therapy_area': 'Diabetology',
       'stock_available': 50, 'allocation_per_doctor': 3},
      {'id': 6, 'name': 'CardioMax Starter Pack', 'therapy_area': 'Cardiovascular',
       'stock_available': 30, 'allocation_per_doctor': 2},
    ];
    for (final p in products) {
      await db.insert('dcr_products', p, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Demo chemists
    final chemists = [
      {'id': 1, 'name': 'Shree Medical Stores', 'area': 'Ahmedabad',
       'territory': 'TER-001', 'address': 'Shop 12, CG Road', 'mobile': '9876543210'},
      {'id': 2, 'name': 'Apollo Pharmacy', 'area': 'Ahmedabad',
       'territory': 'TER-001', 'address': 'Satellite Rd', 'mobile': '9876543211'},
      {'id': 3, 'name': 'Wellness Medical', 'area': 'Gandhinagar',
       'territory': 'TER-002', 'address': 'Sector 21', 'mobile': '9876543212'},
      {'id': 4, 'name': 'City Chemist', 'area': 'Surat',
       'territory': 'TER-002', 'address': 'Ring Road', 'mobile': '9876543213'},
      {'id': 5, 'name': 'MedPlus', 'area': 'Rajkot',
       'territory': 'TER-003', 'address': 'Kalawad Road', 'mobile': '9876543214'},
    ];
    for (final c in chemists) {
      await db.insert('dcr_chemists', c, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Demo employees (co-workers)
    final employees = [
      {'id': 1, 'name': 'Rahul Sharma', 'employee_code': 'EMP-101', 'designation': 'MR'},
      {'id': 2, 'name': 'Kavita Desai', 'employee_code': 'EMP-102', 'designation': 'Sr. MR'},
      {'id': 3, 'name': 'Nitin Joshi', 'employee_code': 'EMP-103', 'designation': 'ABM'},
      {'id': 4, 'name': 'Pooja Mehta', 'employee_code': 'EMP-104', 'designation': 'MR'},
      {'id': 5, 'name': 'Suresh Patil', 'employee_code': 'EMP-105', 'designation': 'ZBM'},
    ];
    for (final e in employees) {
      await db.insert('dcr_employees', e, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
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

  // ─── Cleanup ──────────────────────────────────────────────────────────────────

  Future<void> clearAllData() async {
    final d = await db;
    await d.delete('clm_doctors');
    await d.delete('clm_brands');
    await d.delete('clm_slides');
    await d.delete('clm_media_index');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
