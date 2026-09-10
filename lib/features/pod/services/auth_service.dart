// ============================================================
// POD / SECONDARY SALES — AUTH SERVICE
// ------------------------------------------------------------
// PHASE 3: Auth is now unified with SFA.
//
// This service is kept for backwards-compatibility with any
// POD code that calls AuthService.logout() or AuthService.isAuthenticated().
//
// Key behaviour changes from the original standalone POD:
//
// 1. logout() no longer removes 'authToken' from SharedPreferences.
//    The token is bridged from SFA by PodEntryScreen. Only SFA's
//    ApiService.clearSession() (which calls prefs.clear()) should
//    clear all keys — it does so on SFA logout already.
//    Removing 'authToken' here would cause all POD API calls to fail
//    until the user re-opens "Secondary Sales".
//
// 2. logout() no longer navigates to PodRoutes.login.
//    The POD login screen is intentionally bypassed in Phase 3.
//    On a 401 error we pop the POD Navigator to return to SFA.
//    SFA's own AuthProvider will handle session expiry if needed.
//
// 3. isAuthenticated() and getAuthToken() still work correctly
//    because PodEntryScreen writes 'authToken' before the POD
//    Navigator is rendered.
//
// DO NOT restore the original prefs.remove() / PodRoutes.login
// behaviour without a full review of the Phase 3 auth architecture.
// ============================================================
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:zforce/features/pod/routes/pod_routes.dart'; // Was used for PodRoutes.login — bypassed in Phase 3

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// Called when a 401 Unauthorized is received from the POD backend.
  /// PHASE 3: Pops the POD Navigator to return to SFA dashboard.
  /// The SFA AuthProvider will handle full session expiry separately.
  static Future<void> logout(BuildContext? context) async {
    try {
      // ── PHASE 3: Do NOT remove SharedPreferences keys here ──────────
      // The 'authToken' key is written by PodEntryScreen using the SFA
      // token. Removing it here would break all in-flight POD API calls.
      // SFA's ApiService.clearSession() calls prefs.clear() on full
      // logout — that safely wipes all keys including POD keys.
      //
      // Original code (DO NOT RESTORE without architecture review):
      // final prefs = await SharedPreferences.getInstance();
      // await prefs.remove('authToken');
      // await prefs.remove('userEmail');
      // await prefs.remove('userName');
      // ────────────────────────────────────────────────────────────────

      debugPrint('[AuthService] 401 received — popping POD Navigator back to SFA.');

      // Navigate back to SFA dashboard by popping the POD Navigator.
      // PHASE 3: Do NOT navigate to PodRoutes.login — that screen is
      // intentionally bypassed. Popping returns control to SFA.
      //
      // Original code (DO NOT RESTORE — POD login screen is bypassed):
      // Navigator.of(context).pushNamedAndRemoveUntil(
      //   PodRoutes.login,
      //   (route) => false,
      // );
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(); // Return to SFA dashboard
      }
    } catch (e) {
      debugPrint('[AuthService] Error during logout: $e');
    }
  }

  /// Check if user is authenticated (token is present in SharedPreferences).
  /// PHASE 3: Works correctly — PodEntryScreen writes 'authToken' before
  /// the POD Navigator renders so this will always return true inside POD.
  static Future<bool> isAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('[AuthService] Error checking authentication: $e');
      return false;
    }
  }

  /// Get stored auth token.
  /// PHASE 3: Returns the SFA token that was bridged by PodEntryScreen.
  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('authToken');
    } catch (e) {
      debugPrint('[AuthService] Error getting auth token: $e');
      return null;
    }
  }

  /// Get user email — display only, read-only.
  /// PHASE 3: Returns the value bridged from SFA user_data by PodEntryScreen.
  static Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userEmail');
    } catch (e) {
      debugPrint('[AuthService] Error getting user email: $e');
      return null;
    }
  }

  /// Get user name — display only, read-only.
  /// PHASE 3: Returns the value bridged from SFA user_data by PodEntryScreen.
  static Future<String?> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userName');
    } catch (e) {
      debugPrint('[AuthService] Error getting user name: $e');
      return null;
    }
  }
}


