import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_navigator.dart';
import 'data/services/fcm_notification_service.dart';
import 'firebase_options.dart';
import 'providers/report_provider.dart';
import 'providers/auth_provider.dart';
import 'presentation/dashboard/dashboard_screen.dart';
import 'presentation/login/login_screen.dart';
import 'presentation/webview/internal_webview_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('[Firebase] initialize started');
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[Firebase] initialize successful');
    } else {
      // Native FirebaseInitProvider may already have created [DEFAULT]
      // from google-services.json — do not re-init (avoids duplicate-app).
      debugPrint(
        '[Firebase] initialize skipped — default app already exists',
      );
    }
  } catch (e) {
    debugPrint('[Firebase] initialize FAILED: $e');
    // Never block splash/login on Firebase init failure.
  }

  // Must be registered before runApp (top-level isolate handler).
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Capture terminated-app notification tap before UI mounts.
  try {
    await FcmNotificationService.instance.captureInitialMessage();
  } catch (e) {
    debugPrint('[Firebase] captureInitialMessage FAILED: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..checkLoginStatus(),
        ),
      ],
      child: const ZForceApp(),
    ),
  );
}

class ZForceApp extends StatefulWidget {
  const ZForceApp({super.key});

  @override
  State<ZForceApp> createState() => _ZForceAppState();
}

class _ZForceAppState extends State<ZForceApp> {
  bool _pendingConsumed = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.isAuthenticated && !_pendingConsumed) {
          _pendingConsumed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FcmNotificationService.instance.consumePendingInitialMessage();
          });
        }
        if (!auth.isAuthenticated) {
          _pendingConsumed = false;
        }

        return MaterialApp(
          title: 'vodo',
          navigatorKey: AppNavigator.key,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          onGenerateRoute: (settings) {
            if (settings.name == InternalWebViewScreen.routeName) {
              final args = settings.arguments;
              if (args is InternalWebViewArgs) {
                return MaterialPageRoute(
                  builder: (_) => InternalWebViewScreen(args: args),
                  settings: settings,
                );
              }
            }
            return null;
          },
          home: auth.isLoading
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              : auth.isAuthenticated
                  ? const DashboardScreen()
                  : const LoginScreen(),
        );
      },
    );
  }
}
