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
import 'package:zforce/data/services/fcm_notification_service.dart';
import 'package:zforce/features/pod/models/secondary_sales_validation_failure.dart';
import 'package:zforce/features/pod/routes/pod_routes.dart';
import 'package:zforce/features/pod/screens/main_navigation.dart';
import 'package:zforce/features/pod/services/batch_service.dart';
import 'package:zforce/features/pod/services/firebase_service.dart';
import 'package:zforce/features/pod/services/secondary_sales_data_refresh.dart';
import 'package:zforce/features/pod/widgets/secondary_sales_stock_validation_failed_dialog.dart';

/// Entry point that bridges SFA auth into the POD feature module.
class PodEntryScreen extends StatefulWidget {
  const PodEntryScreen({
    super.key,
    this.initialTabIndex = 0,
    this.pendingValidationData,
  });

  /// 0 = Dashboard, 1 = Upload.
  final int initialTabIndex;

  /// When opened from `stock_validation_failed` notification tap.
  final Map<String, dynamic>? pendingValidationData;

  @override
  State<PodEntryScreen> createState() => _PodEntryScreenState();
}

class _PodEntryScreenState extends State<PodEntryScreen> {
  late final Future<bool> _bridgeFuture;
  final GlobalKey<NavigatorState> _podNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<MainNavigationState> _mainNavKey =
      GlobalKey<MainNavigationState>();
  bool _validationDialogShown = false;

  void _onPushAction(int tabIndex, Map<String, dynamic>? validationData) {
    _mainNavKey.currentState?.selectTab(tabIndex);
    if (validationData != null) {
      _showValidationDialog(validationData);
    }
  }

  @override
  void initState() {
    super.initState();
    _bridgeFuture = _bridgeAuthAndInit();
    SecondarySalesPushBridge.instance.register(_onPushAction);
  }

  @override
  void dispose() {
    SecondarySalesPushBridge.instance.unregister(_onPushAction);
    super.dispose();
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

      // --- Initialize POD Firebase services (analytics only; FCM owned by SFA) ---
      await FirebaseService().initialize();

      return true;
    } catch (e) {
      debugPrint('[PodEntryScreen] Auth bridge error: $e');
      return false;
    }
  }

  Future<void> _showValidationDialog(Map<String, dynamic> data) async {
    if (!mounted) return;
    final failure = SecondarySalesValidationFailure.fromMessageData(data);
    await SecondarySalesStockValidationFailedDialog.show(
      context,
      failure: failure,
      onReprocess: () async {
        final batchId = failure.batchId;
        if (batchId == null || batchId <= 0) {
          throw Exception('Missing batch id for reprocess.');
        }
        try {
          await BatchService().reprocessBatch(batchId);
          SecondarySalesDataRefresh.notify();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Processing started'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF2E7D32),
            ),
          );
          _mainNavKey.currentState?.selectTab(0);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          rethrow;
        }
      },
      onReupload: () {
        _mainNavKey.currentState?.selectTab(1);
      },
    );
  }

  void _maybeShowPendingValidationDialog() {
    if (_validationDialogShown) return;
    final data = widget.pendingValidationData;
    if (data == null) return;
    _validationDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showValidationDialog(data);
    });
  }

  /// Android / system Back landed on the SFA route that hosts Secondary Sales.
  Future<void> _handleSystemBack() async {
    final nested = _podNavigatorKey.currentState;
    final nestedCanPop = nested?.canPop() ?? false;
    debugPrint('[SecondarySales] nested canPop = $nestedCanPop');

    // Pop nested drill-down routes first (KAM stockists, statements, etc.).
    if (nested != null && nestedCanPop) {
      nested.pop();
      return;
    }

    // Forward into MainNavigation PopScope (leave confirm / leave upload).
    if (nested != null) {
      final handled = await nested.maybePop();
      debugPrint('[SecondarySales] nested maybePop handled=$handled');
      if (handled) return;
    }

    // Fallback if MainNavigation is not mounted yet.
    final mainNav = _mainNavKey.currentState;
    if (mainNav != null) {
      debugPrint('[SecondarySales] forwarding to MainNavigation.handleSystemBack');
      await mainNav.handleSystemBack();
      return;
    }

    if (!mounted) return;
    debugPrint('[SecondarySales] fallback leave confirmation at PodEntry');
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Leave Secondary Sales',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        content: const Text('Do you want to return to Home?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF450095),
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (leave == true) {
      debugPrint('[SecondarySales] user confirmed leave');
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    } else {
      debugPrint('[SecondarySales] user cancelled');
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
          _maybeShowPendingValidationDialog();
          // ============================================================
          // SYSTEM BACK (Android) vs AppBar BACK
          // ------------------------------------------------------------
          // MaterialApp's root Navigator receives Android system back.
          // The nested POD Navigator is NOT consulted first, so a PopScope
          // only inside MainNavigation never runs for device Back.
          //
          // PopScope here registers on the SFA route (PodEntryScreen) and
          // forwards into the nested navigator / MainNavigation leave flow.
          // ============================================================
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              debugPrint(
                '[SecondarySales] system back received '
                '(PodEntry PopScope) didPop=$didPop',
              );
              if (didPop) return;
              await _handleSystemBack();
            },
            child: Navigator(
              key: _podNavigatorKey,
              // CRITICAL: onGenerateInitialRoutes MUST be specified here.
              // Without it, Flutter's defaultGenerateInitialRoutes splits
              // '/pod/main' into segments and pushes '/' and '/pod' onto
              // the stack BENEATH '/pod/main'. Since '/' is not defined in
              // PodRouteGenerator, pressing back reveals "Route not found: /".
              // This override generates ONLY the single '/pod/main' route so
              // the stack is clean: exactly one page — MainNavigation.
              onGenerateInitialRoutes:
                  (NavigatorState navigator, String initialRoute) {
                return [
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(
                      name: PodRoutes.mainNavigation,
                    ),
                    builder: (_) => MainNavigation(
                      key: _mainNavKey,
                      initialIndex: widget.initialTabIndex,
                    ),
                  ),
                ];
              },
              initialRoute: PodRoutes.mainNavigation,
              onGenerateRoute: PodRouteGenerator.generateRoute,
            ),
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