import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/api_constants.dart';
import '../models/ai_hub_models.dart';

class AiHubService {
  static final AiHubService _instance = AiHubService._();
  factory AiHubService() => _instance;
  AiHubService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'ai_hub.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ai_insights (
        id INTEGER PRIMARY KEY,
        module TEXT NOT NULL,
        tag TEXT NOT NULL,
        text TEXT NOT NULL,
        icon_key TEXT DEFAULT 'auto_awesome',
        color_hex TEXT DEFAULT '#1565C0',
        priority INTEGER DEFAULT 5
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_doctor_scores (
        doctor_id INTEGER PRIMARY KEY,
        doctor_name TEXT NOT NULL,
        speciality TEXT,
        engagement_score INTEGER DEFAULT 0,
        engagement_level TEXT DEFAULT 'Medium',
        engagement_color_hex TEXT DEFAULT '#E65100',
        conversion_score INTEGER DEFAULT 0,
        conversion_level TEXT DEFAULT 'Medium',
        conversion_product TEXT,
        days_since_visit INTEGER DEFAULT 0,
        is_flagged INTEGER DEFAULT 0,
        flag_reason TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_playbooks (
        id INTEGER PRIMARY KEY,
        doctor_id INTEGER,
        doctor_name TEXT,
        brand_name TEXT,
        strategy TEXT,
        topics TEXT DEFAULT '[]',
        priority TEXT DEFAULT 'normal'
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_scheduling (
        doctor_id INTEGER PRIMARY KEY,
        doctor_name TEXT,
        suggested_day TEXT,
        reason TEXT,
        icon_key TEXT,
        color_hex TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_product_performance (
        id INTEGER PRIMARY KEY,
        product_name TEXT NOT NULL,
        therapy_area TEXT,
        target_specialities TEXT,
        fit_score INTEGER DEFAULT 0,
        growth_value TEXT,
        growth_positive INTEGER DEFAULT 1,
        total_visits INTEGER DEFAULT 0,
        total_conversions INTEGER DEFAULT 0,
        top_region TEXT,
        monthly_trend TEXT DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_doctor_segments (
        speciality TEXT PRIMARY KEY,
        doctor_count INTEGER DEFAULT 0,
        top_product TEXT,
        color_hex TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_employee_performance (
        id INTEGER PRIMARY KEY,
        employee_code TEXT UNIQUE NOT NULL,
        employee_name TEXT,
        region TEXT,
        performance_score INTEGER DEFAULT 0,
        target_achievement TEXT,
        target_met INTEGER DEFAULT 0,
        total_visits INTEGER DEFAULT 0,
        total_sessions INTEGER DEFAULT 0,
        rank_label TEXT,
        rank_color_hex TEXT,
        coaching_flag INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_hub_cache_meta (
        key TEXT PRIMARY KEY,
        cached_at TEXT NOT NULL
      )
    ''');
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────────

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('clm_auth_token') ?? prefs.getString('auth_token');
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

  // ─── Cache Freshness ──────────────────────────────────────────────────────────

  Future<bool> isCacheFresh(String key, {int maxAgeMinutes = 30}) async {
    final d = await db;
    final rows = await d.query('ai_hub_cache_meta',
        where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return false;
    final cachedAt = DateTime.tryParse(rows.first['cached_at'] as String);
    if (cachedAt == null) return false;
    return DateTime.now().difference(cachedAt).inMinutes < maxAgeMinutes;
  }

  Future<void> _stampCache(String key) async {
    final d = await db;
    await d.insert('ai_hub_cache_meta',
        {'key': key, 'cached_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── Metrics ──────────────────────────────────────────────────────────────────

  Future<Map<String, AiHubMetric>> fetchMetrics(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && await isCacheFresh('metrics')) {
      return _metricsFromCache();
    }
    try {
      final token = await _getToken();
      final headers = token != null ? _headers(token) : <String, String>{};
      final resp = await http
          .get(Uri.parse(ApiConstants.aiHubMetrics), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        if (body['status'] == true && body['metrics'] is Map) {
          final metrics = <String, AiHubMetric>{};
          (body['metrics'] as Map<String, dynamic>).forEach((k, v) {
            metrics[k] = AiHubMetric.fromJson(k, v as Map<String, dynamic>);
          });
          await _stampCache('metrics');
          return metrics;
        }
      }
    } catch (e) {
      debugPrint('[AiHub] metrics fetch error: $e');
    }
    return _metricsFromCache();
  }

  Future<Map<String, AiHubMetric>> _metricsFromCache() async => {};

  // ─── Insights ─────────────────────────────────────────────────────────────────

  Future<List<AiHubInsight>> fetchInsights({bool forceRefresh = false}) async {
    if (!forceRefresh && await isCacheFresh('insights')) {
      return _insightsFromCache();
    }
    try {
      final token = await _getToken();
      final headers = token != null ? _headers(token) : <String, String>{};
      final resp = await http
          .get(Uri.parse('${ApiConstants.aiHubInsights}?limit=8'),
              headers: headers)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        if (body['status'] == true && body['insights'] is List) {
          final insights = (body['insights'] as List)
              .map((i) => AiHubInsight.fromJson(i as Map<String, dynamic>))
              .toList();
          await _saveInsights(insights);
          await _stampCache('insights');
          return insights;
        }
      }
    } catch (e) {
      debugPrint('[AiHub] insights fetch error: $e');
    }
    return _insightsFromCache();
  }

  Future<void> _saveInsights(List<AiHubInsight> items) async {
    final d = await db;
    final batch = d.batch();
    batch.delete('ai_insights');
    for (final i in items) {
      batch.insert('ai_insights', i.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<AiHubInsight>> _insightsFromCache() async {
    final d = await db;
    final rows = await d.query('ai_insights', orderBy: 'priority ASC');
    return rows.map(AiHubInsight.fromDb).toList();
  }

  // ─── Sales Assistant ──────────────────────────────────────────────────────────

  Future<AiSalesAssistantData> fetchSalesAssistant(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && await isCacheFresh('sales_assistant', maxAgeMinutes: 60)) {
      return _salesAssistantFromCache();
    }
    try {
      final token = await _getToken();
      final headers = token != null ? _headers(token) : <String, String>{};
      final resp = await http
          .get(Uri.parse(ApiConstants.aiHubSalesAssistant), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        if (body['status'] == true) {
          final data = _parseSalesAssistantBody(body);
          await _saveSalesAssistantData(data);
          await _stampCache('sales_assistant');
          return data;
        }
      }
    } catch (e) {
      debugPrint('[AiHub] sales assistant fetch error: $e');
    }
    return _salesAssistantFromCache();
  }

  AiSalesAssistantData _parseSalesAssistantBody(Map<String, dynamic> body) {
    final scores = (body['doctor_scores'] as List? ?? [])
        .map((j) => AiDoctorScore.fromJson(j as Map<String, dynamic>))
        .toList();
    final playbooks = (body['playbooks'] as List? ?? [])
        .map((j) => AiPlaybook.fromJson(j as Map<String, dynamic>))
        .toList();
    final scheduling = (body['scheduling'] as List? ?? [])
        .map((j) => AiSchedule.fromJson(j as Map<String, dynamic>))
        .toList();
    final segments = (body['segments'] as List? ?? [])
        .map((j) => AiDoctorSegment.fromJson(j as Map<String, dynamic>))
        .toList();
    final productFit = (body['product_fit'] as List? ?? [])
        .map((j) => AiProductPerformance.fromJson(j as Map<String, dynamic>))
        .toList();
    final obs = body['observation'] != null
        ? AiHubInsight.fromJson(body['observation'] as Map<String, dynamic>)
        : null;
    return AiSalesAssistantData(
      doctorScores: scores,
      playbooks:    playbooks,
      scheduling:   scheduling,
      segments:     segments,
      productFit:   productFit,
      observation:  obs,
    );
  }

  Future<void> _saveSalesAssistantData(AiSalesAssistantData data) async {
    final d = await db;
    final batch = d.batch();

    batch.delete('ai_doctor_scores');
    for (final s in data.doctorScores) {
      batch.insert('ai_doctor_scores', s.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    batch.delete('ai_playbooks');
    for (final p in data.playbooks) {
      batch.insert('ai_playbooks', p.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    batch.delete('ai_scheduling');
    for (final s in data.scheduling) {
      batch.insert('ai_scheduling', s.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    batch.delete('ai_doctor_segments');
    for (final s in data.segments) {
      batch.insert('ai_doctor_segments', s.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<AiSalesAssistantData> _salesAssistantFromCache() async {
    final d = await db;
    final scores = (await d.query('ai_doctor_scores',
            orderBy: 'engagement_score DESC'))
        .map(AiDoctorScore.fromDb)
        .toList();
    final playbooks = (await d.query('ai_playbooks'))
        .map(AiPlaybook.fromDb)
        .toList();
    final scheduling = (await d.query('ai_scheduling'))
        .map(AiSchedule.fromDb)
        .toList();
    final segments = (await d.query('ai_doctor_segments',
            orderBy: 'doctor_count DESC'))
        .map(AiDoctorSegment.fromDb)
        .toList();
    final insightRow = await d.query('ai_insights',
        where: 'module = ?', whereArgs: ['sales'], limit: 1);
    final obs = insightRow.isNotEmpty
        ? AiHubInsight.fromDb(insightRow.first)
        : null;
    return AiSalesAssistantData(
      doctorScores: scores,
      playbooks:    playbooks,
      scheduling:   scheduling,
      segments:     segments,
      observation:  obs,
    );
  }

  // ─── Product Performance ──────────────────────────────────────────────────────

  Future<AiProductData> fetchProductPerformance(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && await isCacheFresh('product_performance', maxAgeMinutes: 60)) {
      return _productFromCache();
    }
    try {
      final token = await _getToken();
      final headers = token != null ? _headers(token) : <String, String>{};
      final resp = await http
          .get(Uri.parse(ApiConstants.aiHubProductPerformance), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        if (body['status'] == true) {
          final products = (body['products'] as List? ?? [])
              .map((j) =>
                  AiProductPerformance.fromJson(j as Map<String, dynamic>))
              .toList();
          final d = await db;
          final batch = d.batch();
          batch.delete('ai_product_performance');
          for (final p in products) {
            batch.insert('ai_product_performance', p.toDb(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
          await _stampCache('product_performance');

          final obs = body['observation'] != null
              ? AiHubInsight.fromJson(
                  body['observation'] as Map<String, dynamic>)
              : null;
          return AiProductData(
            products:         products,
            totalVisits:      int.tryParse(body['total_visits']?.toString() ?? '0') ?? 0,
            totalConversions: int.tryParse(body['total_conversions']?.toString() ?? '0') ?? 0,
            conversionRate:   double.tryParse(body['conversion_rate']?.toString() ?? '0') ?? 0,
            topProduct:       body['top_product']?.toString(),
            observation:      obs,
          );
        }
      }
    } catch (e) {
      debugPrint('[AiHub] product performance fetch error: $e');
    }
    return _productFromCache();
  }

  Future<AiProductData> _productFromCache() async {
    final d = await db;
    final products = (await d.query('ai_product_performance',
            orderBy: 'fit_score DESC'))
        .map(AiProductPerformance.fromDb)
        .toList();
    final insightRow = await d.query('ai_insights',
        where: 'module = ?', whereArgs: ['product'], limit: 1);
    final obs = insightRow.isNotEmpty
        ? AiHubInsight.fromDb(insightRow.first)
        : null;
    return AiProductData(products: products, observation: obs);
  }

  // ─── Doctor Review ────────────────────────────────────────────────────────────

  Future<AiDoctorReviewData> fetchDoctorReview(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && await isCacheFresh('doctor_review', maxAgeMinutes: 60)) {
      return _doctorReviewFromCache();
    }
    try {
      final token = await _getToken();
      final headers = token != null ? _headers(token) : <String, String>{};
      final resp = await http
          .get(Uri.parse(ApiConstants.aiHubDoctorReview), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        if (body['status'] == true) {
          final doctors = (body['doctors'] as List? ?? [])
              .map((j) => AiDoctorScore.fromJson(j as Map<String, dynamic>))
              .toList();
          final d = await db;
          final batch = d.batch();
          batch.delete('ai_doctor_scores');
          for (final doc in doctors) {
            batch.insert('ai_doctor_scores', doc.toDb(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
          await _stampCache('doctor_review');

          final obs = body['observation'] != null
              ? AiHubInsight.fromJson(
                  body['observation'] as Map<String, dynamic>)
              : null;
          return AiDoctorReviewData(
            doctors:       doctors,
            flaggedCount:  int.tryParse(body['flagged_count']?.toString() ?? '0') ?? 0,
            highCount:     int.tryParse(body['high_count']?.toString() ?? '0') ?? 0,
            atRiskCount:   int.tryParse(body['at_risk_count']?.toString() ?? '0') ?? 0,
            avgEngagement: double.tryParse(body['avg_engagement']?.toString() ?? '0') ?? 0,
            observation:   obs,
          );
        }
      }
    } catch (e) {
      debugPrint('[AiHub] doctor review fetch error: $e');
    }
    return _doctorReviewFromCache();
  }

  Future<AiDoctorReviewData> _doctorReviewFromCache() async {
    final d = await db;
    final doctors = (await d.query('ai_doctor_scores',
            orderBy: 'is_flagged DESC, engagement_score ASC'))
        .map(AiDoctorScore.fromDb)
        .toList();
    final insightRow = await d.query('ai_insights',
        where: 'module = ?', whereArgs: ['doctor'], limit: 1);
    final obs = insightRow.isNotEmpty
        ? AiHubInsight.fromDb(insightRow.first)
        : null;
    return AiDoctorReviewData(doctors: doctors, observation: obs);
  }

  // ─── Employee Performance ─────────────────────────────────────────────────────

  Future<AiEmployeeData> fetchEmployeePerformance(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && await isCacheFresh('employee_performance', maxAgeMinutes: 60)) {
      return _employeeFromCache();
    }
    try {
      final token = await _getToken();
      final headers = token != null ? _headers(token) : <String, String>{};
      final resp = await http
          .get(Uri.parse(ApiConstants.aiHubEmployeePerformance), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        if (body['status'] == true) {
          final employees = (body['employees'] as List? ?? [])
              .map((j) =>
                  AiEmployeePerformance.fromJson(j as Map<String, dynamic>))
              .toList();
          final d = await db;
          final batch = d.batch();
          batch.delete('ai_employee_performance');
          for (final e in employees) {
            batch.insert('ai_employee_performance', e.toDb(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
          await _stampCache('employee_performance');

          final obs = body['observation'] != null
              ? AiHubInsight.fromJson(
                  body['observation'] as Map<String, dynamic>)
              : null;
          final regions = (body['regions'] as List? ?? [])
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          return AiEmployeeData(
            employees:      employees,
            coachingNeeded: int.tryParse(body['coaching_needed']?.toString() ?? '0') ?? 0,
            topPerformers:  int.tryParse(body['top_performers']?.toString() ?? '0') ?? 0,
            avgScore:       double.tryParse(body['avg_score']?.toString() ?? '0') ?? 0,
            targetMet:      int.tryParse(body['target_met']?.toString() ?? '0') ?? 0,
            total:          int.tryParse(body['total']?.toString() ?? '0') ?? 0,
            regions:        regions,
            observation:    obs,
          );
        }
      }
    } catch (e) {
      debugPrint('[AiHub] employee performance fetch error: $e');
    }
    return _employeeFromCache();
  }

  Future<AiEmployeeData> _employeeFromCache() async {
    final d = await db;
    final employees = (await d.query('ai_employee_performance',
            orderBy: 'performance_score DESC'))
        .map(AiEmployeePerformance.fromDb)
        .toList();
    final insightRow = await d.query('ai_insights',
        where: 'module = ?', whereArgs: ['employee'], limit: 1);
    final obs = insightRow.isNotEmpty
        ? AiHubInsight.fromDb(insightRow.first)
        : null;
    return AiEmployeeData(
      employees:     employees,
      total:         employees.length,
      coachingNeeded: employees.where((e) => e.coachingFlag).length,
      topPerformers: employees.where((e) => e.rankLabel == 'Top Performer').length,
      observation:   obs,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
