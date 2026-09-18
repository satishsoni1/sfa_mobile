// TODO [iOS]: firebase_messaging import temporarily disabled.
// Re-enable after adding GoogleService-Info.plist and iOS Firebase config.
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../data/services/api_service.dart';
// TODO [iOS]: FCM notification service temporarily disabled.
// import '../data/services/fcm_notification_service.dart';
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
  // TODO [iOS]: Type was RemoteMessage — changed to dynamic until Firebase re-enabled.
  void Function(dynamic message)? onForegroundMessage;

  // 1. CHECK LOGIN STATUS (Run on App Start)
  Future<void> checkLoginStatus() async {
    final token = await _apiService.getToken();
    final user = await _apiService.getUser();

    if (token != null && user != null) {
      _currentUser = user;
      _isAuthenticated = true;

      // TODO [iOS]: FCM init temporarily disabled. Re-enable after iOS Firebase config is added.
      // await _initFcm(authToken: token, user: user);
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

      // TODO [iOS]: FCM init temporarily disabled. Re-enable after iOS Firebase config is added.
      // await _initFcm(authToken: token, user: user);

      if (user.isFirstLogin) {
        return 'FIRST_LOGIN';
      }
      return 'SUCCESS';
    } catch (e) {
      debugPrint('Login Error: $e');
      String msg = e.toString();
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring(11);
      }
      return msg;
    }
  }

  // 3. LOGOUT ACTION
  Future<void> logout() async {
    // TODO [iOS]: FCM token cleanup disabled. Re-enable after iOS Firebase config is added.
    // final authToken = await _apiService.getToken();
    // if (authToken != null) {
    //   await FcmNotificationService.instance.onLogout(authToken: authToken);
    // }

    await _apiService.clearSession();
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  // TODO [iOS]: _initFcm temporarily disabled. Restore after adding GoogleService-Info.plist.
  // Future<void> _initFcm({
  //   required String authToken,
  //   required User user,
  // }) async {
  //   await FcmNotificationService.instance.initializeAfterLogin(
  //     authToken: authToken,
  //     employeeCode: user.employeeCode,
  //     onForegroundMessage: (message) {
  //       onForegroundMessage?.call(message);
  //     },
  //   );
  // }
}

