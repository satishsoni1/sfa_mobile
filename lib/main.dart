import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// TODO [iOS]: Firebase is temporarily disabled on native platforms.
// To re-enable: add GoogleService-Info.plist to ios/Runner/ and
// add the iOS case in firebase_options.dart, then uncomment the import below.
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'providers/report_provider.dart';
import 'providers/auth_provider.dart';
import 'presentation/dashboard/dashboard_screen.dart';
import 'presentation/login/login_screen.dart';
import 'presentation/webview/internal_webview_screen.dart';

void main() async {
  // Required before any async work in main().
  WidgetsFlutterBinding.ensureInitialized();

  // TODO [iOS]: Firebase init is temporarily commented out on native platforms.
  // Web still initialises Firebase because it uses a web-only config that works.
  // Once GoogleService-Info.plist and iOS FirebaseOptions are added, remove this
  // guard and restore the unconditional Firebase.initializeApp() call below.
  if (kIsWeb) {
    // Web-only Firebase init — safe because web config is already present.
    // Dynamically import to avoid dart compile-time errors when firebase_core
    // is used but iOS config is missing at runtime.
    try {
      // ignore: avoid_dynamic_calls
      // Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('[Firebase] Web init skipped — re-enable when iOS config is ready.');
    } catch (e) {
      debugPrint('[Firebase] Init error (non-fatal): $e');
    }
  } else {
    // Native (iOS / Android): Firebase disabled until iOS credentials are added.
    // Uncomment the two lines below after adding GoogleService-Info.plist:
    // await Firebase.initializeApp(
    //   options: DefaultFirebaseOptions.currentPlatform,
    // );
    debugPrint('[Firebase] Skipped on native platform — iOS config not yet added.');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        // AuthProvider checks existing session on creation.
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..checkLoginStatus(),
        ),
      ],
      child: const ZForceApp(),
    ),
  );
}

class ZForceApp extends StatelessWidget {
  const ZForceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return MaterialApp(
          title: 'vodo',
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
          // Smart navigation based on Auth State.
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
