import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';
import '../data/models/data_bank_models.dart';
import '../data/services/data_bank_service.dart';

class DataBankProvider extends ChangeNotifier {
  final DataBankService _svc = DataBankService();

  // ─── State ────────────────────────────────────────────────────────────────────
  List<DataBankCategory> _categories = [];
  List<DataBankMaterial> _featured = [];
  List<DataBankMaterial> _mandatory = [];
  List<DataBankMaterial> _currentList = [];
  List<DataBankMaterial> _searchResults = [];
  DataBankUserStats _userStats = const DataBankUserStats();

  String _searchQuery = '';
  bool _isLoading = false;
  bool _isSearching = false;
  DataBankCategory? _activeCategory;
  String _employeeCode = '';

  // ─── Getters ──────────────────────────────────────────────────────────────────
  List<DataBankCategory> get categories => _categories;
  List<DataBankMaterial> get featured => _featured;
  List<DataBankMaterial> get mandatory => _mandatory;
  List<DataBankMaterial> get currentList => _currentList;
  List<DataBankMaterial> get searchResults => _searchResults;
  DataBankUserStats get userStats => _userStats;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  DataBankCategory? get activeCategory => _activeCategory;

  int get mandatoryPendingCount =>
      mandatory.where((m) => !m.userCompleted).length;

  // ─── Init ─────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _employeeCode = prefs.getString('employee_code') ?? '';
    final token  = prefs.getString('auth_token') ?? '';

    // Load from cache first so the UI shows immediately
    await _loadAll();

    // Then sync from API in the background
    if (token.isNotEmpty) {
      syncFromApi(token: token).catchError((e) {
        debugPrint('[DataBank] Background sync error: $e');
      });
    }
  }

  // ─── API Sync ─────────────────────────────────────────────────────────────────

  Future<void> clearAndResync({required String token}) async {
    _isLoading = true;
    _categories = [];
    _featured = [];
    _mandatory = [];
    _currentList = [];
    notifyListeners();

    await _svc.clearAllData();
    await syncFromApi(token: token);
  }

  Future<void> syncFromApi({required String token}) async {
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };

    try {
      // 1. Categories
      final catRes = await http.get(
        Uri.parse(ApiConstants.dataBankCategories),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (catRes.statusCode == 200) {
        final body = json.decode(catRes.body);
        final rows = (body['data'] as List).cast<Map<String, dynamic>>();
        await _svc.upsertCategories(rows);
      }

      // 2. Materials (with user completion sub-queries from server)
      final matRes = await http.get(
        Uri.parse(ApiConstants.dataBankMaterials),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (matRes.statusCode == 200) {
        final body = json.decode(matRes.body);
        final rows = (body['data'] as List).cast<Map<String, dynamic>>();
        await _svc.upsertMaterials(rows);
      }

      // 3. Reload UI with fresh data
      await _loadAll();
    } catch (e) {
      debugPrint('[DataBank] syncFromApi error: $e');
    }
  }

  Future<void> _loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        _loadCategories(),
        _loadFeatured(),
        _loadMandatory(),
        _loadUserStats(),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCategories() async {
    _categories = await _svc.getCategories();
  }

  Future<void> _loadFeatured() async {
    _featured = await _svc.getFeaturedMaterials(_employeeCode);
  }

  Future<void> _loadMandatory() async {
    _mandatory = await _svc.getMandatoryMaterials(_employeeCode);
  }

  Future<void> _loadUserStats() async {
    _userStats = await _svc.getUserStats(_employeeCode);
  }

  // ─── Download ────────────────────────────────────────────────────────────────

  // Tracks per-material download progress 0.0–1.0
  final Map<String, double> _downloadProgress = {};
  Map<String, double> get downloadProgress => _downloadProgress;

  bool isDownloading(String materialId) =>
      _downloadProgress.containsKey(materialId);

  Future<void> downloadMaterial(DataBankMaterial material) async {
    if (isDownloading(material.id)) return;

    _downloadProgress[material.id] = 0.0;
    notifyListeners();

    final path = await _svc.downloadMaterial(
      material,
      onProgress: (p) {
        _downloadProgress[material.id] = p;
        notifyListeners();
      },
    );

    _downloadProgress.remove(material.id);

    if (path != null) {
      material.isDownloaded = true;
      material.localPath = path;
    }

    await _loadAll();
    notifyListeners();
  }

  Future<void> deleteDownload(DataBankMaterial material) async {
    await _svc.deleteDownload(material.id);
    material.isDownloaded = false;
    material.localPath = null;
    await _loadAll();
    notifyListeners();
  }

  // ─── Category List ────────────────────────────────────────────────────────────

  Future<void> loadCategory(DataBankCategory category) async {
    _activeCategory = category;
    _isLoading = true;
    notifyListeners();
    try {
      _currentList =
          await _svc.getMaterialsByCategory(category.id, _employeeCode);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearCategory() {
    _activeCategory = null;
    _currentList = [];
    notifyListeners();
  }

  // ─── Search ───────────────────────────────────────────────────────────────────

  Future<void> search(String query) async {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    try {
      _searchResults = await _svc.searchMaterials(query, _employeeCode);
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }

  // ─── Bookmark ─────────────────────────────────────────────────────────────────

  Future<void> toggleBookmark(DataBankMaterial material) async {
    await _svc.toggleBookmark(material.id);
    material.isBookmarked = !material.isBookmarked;
    await _loadUserStats();
    notifyListeners();
  }

  // ─── View Tracking ────────────────────────────────────────────────────────────

  Future<String> startView(String materialId) async {
    return _svc.startView(materialId, _employeeCode);
  }

  Future<void> updateView(
      String logId, int durationSeconds, bool completed) async {
    await _svc.updateView(logId, durationSeconds, completed);
    // Refresh stats and lists in background
    await _loadUserStats();
    await _loadMandatory();
    await _loadFeatured();
    notifyListeners();
  }

  Future<DataBankMaterial?> getMaterialById(String id) async {
    return _svc.getMaterialById(id, _employeeCode);
  }

  Future<void> refresh() async => _loadAll();
}
