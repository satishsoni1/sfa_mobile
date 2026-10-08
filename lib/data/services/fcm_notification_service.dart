import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zforce/core/navigation/app_navigator.dart';
import 'package:zforce/data/services/api_service.dart';
import 'package:zforce/features/pod/models/secondary_sales_validation_failure.dart';
import 'package:zforce/features/pod/pod_entry_screen.dart';
import 'package:zforce/features/pod/services/batch_service.dart';
import 'package:zforce/features/pod/services/secondary_sales_data_refresh.dart';
import 'package:zforce/features/pod/widgets/secondary_sales_stock_validation_failed_dialog.dart';
import 'package:zforce/firebase_options.dart';

/// FCM Web VAPID public key.
const String _kWebVapidPublicKey =
    'BATCNOHZ0IgIaAfooNWtGqj9GJD_rlnbJEEyudGuYWzkrW6sljaQ0YfIMYxi2ijIH7Gj0JdcwdxriXeNEzaG0xc';

const String _kFcmTokenCacheKey = 'fcm_token_cached';

const String kFcmActionProcessingCompleted = 'processing_completed';
const String kFcmActionStockValidationFailed = 'stock_validation_failed';

const String kSecondarySalesFcmChannelId = 'secondary_sales_fcm';
const String kSecondarySalesFcmChannelName = 'Secondary Sales Notifications';

/// Headless local-notification display for data-only FCM in background/terminated.
Future<void> _showBackgroundLocalNotification({
  required RemoteMessage message,
  required String action,
}) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(
    const InitializationSettings(android: androidInit),
  );

  final androidPlugin = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      kSecondarySalesFcmChannelId,
      kSecondarySalesFcmChannelName,
      description: 'Secondary Sales processing and validation alerts',
      importance: Importance.high,
    ),
  );

  late final String title;
  late final String body;
  if (action == kFcmActionProcessingCompleted) {
    title = 'File Processing Completed';
    body = 'Your stock statement has been processed successfully.';
  } else {
    title = 'Stock Statement Validation Failed';
    body =
        'Closing Stock is greater than Opening Stock + Purchases. Please reprocess or upload the correct stock statement.';
  }

  // Preserve full data map (batch_id, stocks, etc.) for tap routing.
  final payloadMap = Map<String, dynamic>.from(message.data);
  payloadMap['action'] = action;
  final payload = jsonEncode(payloadMap);

  await plugin.show(
    message.hashCode,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        kSecondarySalesFcmChannelId,
        kSecondarySalesFcmChannelName,
        channelDescription:
            'Secondary Sales processing and validation alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: payload,
  );
  debugPrint('[FCM-BG] Local notification shown');
}

/// Top-level background handler required by Firebase Messaging.
/// Must not perform Flutter UI / navigation.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM-BG] Background message received');
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('[FCM-BG] Background Firebase init error: $e');
  }

  final action = (message.data['action'] ??
          message.data['type'] ??
          message.data['notification_action'] ??
          '')
      .toString()
      .trim()
      .toLowerCase();
  debugPrint('[FCM-BG] Action: $action');

  // If FCM already includes a notification payload, Android displays it —
  // do not create a duplicate local notification.
  if (message.notification != null) {
    debugPrint(
      '[FCM-BG] notification payload present — skip local duplicate',
    );
    return;
  }

  if (action != kFcmActionProcessingCompleted &&
      action != kFcmActionStockValidationFailed) {
    debugPrint('[FCM-BG] Unknown/unhandled action — no local notification');
    return;
  }

  try {
    await _showBackgroundLocalNotification(message: message, action: action);
  } catch (e) {
    debugPrint('[FCM-BG] Local notification error: $e');
  }
}

/// Bridge so an already-open Secondary Sales module can react to push actions.
class SecondarySalesPushBridge {
  SecondarySalesPushBridge._();
  static final SecondarySalesPushBridge instance = SecondarySalesPushBridge._();

  void Function(int tabIndex, Map<String, dynamic>? validationData)? onPush;

  bool get isOpen => onPush != null;

  void register(
    void Function(int tabIndex, Map<String, dynamic>? validationData) handler,
  ) {
    onPush = handler;
  }

  void unregister(
    void Function(int tabIndex, Map<String, dynamic>? validationData) handler,
  ) {
    if (onPush == handler) onPush = null;
  }

  void dispatch({
    required int tabIndex,
    Map<String, dynamic>? validationData,
  }) {
    onPush?.call(tabIndex, validationData);
  }
}

/// Central FCM service (login registration, refresh, routing, Secondary Sales).
///
/// Uses the already-working Laravel endpoint:
/// `POST /api/device/fcm-token`
class FcmNotificationService {
  FcmNotificationService._internal();
  static final FcmNotificationService instance =
      FcmNotificationService._internal();

  bool _initialized = false;
  bool _tapHandlersAttached = false;
  bool _localNotificationsReady = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Message that launched a terminated app; consumed after UI is ready.
  RemoteMessage? pendingInitialMessage;

  /// Fallback when navigator is not ready for validation dialog.
  Map<String, dynamic>? _pendingValidationData;

  /// Local-notification tap while app was terminated (data-only FCM path).
  Map<String, dynamic>? _pendingLocalNotificationData;

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

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
      await _ensureLocalNotifications();

      final granted = await _requestPermission();
      if (!granted) {
        debugPrint('[FCM] Notification permission denied. FCM disabled.');
        return;
      }

      final token = await _getToken();
      if (token != null) {
        await _registerTokenWithBackend(
          fcmToken: token,
          authToken: authToken,
          employeeCode: employeeCode,
        );
      }

      _listenForTokenRefresh(
        authToken: authToken,
        employeeCode: employeeCode,
      );
      _listenForForegroundMessages(onForegroundMessage);
      _attachTapHandlers();

      _initialized = true;
      debugPrint('[FCM] Initialization complete.');
    } catch (e) {
      // Never crash login / app due to notification failures.
      debugPrint('[FCM] Initialization error: $e');
    }
  }

  /// Call once after [MaterialApp] is ready (authenticated).
  Future<void> consumePendingInitialMessage() async {
    final message = pendingInitialMessage;
    pendingInitialMessage = null;
    if (message != null) {
      await handleNotification(message, fromTap: true);
      return;
    }

    final localData = _pendingLocalNotificationData;
    _pendingLocalNotificationData = null;
    if (localData != null) {
      await _routeFromLocalPayloadData(localData);
      return;
    }

    final validation = _pendingValidationData;
    _pendingValidationData = null;
    if (validation != null) {
      await _openSecondarySalesDashboard(
        refresh: true,
        validationData: validation,
      );
    }
  }

  /// Capture terminated-app notification before UI routing.
  Future<void> captureInitialMessage() async {
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        pendingInitialMessage = initial;
        debugPrint(
          '[FCM] Captured initial message action=${initial.data['action']}',
        );
      }
    } catch (e) {
      debugPrint('[FCM] getInitialMessage error: $e');
    }

    // Data-only FCM → background local notification → terminated tap.
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final launch = await plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        final payload = launch!.notificationResponse?.payload;
        final parsed = _parseLocalNotificationPayload(payload);
        if (parsed != null) {
          _pendingLocalNotificationData = parsed;
          debugPrint(
            '[FCM] Captured local-notification launch '
            'action=${parsed['action']}',
          );
        }
      }
    } catch (e) {
      debugPrint('[FCM] local notification launch details error: $e');
    }
  }

  Future<void> onLogout({required String authToken}) async {
    try {
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      await _foregroundSub?.cancel();
      _foregroundSub = null;
      await _openedSub?.cancel();
      _openedSub = null;
      _tapHandlersAttached = false;

      final prefs = await SharedPreferences.getInstance();
      final cachedToken = prefs.getString(_kFcmTokenCacheKey);
      if (cachedToken != null && cachedToken.isNotEmpty) {
        await _deleteTokenFromBackend(
          fcmToken: cachedToken,
          authToken: authToken,
        );
        await prefs.remove(_kFcmTokenCacheKey);
      }
      _initialized = false;
      debugPrint('[FCM] Token removed on logout.');
    } catch (e) {
      debugPrint('[FCM] Logout token removal error: $e');
    }
  }

  /// Central router for Secondary Sales (and unknown) FCM actions.
  Future<void> handleNotification(
    RemoteMessage message, {
    required bool fromTap,
    bool isForeground = false,
  }) async {
    final action = _actionOf(message);
    debugPrint(
      '[FCM] handleNotification action=$action fromTap=$fromTap '
      'foreground=$isForeground data=${message.data}',
    );

    switch (action) {
      case kFcmActionProcessingCompleted:
        if (isForeground && !fromTap) {
          await _showProcessingCompletedLocalNotification(message);
          return;
        }
        await _openSecondarySalesDashboard(refresh: true);
        return;

      case kFcmActionStockValidationFailed:
        if (isForeground && !fromTap) {
          await _showValidationFailedDialog(message);
          return;
        }
        await _openSecondarySalesDashboard(
          refresh: true,
          validationData: Map<String, dynamic>.from(message.data),
        );
        return;

      default:
        debugPrint('[FCM] Unknown action "$action" — ignoring navigation.');
        return;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE
  // ─────────────────────────────────────────────────────────────────────────

  String _actionOf(RemoteMessage message) {
    final raw = message.data['action'] ??
        message.data['type'] ??
        message.data['notification_action'];
    return raw?.toString().trim().toLowerCase() ?? '';
  }

  String get _deviceType {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return 'android';
  }

  String get _deviceName {
    if (kIsWeb) return 'Web Browser';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'iOS Device';
    if (defaultTargetPlatform == TargetPlatform.android) return 'Android Device';
    return 'Mobile Device';
  }

  Future<void> _ensureLocalNotifications() async {
    if (_localNotificationsReady || kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        unawaited(_handleLocalNotificationTap(response.payload));
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        kSecondarySalesFcmChannelId,
        kSecondarySalesFcmChannelName,
        description: 'Secondary Sales processing and validation alerts',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();
    _localNotificationsReady = true;
  }

  Map<String, dynamic>? _parseLocalNotificationPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    final trimmed = payload.trim();
    // Legacy plain-string payload.
    if (trimmed == kFcmActionProcessingCompleted) {
      return {'action': kFcmActionProcessingCompleted};
    }
    if (trimmed == kFcmActionStockValidationFailed) {
      return {'action': kFcmActionStockValidationFailed};
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _handleLocalNotificationTap(String? payload) async {
    final data = _parseLocalNotificationPayload(payload);
    if (data == null) return;
    await _routeFromLocalPayloadData(data);
  }

  Future<void> _routeFromLocalPayloadData(Map<String, dynamic> data) async {
    final action = (data['action'] ?? data['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (action == kFcmActionProcessingCompleted) {
      await _openSecondarySalesDashboard(refresh: true);
      return;
    }
    if (action == kFcmActionStockValidationFailed) {
      await _openSecondarySalesDashboard(
        refresh: true,
        validationData: data,
      );
    }
  }

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

  Future<String?> _getToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? _kWebVapidPublicKey : null,
      );
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Token is null or empty.');
        return null;
      }
      debugPrint('[FCM] Token generated (full): $token');
      // ignore: avoid_print
      print('[FCM] TOKEN=$token');
      return token;
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
      final prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/device/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          // Existing working Laravel contract.
          'fcm_token': fcmToken,
          'platform': _deviceType,
          'employee_code': employeeCode,
          // Compatible aliases used by some Laravel builds.
          'token': fcmToken,
          'device_type': _deviceType,
          'device_name': _deviceName,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await prefs.setString(_kFcmTokenCacheKey, fcmToken);
        debugPrint('[FCM] Token registered successfully with backend.');
      } else {
        debugPrint(
          '[FCM] Backend registration failed: '
          '${response.statusCode} ${response.body}',
        );
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
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/device/fcm-token/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'fcm_token': newToken,
          'platform': _deviceType,
          'employee_code': employeeCode,
          'token': newToken,
          'device_type': _deviceType,
          'device_name': _deviceName,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kFcmTokenCacheKey, newToken);
        debugPrint('[FCM] Token refreshed successfully on backend.');
      } else {
        // Fallback: register as a new token if refresh endpoint rejects.
        await _registerTokenWithBackend(
          fcmToken: newToken,
          authToken: authToken,
          employeeCode: employeeCode,
        );
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
        body: jsonEncode({
          'fcm_token': fcmToken,
          'platform': _deviceType,
          'token': fcmToken,
          'device_type': _deviceType,
        }),
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
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
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

  void _listenForForegroundMessages(
    void Function(RemoteMessage message)? onMessage,
  ) {
    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        debugPrint(
          '[FCM] Foreground message. action=${_actionOf(message)} '
          'title=${message.notification?.title}',
        );
        final action = _actionOf(message);
        if (action == kFcmActionProcessingCompleted ||
            action == kFcmActionStockValidationFailed) {
          await handleNotification(
            message,
            fromTap: false,
            isForeground: true,
          );
          return;
        }
        onMessage?.call(message);
      },
      onError: (e) {
        debugPrint('[FCM] Foreground message stream error: $e');
      },
    );
  }

  void _attachTapHandlers() {
    if (_tapHandlersAttached) return;
    _tapHandlersAttached = true;

    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(handleNotification(message, fromTap: true));
    });
  }

  Future<void> _showProcessingCompletedLocalNotification(
    RemoteMessage message,
  ) async {
    await _ensureLocalNotifications();
    if (kIsWeb) {
      // Web: fall back to a snackbar via root messenger if available.
      final ctx = AppNavigator.context;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text(
              'File Processing Completed — Your stock statement has been '
              'processed successfully.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    await _localNotifications.show(
      message.hashCode,
      'File Processing Completed',
      'Your stock statement has been processed successfully.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kSecondarySalesFcmChannelId,
          kSecondarySalesFcmChannelName,
          channelDescription:
              'Secondary Sales processing and validation alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode({
        'action': kFcmActionProcessingCompleted,
        ...message.data,
      }),
    );
  }

  Future<void> _openSecondarySalesDashboard({
    required bool refresh,
    Map<String, dynamic>? validationData,
  }) async {
    if (refresh) SecondarySalesDataRefresh.notify();

    if (SecondarySalesPushBridge.instance.isOpen) {
      SecondarySalesPushBridge.instance.dispatch(
        tabIndex: 0,
        validationData: validationData,
      );
      return;
    }

    final nav = AppNavigator.state;
    if (nav == null) {
      if (validationData != null) {
        _pendingValidationData = validationData;
      }
      return;
    }

    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => PodEntryScreen(
          initialTabIndex: 0,
          pendingValidationData: validationData,
        ),
      ),
    );
  }

  Future<void> openSecondarySalesUpload() async {
    if (SecondarySalesPushBridge.instance.isOpen) {
      SecondarySalesPushBridge.instance.dispatch(tabIndex: 1);
      return;
    }
    final nav = AppNavigator.state;
    if (nav == null) return;
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const PodEntryScreen(initialTabIndex: 1),
      ),
    );
  }

  Future<void> _showValidationFailedDialog(RemoteMessage message) async {
    final ctx = AppNavigator.context;
    if (ctx == null || !ctx.mounted) {
      _pendingValidationData = Map<String, dynamic>.from(message.data);
      return;
    }

    final failure =
        SecondarySalesValidationFailure.fromMessageData(message.data);

    await SecondarySalesStockValidationFailedDialog.show(
      ctx,
      failure: failure,
      onReprocess: () async {
        final batchId = failure.batchId;
        if (batchId == null || batchId <= 0) {
          throw Exception('Missing batch id for reprocess.');
        }
        final prefs = await SharedPreferences.getInstance();
        final sfa = prefs.getString('auth_token');
        if (sfa != null && sfa.isNotEmpty) {
          await prefs.setString('authToken', sfa);
        }
        try {
          await BatchService().reprocessBatch(batchId);
          SecondarySalesDataRefresh.notify();
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('Processing started'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Color(0xFF2E7D32),
              ),
            );
          }
          await _openSecondarySalesDashboard(refresh: true);
        } catch (e) {
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(
                  e.toString().replaceFirst('Exception: ', ''),
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          rethrow;
        }
      },
      onReupload: () {
        unawaited(openSecondarySalesUpload());
      },
    );
  }
}
