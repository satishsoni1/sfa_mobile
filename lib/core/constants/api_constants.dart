class ApiConstants {
  // ── MAIN SFA API (production) ─────────────────────────────────────────────
  static const String baseUrl = 'https://zorvia.globalspace.in/api';

  // ── CLM / VODOCLM LOCAL API ───────────────────────────────────────────────
  // Switch between environments by commenting/uncommenting one line:

  // Local machine (Flutter web / desktop / unit tests)
  static const String clmBaseUrl = 'http://192.168.1.13:8000/api';

  // Android Emulator → maps to host machine's localhost
  // static const String clmBaseUrl = 'http://10.0.2.2:8000/api'; 

  // Real device on same Wi-Fi → use your PC's LAN IP
  // static const String clmBaseUrl = 'http://192.168.1.X:8000/api';

  // Production
  // static const String clmBaseUrl = 'https://zorvia.globalspace.in/api';

  // ── TIMEOUTS ──────────────────────────────────────────────────────────────
  static const int connectionTimeout = 15000; // ms
  static const int receiveTimeout    = 15000; // ms

  // ── MAIN SFA ENDPOINTS ────────────────────────────────────────────────────
  static const String login      = '$baseUrl/login';
  static const String doctors    = '$baseUrl/doctors';
  static const String visits     = '$baseUrl/visits';
  static const String attendance = '$baseUrl/attendance';

  // ── CLM ENDPOINTS ─────────────────────────────────────────────────────────
  static const String clmLogin        = '$clmBaseUrl/auth/login';
  static const String clmLogout       = '$clmBaseUrl/auth/logout';
  static const String clmDoctors      = '$clmBaseUrl/clm/doctors';
  static const String clmBrands       = '$clmBaseUrl/clm/brands';
  static const String clmSyncSessions = '$clmBaseUrl/clm/sync/sessions';
  static const String clmSyncAnalytics= '$clmBaseUrl/clm/sync/analytics';
  static const String clmSyncReports  = '$clmBaseUrl/clm/sync/call-reports';

  // ── DCR ENDPOINTS ─────────────────────────────────────────────────────────
  static const String dcrProducts          = '$clmBaseUrl/dcr/products';
  static const String dcrChemists          = '$clmBaseUrl/dcr/chemists';
  static const String dcrSyncDoctorVisits  = '$clmBaseUrl/dcr/sync/doctor-visits';
  static const String dcrSyncChemistVisits = '$clmBaseUrl/dcr/sync/chemist-visits';
  static const String dcrSyncRcpa          = '$clmBaseUrl/dcr/sync/rcpa';

  // ── DATA BANK ENDPOINTS ───────────────────────────────────────────────────
  static const String dataBankCategories  = '$clmBaseUrl/data-bank/categories';
  static const String dataBankMaterials   = '$clmBaseUrl/data-bank/materials';
  static const String dataBankUserStats   = '$clmBaseUrl/data-bank/user-stats';
  static const String dataBankSyncLogs    = '$clmBaseUrl/data-bank/sync/view-logs';

  // ── AI HUB ENDPOINTS ──────────────────────────────────────────────────────
  static const String aiHubMetrics             = '$clmBaseUrl/ai-hub/metrics';
  static const String aiHubInsights            = '$clmBaseUrl/ai-hub/insights';
  static const String aiHubSalesAssistant      = '$clmBaseUrl/ai-hub/sales-assistant';
  static const String aiHubProductPerformance  = '$clmBaseUrl/ai-hub/product-performance';
  static const String aiHubDoctorReview        = '$clmBaseUrl/ai-hub/doctor-review';
  static const String aiHubEmployeePerformance = '$clmBaseUrl/ai-hub/employee-performance';
}