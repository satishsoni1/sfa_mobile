// ============================================================
// POD / SECONDARY SALES — FIREBASE SERVICE
// ------------------------------------------------------------
// Firebase integration is ACTIVE.
// SFA initializes Firebase in main.dart (himalaya-e7d22 project).
// This service does NOT call Firebase.initializeApp() again —
// it is already initialized before PodEntryScreen is rendered.
// Calling initializeApp() twice would throw a DuplicateApp crash.
//
// Firebase Analytics: re-enabled with firebase_analytics ^12.x
// (compatible with firebase_core ^4.x already used by SFA).
//
// FCM background handler: intentionally NOT registered here.
// SFA FcmNotificationService owns the single background handler.
// POD handles foreground notifications only.
// ============================================================
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
// TODO [iOS]: firebase_messaging temporarily disabled until GoogleService-Info.plist is added.
// import 'package:firebase_messaging/firebase_messaging.dart';
// TODO [iOS]: firebase_analytics temporarily disabled until GoogleService-Info.plist is added.
// import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // TODO [iOS]: Types changed from FirebaseMessaging?/FirebaseAnalytics? to dynamic
  // until firebase_messaging/firebase_analytics imports are restored.
  dynamic _messaging;
  dynamic _analytics;
  FlutterLocalNotificationsPlugin? _localNotifications;
  String? _fcmToken;

  // Initialize Firebase services for POD.
  // IMPORTANT: Firebase.initializeApp() is NOT called here.
  // SFA main.dart calls it first. This method safely uses the
  // already-initialized default app via Firebase.apps check.
  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (kDebugMode) {
          print('[FirebaseService] WARNING: Firebase not initialized. Skipping POD Firebase setup.');
        }
        return;
      }

      // TODO [iOS]: Restore these two lines after re-enabling firebase imports:
      // _analytics = FirebaseAnalytics.instance;
      // _messaging = FirebaseMessaging.instance;

      await _initializeLocalNotifications();
      await _requestNotificationPermissions();
      await _getFCMToken();

      // Foreground handler only — background handler belongs to SFA.
      _setupForegroundMessageHandler();

      if (kDebugMode) {
        print('[FirebaseService] POD Firebase services initialized.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[FirebaseService] Error: $e');
      }
    }
  }

  Future<void> _initializeLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    await _localNotifications?.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );
  }

  Future<void> _requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      await _localNotifications
          ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _messaging?.requestPermission(
        alert: true, badge: true, sound: true,
        announcement: false, carPlay: false, criticalAlert: false, provisional: false,
      );
    } else if (Platform.isIOS) {
      await _messaging?.requestPermission(
        alert: true, badge: true, sound: true,
        announcement: false, carPlay: false, criticalAlert: false, provisional: false,
      );
    }
  }

  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _messaging?.getToken();
      if (kDebugMode) print('[FirebaseService] FCM Token: $_fcmToken');
      await _sendTokenToServer(_fcmToken);
    } catch (e) {
      if (kDebugMode) print('[FirebaseService] FCM token error: $e');
    }
  }

  Future<void> _sendTokenToServer(String? token) async {
    if (token != null) {
      // TODO: POST token to Himalaya backend FCM registration endpoint.
    }
  }

  // Foreground handler only — never register onBackgroundMessage here.
  // SFA FcmNotificationService owns the background handler.
  void _setupForegroundMessageHandler() {
    // TODO [iOS]: Restore after re-enabling firebase_messaging import:
    // FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    // FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    // _messaging?.getInitialMessage().then((msg) {
    //   if (msg != null) _handleNotificationTap(msg);
    // });
  }

  // TODO [iOS]: Parameter was RemoteMessage — changed to dynamic until Firebase re-enabled.
  void _handleForegroundMessage(dynamic message) {
    if (kDebugMode) print('[FirebaseService] Foreground: ${message.messageId}');
    _showLocalNotification(message);
  }

  // TODO [iOS]: Parameter was RemoteMessage — changed to dynamic until Firebase re-enabled.
  void _handleNotificationTap(dynamic message) {
    if (kDebugMode) print('[FirebaseService] Tapped: ${message.messageId}');
    _navigateFromNotification(message);
  }

  // TODO [iOS]: Parameter was RemoteMessage — changed to dynamic until Firebase re-enabled.
  void _showLocalNotification(dynamic message) async {
    if (message.notification == null) return;
    await _localNotifications?.show(
      message.hashCode,
      message.notification?.title ?? 'Secondary Sales',
      message.notification?.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'secondary_sales_channel',
          'Secondary Sales Notifications',
          channelDescription: 'Notifications for the Secondary Sales (POD) feature',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true, sound: 'default',
        ),
      ),
      payload: message.data.toString(),
    );
  }

  // TODO [iOS]: Parameter was RemoteMessage — changed to dynamic until Firebase re-enabled.
  void _navigateFromNotification(dynamic message) {
    final screen = message.data['screen'];
    if (screen != null && kDebugMode) print('[FirebaseService] Navigate to: $screen');
  }

  Future<bool> requestNotificationPermissions() async {
    try {
      if (Platform.isAndroid) {
        final granted = await _localNotifications
            ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        // TODO [iOS]: Restore after re-enabling firebase_messaging:
        // final settings = await _messaging?.requestPermission(...);
        // return (granted == true) && (settings?.authorizationStatus == AuthorizationStatus.authorized);
        return granted == true;
      } else if (Platform.isIOS) {
        // TODO [iOS]: Restore after re-enabling firebase_messaging:
        // final settings = await _messaging?.requestPermission(...);
        // return settings?.authorizationStatus == AuthorizationStatus.authorized;
        return false;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('[FirebaseService] Permission error: $e');
      return false;
    }
  }

  Future<void> checkForUpdates() async {
    if (kDebugMode) print('[FirebaseService] Update checking not implemented.');
  }

  String? get fcmToken => _fcmToken;
  // TODO [iOS]: Return type was FirebaseAnalytics? — changed to dynamic until re-enabled.
  dynamic get analytics => _analytics;

  Future<void> logEvent(String name, Map<String, Object> parameters) async {
    await _analytics?.logEvent(name: name, parameters: parameters);
  }

  Future<void> setUserProperty(String name, String value) async {
    await _analytics?.setUserProperty(name: name, value: value);
  }
}