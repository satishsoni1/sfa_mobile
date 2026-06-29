import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/data_bank_models.dart';

class DataBankService {
  static final DataBankService _instance = DataBankService._();
  factory DataBankService() => _instance;
  DataBankService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'data_bank.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE db_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        icon_key TEXT DEFAULT 'folder',
        color_hex TEXT DEFAULT '#4A148C',
        sort_order INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE db_materials (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        type TEXT DEFAULT 'pdf',
        thumbnail_url TEXT,
        source_url TEXT NOT NULL,
        file_size_kb INTEGER DEFAULT 0,
        duration_seconds INTEGER,
        is_downloaded INTEGER DEFAULT 0,
        local_path TEXT,
        published_at TEXT NOT NULL,
        tags TEXT DEFAULT '[]',
        is_mandatory INTEGER DEFAULT 0,
        is_featured INTEGER DEFAULT 0,
        view_count INTEGER DEFAULT 0,
        completion_count INTEGER DEFAULT 0,
        is_bookmarked INTEGER DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES db_categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE db_view_logs (
        id TEXT PRIMARY KEY,
        material_id TEXT NOT NULL,
        employee_code TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        duration_seconds INTEGER DEFAULT 0,
        completed INTEGER DEFAULT 0,
        FOREIGN KEY (material_id) REFERENCES db_materials(id)
      )
    ''');

  }

  // ─── API Upsert ───────────────────────────────────────────────────────────────

  Future<void> upsertCategories(List<Map<String, dynamic>> rows) async {
    final d = await db;
    final batch = d.batch();
    for (final row in rows) {
      batch.insert('db_categories', {
        'id':          row['id'].toString(),
        'name':        row['name'] ?? '',
        'description': row['description'] ?? '',
        'icon_key':    row['icon_key'] ?? 'folder',
        'color_hex':   row['color_hex'] ?? '#4A148C',
        'sort_order':  row['sort_order'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertMaterials(List<Map<String, dynamic>> rows) async {
    final d = await db;
    final batch = d.batch();
    for (final row in rows) {
      batch.insert('db_materials', {
        'id':               row['id'].toString(),
        'category_id':      row['category_id'].toString(),
        'title':            row['title'] ?? '',
        'description':      row['description'] ?? '',
        'type':             row['type'] ?? 'pdf',
        'thumbnail_url':    row['thumbnail_url'],
        'source_url':       row['source_url'] ?? '',
        'file_size_kb':     row['file_size_kb'] ?? 0,
        'duration_seconds': row['duration_seconds'],
        'published_at':     row['published_at'] ?? DateTime.now().toIso8601String(),
        'tags':             row['tags'] is List
            ? json.encode(row['tags'])
            : (row['tags'] ?? '[]'),
        'is_mandatory':     (row['is_mandatory'] == true || row['is_mandatory'] == 1) ? 1 : 0,
        'is_featured':      (row['is_featured'] == true || row['is_featured'] == 1) ? 1 : 0,
        'view_count':       row['view_count'] ?? 0,
        'completion_count': row['completion_count'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<bool> hasCachedData() async {
    final d = await db;
    final r = await d.rawQuery('SELECT COUNT(*) as cnt FROM db_categories');
    return (r.first['cnt'] as int? ?? 0) > 0;
  }

  Future<void> clearAllData() async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.execute('DELETE FROM db_view_logs');
      await txn.execute('DELETE FROM db_materials');
      await txn.execute('DELETE FROM db_categories');
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ─── Offline Download ────────────────────────────────────────────────────────

  /// Downloads a material file to local storage and marks it downloaded in DB.
  /// Returns the local file path on success, null on failure.
  Future<String?> downloadMaterial(
    DataBankMaterial material, {
    ValueChanged<double>? onProgress,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory(p.join(dir.path, 'data_bank'));
      await folder.create(recursive: true);

      final ext = _extForType(material.type, material.sourceUrl);
      final filePath = p.join(folder.path, 'mat_${material.id}$ext');

      final file = File(filePath);
      if (file.existsSync()) {
        await _markDownloaded(material.id, filePath);
        return filePath;
      }

      final request = http.Request('GET', Uri.parse(material.sourceUrl));
      final response = await request.send().timeout(const Duration(minutes: 10));

      if (response.statusCode != 200) return null;

      final total = response.contentLength ?? 0;
      int received = 0;
      final sink = file.openWrite();

      await response.stream.listen((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }).asFuture();

      await sink.flush();
      await sink.close();

      await _markDownloaded(material.id, filePath);
      return filePath;
    } catch (e) {
      debugPrint('[DataBank] Download error ${material.id}: $e');
      return null;
    }
  }

  Future<void> _markDownloaded(String materialId, String filePath) async {
    final d = await db;
    await d.update(
      'db_materials',
      {'is_downloaded': 1, 'local_path': filePath},
      where: 'id = ?',
      whereArgs: [materialId],
    );
  }

  Future<void> deleteDownload(String materialId) async {
    final d = await db;
    final rows = await d.query('db_materials',
        columns: ['local_path'], where: 'id = ?', whereArgs: [materialId]);
    final path = rows.isNotEmpty ? rows.first['local_path'] as String? : null;
    if (path != null) {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    }
    await d.update('db_materials',
        {'is_downloaded': 0, 'local_path': null},
        where: 'id = ?', whereArgs: [materialId]);
  }

  String _extForType(DataBankMaterialType type, String url) {
    switch (type) {
      case DataBankMaterialType.video: return '.mp4';
      case DataBankMaterialType.image: return '.jpg';
      case DataBankMaterialType.pdf:   return '.pdf';
      case DataBankMaterialType.link:  return '.html';
    }
  }

  // ─── Categories ───────────────────────────────────────────────────────────────

  Future<List<DataBankCategory>> getCategories() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT c.*,
        COUNT(m.id) AS material_count,
        SUM(m.is_mandatory) AS mandatory_count
      FROM db_categories c
      LEFT JOIN db_materials m ON m.category_id = c.id
      GROUP BY c.id
      ORDER BY c.sort_order ASC
    ''');
    return rows.map(DataBankCategory.fromDb).toList();
  }

  // ─── Materials ────────────────────────────────────────────────────────────────

  Future<List<DataBankMaterial>> getMaterialsByCategory(
      String categoryId, String employeeCode) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT m.*,
        COALESCE(l.duration_seconds, 0) AS user_duration,
        COALESCE(l.completed, 0) AS user_completed,
        l.started_at AS user_last_viewed
      FROM db_materials m
      LEFT JOIN db_view_logs l ON l.material_id = m.id
        AND l.employee_code = ?
        AND l.id = (
          SELECT id FROM db_view_logs
          WHERE material_id = m.id AND employee_code = ?
          ORDER BY started_at DESC LIMIT 1
        )
      WHERE m.category_id = ?
      ORDER BY m.is_mandatory DESC, m.published_at DESC
    ''', [employeeCode, employeeCode, categoryId]);
    return rows.map(DataBankMaterial.fromDb).toList();
  }

  Future<List<DataBankMaterial>> getFeaturedMaterials(
      String employeeCode) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT m.*,
        COALESCE(l.duration_seconds, 0) AS user_duration,
        COALESCE(l.completed, 0) AS user_completed,
        l.started_at AS user_last_viewed
      FROM db_materials m
      LEFT JOIN db_view_logs l ON l.material_id = m.id
        AND l.employee_code = ?
        AND l.id = (
          SELECT id FROM db_view_logs
          WHERE material_id = m.id AND employee_code = ?
          ORDER BY started_at DESC LIMIT 1
        )
      WHERE m.is_featured = 1
      ORDER BY m.published_at DESC
      LIMIT 8
    ''', [employeeCode, employeeCode]);
    return rows.map(DataBankMaterial.fromDb).toList();
  }

  Future<List<DataBankMaterial>> getMandatoryMaterials(
      String employeeCode) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT m.*,
        COALESCE(l.duration_seconds, 0) AS user_duration,
        COALESCE(l.completed, 0) AS user_completed,
        l.started_at AS user_last_viewed
      FROM db_materials m
      LEFT JOIN db_view_logs l ON l.material_id = m.id
        AND l.employee_code = ?
        AND l.id = (
          SELECT id FROM db_view_logs
          WHERE material_id = m.id AND employee_code = ?
          ORDER BY started_at DESC LIMIT 1
        )
      WHERE m.is_mandatory = 1
      ORDER BY m.published_at DESC
    ''', [employeeCode, employeeCode]);
    return rows.map(DataBankMaterial.fromDb).toList();
  }

  Future<List<DataBankMaterial>> searchMaterials(
      String query, String employeeCode) async {
    if (query.trim().isEmpty) return [];
    final d = await db;
    final q = '%${query.toLowerCase()}%';
    final rows = await d.rawQuery('''
      SELECT m.*,
        COALESCE(l.duration_seconds, 0) AS user_duration,
        COALESCE(l.completed, 0) AS user_completed,
        l.started_at AS user_last_viewed
      FROM db_materials m
      LEFT JOIN db_view_logs l ON l.material_id = m.id
        AND l.employee_code = ?
        AND l.id = (
          SELECT id FROM db_view_logs
          WHERE material_id = m.id AND employee_code = ?
          ORDER BY started_at DESC LIMIT 1
        )
      WHERE LOWER(m.title) LIKE ? OR LOWER(m.description) LIKE ? OR LOWER(m.tags) LIKE ?
      ORDER BY m.is_mandatory DESC, m.view_count DESC
      LIMIT 30
    ''', [employeeCode, employeeCode, q, q, q]);
    return rows.map(DataBankMaterial.fromDb).toList();
  }

  Future<DataBankMaterial?> getMaterialById(
      String id, String employeeCode) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT m.*,
        COALESCE(l.duration_seconds, 0) AS user_duration,
        COALESCE(l.completed, 0) AS user_completed,
        l.started_at AS user_last_viewed
      FROM db_materials m
      LEFT JOIN db_view_logs l ON l.material_id = m.id
        AND l.employee_code = ?
        AND l.id = (
          SELECT id FROM db_view_logs
          WHERE material_id = m.id AND employee_code = ?
          ORDER BY started_at DESC LIMIT 1
        )
      WHERE m.id = ?
      LIMIT 1
    ''', [employeeCode, employeeCode, id]);
    return rows.isEmpty ? null : DataBankMaterial.fromDb(rows.first);
  }

  // ─── Bookmark ─────────────────────────────────────────────────────────────────

  Future<void> toggleBookmark(String materialId) async {
    final d = await db;
    final current = await d.rawQuery(
        'SELECT is_bookmarked FROM db_materials WHERE id = ?', [materialId]);
    if (current.isEmpty) return;
    final val = (current.first['is_bookmarked'] as int? ?? 0) == 1 ? 0 : 1;
    await d.update('db_materials', {'is_bookmarked': val},
        where: 'id = ?', whereArgs: [materialId]);
  }

  // ─── View Tracking ────────────────────────────────────────────────────────────

  Future<String> startView(String materialId, String employeeCode) async {
    final d = await db;
    final id = const Uuid().v4();
    await d.insert('db_view_logs', {
      'id': id,
      'material_id': materialId,
      'employee_code': employeeCode,
      'started_at': DateTime.now().toIso8601String(),
      'duration_seconds': 0,
      'completed': 0,
    });
    // Increment view count
    await d.rawUpdate(
        'UPDATE db_materials SET view_count = view_count + 1 WHERE id = ?',
        [materialId]);
    return id;
  }

  Future<void> updateView(
      String logId, int durationSeconds, bool completed) async {
    final d = await db;
    await d.update(
      'db_view_logs',
      {
        'ended_at': DateTime.now().toIso8601String(),
        'duration_seconds': durationSeconds,
        'completed': completed ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [logId],
    );
    if (completed) {
      final row = await d.rawQuery(
          'SELECT material_id FROM db_view_logs WHERE id = ?', [logId]);
      if (row.isNotEmpty) {
        await d.rawUpdate(
            'UPDATE db_materials SET completion_count = completion_count + 1 WHERE id = ?',
            [row.first['material_id']]);
      }
    }
  }

  // ─── User Stats ───────────────────────────────────────────────────────────────

  Future<DataBankUserStats> getUserStats(String employeeCode) async {
    final d = await db;

    final viewed = await d.rawQuery('''
      SELECT COUNT(DISTINCT material_id) AS cnt FROM db_view_logs
      WHERE employee_code = ?
    ''', [employeeCode]);
    final totalViewed = viewed.first['cnt'] as int? ?? 0;

    final completed = await d.rawQuery('''
      SELECT COUNT(DISTINCT material_id) AS cnt FROM db_view_logs
      WHERE employee_code = ? AND completed = 1
    ''', [employeeCode]);
    final totalCompleted = completed.first['cnt'] as int? ?? 0;

    final mandatory = await d.rawQuery('''
      SELECT COUNT(*) AS cnt FROM db_materials m
      WHERE m.is_mandatory = 1
        AND NOT EXISTS (
          SELECT 1 FROM db_view_logs l
          WHERE l.material_id = m.id AND l.employee_code = ? AND l.completed = 1
        )
    ''', [employeeCode]);
    final mandatoryPending = mandatory.first['cnt'] as int? ?? 0;

    final bookmarked = await d.rawQuery(
        'SELECT COUNT(*) AS cnt FROM db_materials WHERE is_bookmarked = 1');
    final bookmarkedCount = bookmarked.first['cnt'] as int? ?? 0;

    final duration = await d.rawQuery('''
      SELECT COALESCE(SUM(duration_seconds), 0) AS total FROM db_view_logs
      WHERE employee_code = ?
    ''', [employeeCode]);
    final totalSecs = duration.first['total'] as int? ?? 0;

    return DataBankUserStats(
      totalViewed: totalViewed,
      totalCompleted: totalCompleted,
      mandatoryPending: mandatoryPending,
      bookmarked: bookmarkedCount,
      totalViewTimeMinutes: totalSecs ~/ 60,
    );
  }

  // ─── View Logs for a material ──────────────────────────────────────────────────

  Future<List<DataBankViewLog>> getViewLogs(String materialId) async {
    final d = await db;
    final rows = await d.query('db_view_logs',
        where: 'material_id = ?',
        whereArgs: [materialId],
        orderBy: 'started_at DESC',
        limit: 50);
    return rows.map(DataBankViewLog.fromDb).toList();
  }
}
