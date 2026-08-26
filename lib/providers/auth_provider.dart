import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../data/services/api_service.dart';
import '../data/services/fcm_notification_service.dart';
import '../data/models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isAuthenticated = false;
  bool _isLoading = true;
  User? _currentUser;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  User? get user => _currentUser;

  // Callback for showing in-app foreground notification UI (set by DashboardScreen).
  void Function(RemoteMessage)? onForegroundMessage;

  // 1. CHECK LOGIN STATUS (Run on App Start)
  Future<void> checkLoginStatus() async {
    final token = await _apiService.getToken();
    final user = await _apiService.getUser();

    if (token != null && user != null) {
      _currentUser = user;
      _isAuthenticated = true;

      // Re-initialize FCM for already-logged-in users on page refresh.
      if (kIsWeb) {
        await _initFcm(authToken: token, user: user);
      }
    } else {
      _isAuthenticated = false;
    }
    _isLoading = false;
    notifyListeners();
  }

  // 2. LOGIN ACTION
  Future<String> login(String empId, String password) async {
    try {
      final result = await _apiService.login(empId, password);

      final token = result['token'] as String;
      final user = User.fromJson(result['user'] as Map<String, dynamic>);

      await _apiService.saveSession(token, user);

      _currentUser = user;
      _isAuthenticated = true;
      notifyListeners();

      // Initialize FCM after a successful login on Web.
      if (kIsWeb) {
        await _initFcm(authToken: token, user: user);
      }

      if (user.isFirstLogin) {
        return 'FIRST_LOGIN';
      }
      return 'SUCCESS';
    } catch (e) {
      print('Login Error: $e');
      String msg = e.toString();
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring(11);
      }
      return msg;
    }
  }

  // 3. LOGOUT ACTION
  Future<void> logout() async {
    // Disassociate FCM token from this user before clearing session.
    if (kIsWeb) {
      final authToken = await _apiService.getToken();
      if (authToken != null) {
        await FcmNotificationService.instance.onLogout(authToken: authToken);
      }
    }

    await _apiService.clearSession();
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  /// Initializes the FCM service for a logged-in user.
  /// Safe to call multiple times — the service guards against re-initialization.
  Future<void> _initFcm({
    required String authToken,
    required User user,
  }) async {
    await FcmNotificationService.instance.initializeAfterLogin(
      authToken: authToken,
      employeeCode: user.employeeCode,
      onForegroundMessage: (message) {
        // Invoke the callback registered by the UI layer (DashboardScreen).
        onForegroundMessage?.call(message);
      },
    );
  }
}
