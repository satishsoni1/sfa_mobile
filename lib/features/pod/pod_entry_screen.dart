// ============================================================
// POD / SECONDARY SALES — FEATURE ENTRY POINT (Phase 3)
// ------------------------------------------------------------
// This screen bridges the SFA authentication layer into the
// embedded POD feature module.
//
// Navigation path:
//   SFA Dashboard → Field Operations → Secondary Sales
//   → PodEntryScreen (reads SFA token, writes POD keys)
//   → POD MainNavigation (directly — splash + login bypassed)
//
// Authentication Bridge:
//   SFA stores its token under key: 'auth_token'
//   SFA stores user data under key: 'user_data'
//   POD reads its token from key:   'authToken'
//   POD reads user email from key:  'userEmail'
//   POD reads user name from key:   'userName'
//
//   This screen reads SFA keys and writes them into POD keys
//   BEFORE the POD Navigator is rendered. This ensures every
//   POD API call (which reads 'authToken') has a valid token.
//
// SFA logout (clearSession) calls prefs.clear() which removes
// all keys including the POD bridge keys — safe by design.
//
// POD's own login screen is bypassed completely.
// SFA owns the single login/logout lifecycle for this app.
// ============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zforce/features/pod/routes/pod_routes.dart';
import 'package:zforce/features/pod/services/firebase_service.dart';

/// Entry point that bridges SFA auth into the POD feature module.
class PodEntryScreen extends StatefulWidget {
  const PodEntryScreen({super.key});

  @override
  State<PodEntryScreen> createState() => _PodEntryScreenState();
}

class _PodEntryScreenState extends State<PodEntryScreen> {
  late final Future<bool> _bridgeFuture;

  @override
  void initState() {
    super.initState();
    _bridgeFuture = _bridgeAuthAndInit();
  }

  /// Reads SFA auth data and writes it into POD's SharedPreferences keys.
  /// Also initializes POD's Firebase services (foreground notifications + analytics).
  /// Returns true if a valid token was found, false if the session is missing.
  Future<bool> _bridgeAuthAndInit() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // --- Read SFA session ---
      final sfaToken = prefs.getString('auth_token');
      final sfaUserJson = prefs.getString('user_data');

      if (sfaToken == null || sfaToken.isEmpty) {
        // No SFA session — should not normally happen since SFA guards navigation.
        // Return false so we can show an error instead of a blank POD screen.
        return false;
      }

      // --- Write POD auth keys (same values, different key names) ---
      await prefs.setString('authToken', sfaToken);

      // Derive email and display name from SFA user data.
      if (sfaUserJson != null && sfaUserJson.isNotEmpty) {
        try {
          final userMap = jsonDecode(sfaUserJson) as Map<String, dynamic>;
          final email = (userMap['email'] as String?) ?? '';
          final firstName = (userMap['first_name'] as String?) ?? '';
          final lastName = (userMap['last_name'] as String?) ?? '';
          final displayName = lastName.isNotEmpty
              ? '$firstName $lastName'
              : firstName;
          await prefs.setString('userEmail', email);
          await prefs.setString('userName', displayName);
        } catch (_) {
          // If user JSON parsing fails, write empty strings gracefully.
          await prefs.setString('userEmail', '');
          await prefs.setString('userName', '');
        }
      }

      // --- Initialize POD Firebase services (foreground + analytics only) ---
      await FirebaseService().initialize();

      return true;
    } catch (e) {
      debugPrint('[PodEntryScreen] Auth bridge error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _bridgeFuture,
      builder: (context, snapshot) {
        // While the bridge is running, show a branded loading screen.
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF450095),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading Secondary Sales...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Bridge succeeded — token is valid — go straight to POD dashboard.
        if (snapshot.data == true) {
          return Navigator(
            // ============================================================
            // CRITICAL: onGenerateInitialRoutes MUST be specified here.
            // Without it, Flutter's defaultGenerateInitialRoutes splits
            // '/pod/main' into segments and pushes '/' and '/pod' onto
            // the stack BENEATH '/pod/main'. Since '/' is not defined in
            // PodRouteGenerator, pressing back reveals "Route not found: /".
            // This override generates ONLY the single '/pod/main' route so
            // the stack is clean: exactly one page — MainNavigation.
            // ============================================================
            onGenerateInitialRoutes: (NavigatorState navigator, String initialRoute) {
              return [PodRouteGenerator.generateRoute(
                const RouteSettings(name: PodRoutes.mainNavigation),
              )];
            },
            initialRoute: PodRoutes.mainNavigation,
            onGenerateRoute: PodRouteGenerator.generateRoute,
          );
        }

        // Bridge failed — SFA session missing — go back to SFA.
        // This should never happen in normal use since SFA's AuthProvider
        // guards navigation. Show an error and pop back.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session error. Please log in again.'),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.of(context).pop();
          }
        });

        return const Scaffold(
          backgroundColor: Color(0xFF450095),
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      },
    );
  }
}