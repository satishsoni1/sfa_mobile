// ============================================================
// POD / SECONDARY SALES — FIREBASE SERVICE
// ------------------------------------------------------------
// Firebase integration is ACTIVE.
// SFA initializes Firebase in main.dart (himalaya-e7d22 project).
// This service does NOT call Firebase.initializeApp() again —
// it is already initialized before PodEntryScreen is rendered.
//
// FCM foreground / background / tap routing is owned exclusively by
// SFA [FcmNotificationService]. This class keeps Analytics helpers
// and optional local-notification channel setup for POD screens.
// ============================================================
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseAnalytics? _analytics;

  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (kDebugMode) {
          print(
            '[FirebaseService] WARNING: Firebase not initialized. '
            'Skipping POD Firebase setup.',
          );
        }
        return;
      }

      _analytics = FirebaseAnalytics.instance;

      if (kDebugMode) {
        print('[FirebaseService] POD Analytics initialized.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[FirebaseService] Error: $e');
      }
    }
  }

  FirebaseAnalytics? get analytics => _analytics;

  /// Kept for legacy POD notification-settings UI; FCM permission is owned by SFA.
  Future<bool> requestNotificationPermissions() async {
    debugPrint(
      '[FirebaseService] requestNotificationPermissions deferred to '
      'FcmNotificationService',
    );
    return true;
  }

  Future<void> checkForUpdates() async {
    if (kDebugMode) {
      print('[FirebaseService] Update checking not implemented.');
    }
  }

  /// Legacy accessor — token registration is owned by SFA FcmNotificationService.
  String? get fcmToken => null;

  Future<void> logEvent(String name, Map<String, Object> parameters) async {
    await _analytics?.logEvent(name: name, parameters: parameters);
  }

  Future<void> setUserProperty(String name, String value) async {
    await _analytics?.setUserProperty(name: name, value: value);
  }
}
