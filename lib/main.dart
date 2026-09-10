// import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
// import 'firebase_options.dart';
import 'providers/report_provider.dart';
import 'providers/auth_provider.dart';
import 'presentation/dashboard/dashboard_screen.dart';
import 'presentation/login/login_screen.dart';
import 'presentation/webview/internal_webview_screen.dart';

void main() async {
  // Required before any async work in main().
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // TEMPORARILY COMMENTED: Firebase Initialization
  // Uncomment this block when Firebase google-services.json is configured.
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );
  // debugPrint('[Firebase] Initialized successfully.');
  // ============================================================
  
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
          title: 'himalayas-app',
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
