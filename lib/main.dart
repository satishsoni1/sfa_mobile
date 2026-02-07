import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/report_provider.dart';
import 'providers/auth_provider.dart'; // Ensure this file exists
import 'presentation/dashboard/dashboard_screen.dart';
import 'presentation/login/login_screen.dart';

void main() {
  // 1. We wrap the ENTIRE app in MultiProvider here.
  // This ensures Providers are at the very top of the widget tree.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        // We initialize AuthProvider and immediately check login status
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
    // 2. Now Consumer can safely find AuthProvider because ZForceApp is a child of MultiProvider
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return MaterialApp(
          title: 'ZForce',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme, // Uses your theme file
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
