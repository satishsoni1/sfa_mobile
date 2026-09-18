import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
// TODO [iOS]: firebase_messaging temporarily disabled until GoogleService-Info.plist is added.
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zforce/data/services/api_service.dart';

/// FCM Web VAPID public key.
const String _kWebVapidPublicKey =
    'BATCNOHZ0IgIaAfooNWtGqj9GJD_rlnbJEEyudGuYWzkrW6sljaQ0YfIMYxi2ijIH7Gj0JdcwdxriXeNEzaG0xc';

/// SharedPreferences key for cached FCM token
const String _kFcmTokenCacheKey = 'fcm_token_cached';

/// FCM Notification Service
///
/// Responsibilities:
///   - Initialize Firebase Messaging 
///   - Request browser notification permission.
///   - Generate and cache the FCM Web token (using VAPID key).
///   - Register the token with the backend via POST /device/fcm-token.
///   - Listen for token refresh and update the backend via PUT /device/fcm-token/refresh.
///   - Listen for foreground messages and invoke the provided [onForegroundMessage] callback.
///   - Delete the token from the backend on logout via DELETE /device/fcm-token/delete.
///
/// Usage:
///   After login, call:
///     await FcmNotificationService.instance.initializeAfterLogin(
///       authToken: bearerToken,
///       employeeCode: user.employeeCode,
///       onForegroundMessage: (message) { /* show in-app UI */ },
///     );
///
///   On logout, call:
///     await FcmNotificationService.instance.onLogout(authToken: bearerToken);
class FcmNotificationService {
  FcmNotificationService._internal();
  static final FcmNotificationService instance = FcmNotificationService._internal();

  bool _initialized = false;

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  /// Call this once after a successful login (or on startup if already logged in).
  ///
  /// [authToken]       — Bearer token from SharedPreferences / session.
  /// [employeeCode]    — Logged-in user's employee code for backend association.
  /// [onForegroundMessage] — Callback invoked when a message arrives while the
  ///                         app tab is in the foreground.
  Future<void> initializeAfterLogin({
    required String authToken,
    required String employeeCode,
    // TODO [iOS]: was void Function(RemoteMessage message)? — changed to dynamic
    void Function(dynamic message)? onForegroundMessage,
  }) async {
    

    if (_initialized) {
      debugPrint('[FCM] Already initialized. Skipping re-init.');
      return;
    }

    try {
      debugPrint('[FCM] Starting initialization sequence...');
      // 1. Request browser notification permission.
      debugPrint('[FCM] Requesting browser permission...');
      final granted = await _requestPermission();
      if (!granted) {
        debugPrint('[FCM] Notification permission denied. FCM disabled.');
        return;
      }
      debugPrint('[FCM] Permission granted!');

      // 2. Generate the Web FCM token using the VAPID public key.
      debugPrint('[FCM] Fetching token from Firebase...');
      final token = await _getToken();
      if (token == null) return;
      debugPrint('[FCM] Token fetched successfully.');

      // 3. Register the token with the backend (skips if token unchanged).
      await _registerTokenWithBackend(
        fcmToken: token,
        authToken: authToken,
        employeeCode: employeeCode,
      );

      // 4. Listen for token refresh events (token can be rotated by FCM).
      _listenForTokenRefresh(authToken: authToken, employeeCode: employeeCode);

      // 5. Listen for foreground messages (tab is open and focused).
      _listenForForegroundMessages(onForegroundMessage);

      _initialized = true;
      debugPrint('[FCM] Initialization complete.');
    } catch (e) {
      // Never crash the app due to notification failures.
      debugPrint('[FCM] Initialization error: $e');
    }
  }

  /// Call this during logout to disassociate the token from the current user.
  Future<void> onLogout({required String authToken}) async {
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedToken = prefs.getString(_kFcmTokenCacheKey);
      if (cachedToken == null || cachedToken.isEmpty) return;

      await _deleteTokenFromBackend(
        fcmToken: cachedToken,
        authToken: authToken,
      );
      await prefs.remove(_kFcmTokenCacheKey);
      _initialized = false;
      debugPrint('[FCM] Token removed on logout.');
    } catch (e) {
      debugPrint('[FCM] Logout token removal error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE IMPLEMENTATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Requests browser/device notification permission.
  Future<bool> _requestPermission() async {
    try {
      // TODO [iOS]: Restore after re-enabling firebase_messaging import:
      // final settings = await FirebaseMessaging.instance.requestPermission(
      //   alert: true, badge: true, sound: true,
      // );
      // final status = settings.authorizationStatus;
      // return status == AuthorizationStatus.authorized || status == AuthorizationStatus.provisional;
      debugPrint('[FCM] _requestPermission: Firebase disabled — returning false on native.');
      return false;
    } catch (e) {
      debugPrint('[FCM] Permission request error: $e');
      return false;
    }
  }

  /// Generates the FCM token.
  Future<String?> _getToken() async {
    try {
      // TODO [iOS]: Restore after re-enabling firebase_messaging import:
      // final token = await FirebaseMessaging.instance.getToken(
      //   vapidKey: kIsWeb ? _kWebVapidPublicKey : null,
      // );
      // return token;
      debugPrint('[FCM] _getToken: Firebase disabled — returning null on native.');
      return null;
    } catch (e) {
      debugPrint('[FCM] Token generation error: $e');
      return null;
    }
  }

  Future<void> _registerTokenWithBackend({
    required String fcmToken,
    required String authToken,
    required String employeeCode,
  }) async {
    try {
      debugPrint('[FCM] Registering token with server');
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/device/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'fcm_token': fcmToken,
          'platform': 'web',
          'employee_code': employeeCode,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kFcmTokenCacheKey, fcmToken);
        debugPrint('[FCM] Token registered successfully with backend.');
      } else {
        debugPrint('[FCM] Backend registration failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('[FCM] Backend registration error: $e');
    }
  }

  Future<void> _refreshTokenOnBackend({
    required String newToken,
    required String authToken,
    required String employeeCode,
  }) async {
    try {
      debugPrint('[FCM] Refreshing rotated token on server');
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/device/fcm-token/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'fcm_token': newToken,
          'platform': 'web',
          'employee_code': employeeCode,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kFcmTokenCacheKey, newToken);
        debugPrint('[FCM] Token refreshed successfully on backend.');
      } else {
        debugPrint('[FCM] Token refresh failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('[FCM] Token refresh error: $e');
    }
  }

  Future<void> _deleteTokenFromBackend({
    required String fcmToken,
    required String authToken,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/device/fcm-token/delete'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcm_token': fcmToken, 'platform': 'web'}),
      );
      debugPrint('[FCM] Token deletion response: ${response.statusCode}');
    } catch (e) {
      debugPrint('[FCM] Token deletion error: $e');
    }
  }

  void _listenForTokenRefresh({
    required String authToken,
    required String employeeCode,
  }) {
    // TODO [iOS]: Restore after re-enabling firebase_messaging import:
    // FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    //   await _refreshTokenOnBackend(newToken: newToken, authToken: authToken, employeeCode: employeeCode);
    // });
    debugPrint('[FCM] _listenForTokenRefresh: Firebase disabled — skipping on native.');
  }

  /// Listens for foreground messages.
  void _listenForForegroundMessages(
    // TODO [iOS]: was void Function(RemoteMessage)? — changed to dynamic
    void Function(dynamic message)? onMessage,
  ) {
    // TODO [iOS]: Restore after re-enabling firebase_messaging import:
    // FirebaseMessaging.onMessage.listen((dynamic message) {
    //   debugPrint('[FCM] Foreground message received: ${message.notification?.title}');
    //   onMessage?.call(message);
    // });
    debugPrint('[FCM] _listenForForegroundMessages: Firebase disabled — skipping on native.');
  }

}
