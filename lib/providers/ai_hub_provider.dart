import 'package:flutter/foundation.dart';

import '../data/models/ai_hub_models.dart';
import '../data/services/ai_hub_service.dart';

enum AiHubLoadState { idle, loading, loaded, error }

class AiHubProvider extends ChangeNotifier {
  final AiHubService _service = AiHubService();

  // ── Hub header metrics ─────────────────────────────────────────────────────
  Map<String, AiHubMetric> _metrics     = {};
  List<AiHubInsight>       _insights    = [];

  // ── Module data ────────────────────────────────────────────────────────────
  AiSalesAssistantData? _salesData;
  AiProductData?        _productData;
  AiDoctorReviewData?   _doctorData;
  AiEmployeeData?       _employeeData;

  // ── State ──────────────────────────────────────────────────────────────────
  AiHubLoadState _hubState      = AiHubLoadState.idle;
  AiHubLoadState _salesState    = AiHubLoadState.idle;
  AiHubLoadState _productState  = AiHubLoadState.idle;
  AiHubLoadState _doctorState   = AiHubLoadState.idle;
  AiHubLoadState _employeeState = AiHubLoadState.idle;

  String _errorMessage = '';

  // ── Public getters ─────────────────────────────────────────────────────────
  Map<String, AiHubMetric> get metrics      => _metrics;
  List<AiHubInsight>        get insights    => _insights;
  AiSalesAssistantData?     get salesData   => _salesData;
  AiProductData?            get productData => _productData;
  AiDoctorReviewData?       get doctorData  => _doctorData;
  AiEmployeeData?           get employeeData=> _employeeData;

  AiHubLoadState get hubState      => _hubState;
  AiHubLoadState get salesState    => _salesState;
  AiHubLoadState get productState  => _productState;
  AiHubLoadState get doctorState   => _doctorState;
  AiHubLoadState get employeeState => _employeeState;

  bool get isHubLoading => _hubState == AiHubLoadState.loading;
  String get errorMessage => _errorMessage;

  // ── Convenience metric helpers ─────────────────────────────────────────────
  String metricValue(String key, {String fallback = '—'}) =>
      _metrics[key]?.displayValue ?? fallback;

  AiHubMetric? metric(String key) => _metrics[key];

  // ── Init (hub home) ────────────────────────────────────────────────────────
  Future<void> init({bool forceRefresh = false}) async {
    if (_hubState == AiHubLoadState.loading) return;
    _hubState = AiHubLoadState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.fetchMetrics(forceRefresh: forceRefresh),
        _service.fetchInsights(forceRefresh: forceRefresh),
      ]);
      _metrics  = results[0] as Map<String, AiHubMetric>;
      _insights = results[1] as List<AiHubInsight>;
      _hubState = AiHubLoadState.loaded;
    } catch (e) {
      _hubState     = AiHubLoadState.error;
      _errorMessage = e.toString();
      debugPrint('[AiHubProvider] init error: $e');
    }
    notifyListeners();
  }

  Future<void> refresh() => init(forceRefresh: true);

  // ── Sales Assistant ────────────────────────────────────────────────────────
  Future<void> loadSalesAssistant({bool forceRefresh = false}) async {
    if (_salesState == AiHubLoadState.loading) return;
    _salesState = AiHubLoadState.loading;
    notifyListeners();

    try {
      _salesData  = await _service.fetchSalesAssistant(forceRefresh: forceRefresh);
      _salesState = AiHubLoadState.loaded;
    } catch (e) {
      _salesState = AiHubLoadState.error;
      debugPrint('[AiHubProvider] sales error: $e');
    }
    notifyListeners();
  }

  // ── Product Performance ────────────────────────────────────────────────────
  Future<void> loadProductPerformance({bool forceRefresh = false}) async {
    if (_productState == AiHubLoadState.loading) return;
    _productState = AiHubLoadState.loading;
    notifyListeners();

    try {
      _productData  = await _service.fetchProductPerformance(forceRefresh: forceRefresh);
      _productState = AiHubLoadState.loaded;
    } catch (e) {
      _productState = AiHubLoadState.error;
      debugPrint('[AiHubProvider] product error: $e');
    }
    notifyListeners();
  }

  // ── Doctor Review ──────────────────────────────────────────────────────────
  Future<void> loadDoctorReview({bool forceRefresh = false}) async {
    if (_doctorState == AiHubLoadState.loading) return;
    _doctorState = AiHubLoadState.loading;
    notifyListeners();

    try {
      _doctorData  = await _service.fetchDoctorReview(forceRefresh: forceRefresh);
      _doctorState = AiHubLoadState.loaded;
    } catch (e) {
      _doctorState = AiHubLoadState.error;
      debugPrint('[AiHubProvider] doctor review error: $e');
    }
    notifyListeners();
  }

  // ── Employee Performance ───────────────────────────────────────────────────
  Future<void> loadEmployeePerformance({bool forceRefresh = false}) async {
    if (_employeeState == AiHubLoadState.loading) return;
    _employeeState = AiHubLoadState.loading;
    notifyListeners();

    try {
      _employeeData  = await _service.fetchEmployeePerformance(forceRefresh: forceRefresh);
      _employeeState = AiHubLoadState.loaded;
    } catch (e) {
      _employeeState = AiHubLoadState.error;
      debugPrint('[AiHubProvider] employee error: $e');
    }
    notifyListeners();
  }
}
