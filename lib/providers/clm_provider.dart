import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/clm_models.dart';
import '../data/services/clm_ai_service.dart';
import '../data/services/clm_analytics_service.dart';
import '../data/services/clm_database_service.dart';
import '../data/services/clm_sync_service.dart';

class ClmProvider extends ChangeNotifier {
  final ClmDatabaseService _db = ClmDatabaseService();
  final ClmSyncService _sync = ClmSyncService();
  final ClmAnalyticsService _analytics = ClmAnalyticsService();

  // ─── Doctor List ──────────────────────────────────────────────────────────────
  List<ClmDoctor> _allDoctors = [];
  List<ClmDoctor> _filteredDoctors = [];
  String _searchQuery = '';
  String _filterSpeciality = '';
  String _filterCategory = '';
  String _filterTerritory = '';
  bool _showPlannedOnly = false;

  List<ClmDoctor> get filteredDoctors => _filteredDoctors;
  String get searchQuery => _searchQuery;
  String get filterSpeciality => _filterSpeciality;
  String get filterCategory => _filterCategory;
  bool get showPlannedOnly => _showPlannedOnly;

  // ─── Brands & Slides ─────────────────────────────────────────────────────────
  List<ClmBrand> _allBrands = [];
  List<ClmBrand> get allBrands => _allBrands;

  // ─── Cart ─────────────────────────────────────────────────────────────────────
  final List<ClmCartItem> _cart = [];
  List<ClmCartItem> get cart => _cart;
  int get cartSlideCount =>
      _cart.fold(0, (sum, item) => sum + item.slides.length);

  // ─── Session ──────────────────────────────────────────────────────────────────
  ClmSession? _activeSession;
  ClmSession? get activeSession => _activeSession;

  // ─── Liked Brands ─────────────────────────────────────────────────────────────
  final Set<int> _likedBrandIds = {};
  Set<int> get likedBrandIds => _likedBrandIds;

  // ─── Sync ─────────────────────────────────────────────────────────────────────
  ClmSyncStatus _syncStatus = const ClmSyncStatus();
  ClmSyncStatus get syncStatus => _syncStatus;

  // ─── Dashboard Stats ──────────────────────────────────────────────────────────
  Map<String, int> _todayStats = {};
  Map<String, int> get todayStats => _todayStats;
  List<ClmSession> _recentSessions = [];
  List<ClmSession> get recentSessions => _recentSessions;
  int _pendingUploads = 0;
  int get pendingUploads => _pendingUploads;

  // ─── Loading flags ────────────────────────────────────────────────────────────
  bool _isLoadingDoctors = false;
  bool _isLoadingBrands = false;
  bool get isLoadingDoctors => _isLoadingDoctors;
  bool get isLoadingBrands => _isLoadingBrands;

  ClmProvider() {
    _sync.statusStream.listen((status) {
      _syncStatus = status;
      notifyListeners();
    });
  }

  // ─── Initialise ───────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Load whatever is already cached so the UI is instantly responsive
    await loadDoctors();
    await loadBrands();
    await loadDashboardStats();
    await _loadLikedBrands();
    await _restoreIncompleteSession();

    final online = await _sync.isOnline();
    if (online) {
      // Pull fresh master data (CLM + DCR) then reload UI
      unawaited(_sync.fullSync().then((_) async {
        await loadDoctors();
        await loadBrands();
        await loadDashboardStats();
        notifyListeners();
      }));
    }
  }

  Future<void> _loadLikedBrands() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('clm_liked_brands') ?? [];
    _likedBrandIds.addAll(ids.map(int.parse));
    notifyListeners();
  }

  bool isBrandLiked(int brandId) => _likedBrandIds.contains(brandId);

  Future<void> toggleBrandLike(int brandId) async {
    if (_likedBrandIds.contains(brandId)) {
      _likedBrandIds.remove(brandId);
    } else {
      _likedBrandIds.add(brandId);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'clm_liked_brands', _likedBrandIds.map((e) => e.toString()).toList());
  }

  // ─── Doctor Loading ───────────────────────────────────────────────────────────

  Future<void> loadDoctors() async {
    _isLoadingDoctors = true;
    notifyListeners();
    try {
      _allDoctors = await _db.getAllDoctors();
      _applyFilters();
    } finally {
      _isLoadingDoctors = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    _applyFilters();
    notifyListeners();
  }

  void setFilterSpeciality(String s) {
    _filterSpeciality = s;
    _applyFilters();
    notifyListeners();
  }

  void setFilterCategory(String c) {
    _filterCategory = c;
    _applyFilters();
    notifyListeners();
  }

  void setFilterTerritory(String t) {
    _filterTerritory = t;
    _applyFilters();
    notifyListeners();
  }

  void togglePlannedOnly() {
    _showPlannedOnly = !_showPlannedOnly;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _filterSpeciality = '';
    _filterCategory = '';
    _filterTerritory = '';
    _showPlannedOnly = false;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    var list = _allDoctors;

    if (_showPlannedOnly) {
      list = list.where((d) => d.isPlanned).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((d) =>
          d.name.toLowerCase().contains(q) ||
          d.speciality.toLowerCase().contains(q) ||
          (d.hospital?.toLowerCase().contains(q) ?? false) ||
          d.area.toLowerCase().contains(q)).toList();
    }
    if (_filterSpeciality.isNotEmpty) {
      list = list.where((d) => d.speciality == _filterSpeciality).toList();
    }
    if (_filterCategory.isNotEmpty) {
      list = list.where((d) => d.category == _filterCategory).toList();
    }
    if (_filterTerritory.isNotEmpty) {
      list = list.where((d) => d.territory == _filterTerritory).toList();
    }

    _filteredDoctors = list;
  }

  Future<List<String>> getDistinctSpecialities() =>
      _db.getDistinctSpecialities();
  Future<List<String>> getDistinctTerritories() =>
      _db.getDistinctTerritories();

  // ─── Brand Loading ────────────────────────────────────────────────────────────

  Future<void> loadBrands() async {
    _isLoadingBrands = true;
    notifyListeners();
    try {
      _allBrands = await _db.getAllBrands();
    } finally {
      _isLoadingBrands = false;
      notifyListeners();
    }
  }

  Future<List<ClmBrand>> getBrandsForDoctor(ClmDoctor doctor) async {
    if (doctor.assignedBrandIds.isEmpty) return _allBrands;
    return _db.getBrandsForDoctor(doctor.assignedBrandIds);
  }

  Future<List<ClmSlide>> getSlidesForBrand(int brandId) =>
      _db.getSlidesForBrand(brandId);

  // ─── Cart Management ──────────────────────────────────────────────────────────

  Future<void> buildCartForDoctor(ClmDoctor doctor) async {
    _cart.clear();
    final brands = await getBrandsForDoctor(doctor);
    int seq = 0;
    for (final brand in brands) {
      final slides = await _db.getSlidesForBrand(brand.id);
      if (slides.isNotEmpty) {
        _cart.add(ClmCartItem(brand: brand, slides: slides, cartSequence: seq++));
      }
    }
    notifyListeners();
  }

  void addBrandToCart(ClmBrand brand, List<ClmSlide> slides) {
    if (_cart.any((item) => item.brand.id == brand.id)) return;
    _cart.add(ClmCartItem(
      brand: brand,
      slides: slides,
      cartSequence: _cart.length,
    ));
    notifyListeners();
  }

  void removeBrandFromCart(int brandId) {
    _cart.removeWhere((item) => item.brand.id == brandId);
    // Renumber
    for (int i = 0; i < _cart.length; i++) {
      _cart[i].cartSequence = i;
    }
    notifyListeners();
  }

  void reorderCart(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = _cart.removeAt(oldIndex);
    _cart.insert(newIndex, item);
    for (int i = 0; i < _cart.length; i++) {
      _cart[i].cartSequence = i;
    }
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  /// Returns flat ordered list of all slides across all cart brands.
  List<ClmSlide> getFlatSlideList() {
    final slides = <ClmSlide>[];
    final sorted = List<ClmCartItem>.from(_cart)
      ..sort((a, b) => a.cartSequence.compareTo(b.cartSequence));
    for (final item in sorted) {
      slides.addAll(item.sortedSlides);
    }
    return slides;
  }

  // ─── Session Management ───────────────────────────────────────────────────────

  static const _activeSessionPrefKey = 'clm_active_session_id';

  /// True if there is an in-progress session for a DIFFERENT doctor.
  bool hasConflictingSession(int doctorId) =>
      _activeSession != null && _activeSession!.doctorId != doctorId;

  /// True if the same doctor is already checked in (session in progress).
  bool isSameDocCheckedIn(int doctorId) =>
      _activeSession != null && _activeSession!.doctorId == doctorId;

  /// Starts a new detailing session.
  /// If a session for a DIFFERENT doctor is still open, it is auto-ended first.
  /// If it is the SAME doctor, this is a no-op (returns the existing session).
  Future<void> startSession(ClmDoctor doctor, {Position? position}) async {
    // Auto-checkout a session for a different doctor
    if (_activeSession != null && _activeSession!.doctorId != doctor.id) {
      await endSession();
    }
    // Same doctor already checked in – don't create a duplicate session
    if (_activeSession != null && _activeSession!.doctorId == doctor.id) {
      return;
    }

    final brandIds = _cart.map((c) => c.brand.id).toList();
    _activeSession = await _analytics.createSession(
      doctor: doctor,
      brandIds: brandIds,
      latitude: position?.latitude.toString(),
      longitude: position?.longitude.toString(),
    );

    // Persist so we can restore after a cold restart
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeSessionPrefKey, _activeSession!.id);

    notifyListeners();
  }

  Future<void> endSession() async {
    if (_activeSession == null) return;
    await _analytics.endSession(_activeSession!.id);
    await _db.updateDoctorSession(_activeSession!.doctorId, DateTime.now());

    // Clear the persisted session key
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeSessionPrefKey);

    // Re-load doctor list so last_detailed_at is fresh
    await loadDoctors();
    await loadDashboardStats();

    _activeSession = null;
    notifyListeners();

    unawaited(_sync.uploadPendingAnalytics());
  }

  /// Recovers any incomplete session left open from a previous app run.
  Future<void> _restoreIncompleteSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_activeSessionPrefKey);
    if (sessionId == null) return;
    try {
      final session = await _db.getSessionById(sessionId);
      if (session != null && session.endTime == null) {
        _activeSession = session;
        notifyListeners();
      } else {
        await prefs.remove(_activeSessionPrefKey);
      }
    } catch (_) {
      await prefs.remove(_activeSessionPrefKey);
    }
  }

  // ─── Dashboard Stats ──────────────────────────────────────────────────────────

  Future<void> loadDashboardStats() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('employee_code') ?? '';
    _todayStats = await _analytics.getTodaySummary(code);
    _recentSessions = await _analytics.getRecentSessions(limit: 15);
    _pendingUploads = await _analytics.getPendingUploadsCount();
    notifyListeners();
  }

  // ─── Sync ─────────────────────────────────────────────────────────────────────

  Future<void> syncNow() async {
    if (!await _sync.isOnline()) {
      _syncStatus = const ClmSyncStatus(
          state: SyncState.error, message: 'No internet connection');
      notifyListeners();
      return;
    }
    await _sync.fullSync();
    await loadDoctors();
    await loadBrands();
    await loadDashboardStats();
    notifyListeners();
  }

  Future<void> clearAndResync() async {
    _syncStatus = const ClmSyncStatus(
        state: SyncState.syncing, message: 'Clearing local data…');
    _allDoctors = [];
    _filteredDoctors = [];
    _allBrands = [];
    notifyListeners();

    await _db.clearAllData();

    _syncStatus = const ClmSyncStatus(
        state: SyncState.syncing, message: 'Syncing from server…');
    notifyListeners();

    await _sync.fullSync();
    await loadDoctors();
    await loadBrands();
    await loadDashboardStats();
    notifyListeners();
  }

  Future<void> downloadBrand(int brandId,
      {ValueChanged<double>? onProgress}) async {
    await _sync.downloadBrandMedia(brandId, onProgress: onProgress);
    await loadBrands(); // Refresh download state
  }

  Future<ClmDoctorStats> getDoctorStats(int doctorId) =>
      _analytics.getDoctorStats(doctorId);

  ClmAnalyticsService get analyticsService => _analytics;

  // ─── Call Reports ─────────────────────────────────────────────────────────────

  Future<void> saveCallReport(ClmCallReport report) async {
    await _db.saveCallReport(report);
    await loadDashboardStats();
  }

  Future<List<ClmCallReport>> getCallReportsForDoctor(int doctorId) =>
      _db.getCallReportsForDoctor(doctorId);

  Future<ClmCallReport?> getLastCallReportForDoctor(int doctorId) async {
    final reports = await _db.getCallReportsForDoctor(doctorId);
    return reports.isNotEmpty ? reports.first : null;
  }

  Future<ClmCallReport?> getCallReportForSession(String sessionId) =>
      _db.getCallReportForSession(sessionId);

  // ─── Visit History ────────────────────────────────────────────────────────────

  Future<List<ClmVisitSummary>> getVisitHistory(int doctorId, {int limit = 10}) =>
      _db.getVisitHistory(doctorId, limit: limit);

  Future<void> updateDoctorNextCallDate(int doctorId, DateTime? date) async {
    await _db.updateDoctorNextCallDate(doctorId, date);
    await loadDoctors();
  }

  // ─── Doctor Locations ─────────────────────────────────────────────────────────

  Future<List<DoctorLocation>> getLocationsForDoctor(int doctorId) =>
      _db.getLocationsForDoctor(doctorId);

  Future<int> getDoctorLocationCount(int doctorId) =>
      _db.getDoctorLocationCount(doctorId);

  /// Saves a new tagged location. Returns false if the doctor already has 3.
  Future<bool> addDoctorLocation(DoctorLocation loc) async {
    final count = await _db.getDoctorLocationCount(loc.doctorId);
    if (count >= 3) return false;
    await _db.insertDoctorLocation(loc);
    return true;
  }

  Future<void> updateDoctorLocationLabel(int id, String label) =>
      _db.updateDoctorLocationLabel(id, label);

  Future<void> deleteDoctorLocation(int id) =>
      _db.deleteDoctorLocation(id);

  // ─── AI Insight ───────────────────────────────────────────────────────────────

  final ClmAiService _ai = ClmAiService();

  Future<AiDoctorInsight> getAiInsightForDoctor(ClmDoctor doctor) async {
    final history = await _db.getVisitHistory(doctor.id, limit: 10);
    final reports = await _db.getCallReportsForDoctor(doctor.id);
    final brands = doctor.assignedBrandIds.isEmpty
        ? _allBrands
        : _allBrands
            .where((b) => doctor.assignedBrandIds.contains(b.id))
            .toList();

    final slidesMap = <int, List<ClmSlide>>{};
    for (final brand in brands) {
      slidesMap[brand.id] = await _db.getSlidesForBrand(brand.id);
    }

    return _ai.analyze(
      doctor: doctor,
      history: history,
      reports: reports,
      brands: brands,
      slidesPerBrand: slidesMap,
    );
  }

  /// Builds the cart from AI-selected brand recommendations.
  void applyAiCart(AiDoctorInsight insight) {
    _cart.clear();
    int seq = 0;
    for (final rec in insight.brandRecs.where((r) => r.isSelected)) {
      if (rec.slides.isNotEmpty) {
        _cart.add(ClmCartItem(
          brand: rec.brand,
          slides: rec.slides,
          cartSequence: seq++,
        ));
      }
    }
    notifyListeners();
  }
}

void unawaited(Future<void> future) {
  future.catchError((_) {});
}
