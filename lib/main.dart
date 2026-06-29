import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/clm_provider.dart';
import 'providers/data_bank_provider.dart';
import 'providers/report_provider.dart';
import 'providers/ai_hub_provider.dart';
import 'presentation/dashboard/dashboard_screen.dart';
import 'presentation/login/login_screen.dart';
import 'presentation/webview/internal_webview_screen.dart';

void main() {
  // 1. We wrap the ENTIRE app in MultiProvider here.
  // This ensures Providers are at the very top of the widget tree.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkLoginStatus()),
        ChangeNotifierProvider(create: (_) => ClmProvider()),
        ChangeNotifierProvider(create: (_) => DataBankProvider()),
        ChangeNotifierProvider(create: (_) => AiHubProvider()),
      ],
      child: const ZForceApp(),
    ),
  );
}

class ZForceApp extends StatelessWidget {
  const ZForceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. Now Consumer can safely find AuthProvider because ZForceApp is a child of MultiProvider
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return MaterialApp(
          title: 'ZForce',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme, // Uses your theme file
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
          // 3. Smart Navigation based on Auth State
          home: auth.isLoading
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ) // Splash Screen
              : auth.isAuthenticated
              ? const DashboardScreen()
              : const LoginScreen(),
        );
      },
    );
  }
}
