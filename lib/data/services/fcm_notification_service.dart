import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_messaging/firebase_messaging.dart';
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
    void Function(RemoteMessage message)? onForegroundMessage,
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

  /// Requests browser notification permission.
  /// Returns true if granted, false otherwise.
  Future<bool> _requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final status = settings.authorizationStatus;
      debugPrint('[FCM] Permission status: $status');

      return status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('[FCM] Permission request error: $e');
      return false;
    }
  }

  /// Generates the FCM Web token using the VAPID public key.
  /// Returns null if token generation fails.
  Future<String?> _getToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? _kWebVapidPublicKey : null,
      );

      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Token is null or empty — check VAPID key and browser support.');
        return null;
      }

      debugPrint('[FCM] Token generated: ${token.substring(0, 20)}...');
      return token;
    } catch (e) {
      debugPrint('[FCM] Token generation error: $e');
      return null;
    }
  }

  /// Registers the FCM token with the backend.
  /// Skips registration if the token has not changed since last registration.
  Future<void> _registerTokenWithBackend({
    required String fcmToken,
    required String authToken,
    required String employeeCode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

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
        // Cache the token so we don't re-register on subsequent app starts.
        await prefs.setString(_kFcmTokenCacheKey, fcmToken);
        debugPrint('[FCM] Token registered successfully with backend.');
      } else {
        debugPrint(
            '[FCM] Backend registration failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      // Backend failure must not crash the app.
      debugPrint('[FCM] Backend registration error: $e');
    }
  }

  /// Refreshes the token on the backend when FCM rotates it.
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
        debugPrint(
            '[FCM] Token refresh failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('[FCM] Token refresh error: $e');
    }
  }

  /// Deletes the token from the backend on logout.
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

  /// Listens for FCM token refresh events.
  /// Re-registers the new token with the backend automatically.
  void _listenForTokenRefresh({
    required String authToken,
    required String employeeCode,
  }) {
    FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) async {
        debugPrint('[FCM] Token refreshed by FCM.');
        await _refreshTokenOnBackend(
          newToken: newToken,
          authToken: authToken,
          employeeCode: employeeCode,
        );
      },
      onError: (e) {
        debugPrint('[FCM] Token refresh stream error: $e');
      },
    );
  }

  /// Listens for foreground messages (app tab is open and focused).
  /// Background messages are handled by the Firebase Messaging Service Worker.
  void _listenForForegroundMessages(
    void Function(RemoteMessage message)? onMessage,
  ) {
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        debugPrint(
          '[FCM] Foreground message received. '
          'Title: ${message.notification?.title} '
          'Body: ${message.notification?.body} '
          'Data: ${message.data}',
        );
        // Invoke the caller-supplied callback (typically shows an in-app snackbar/dialog).
        onMessage?.call(message);
      },
      onError: (e) {
        debugPrint('[FCM] Foreground message stream error: $e');
      },
    );
  }
}
