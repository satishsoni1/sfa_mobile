// import 'dart:io'; // Was used for exit(0) — removed in Phase 3 (POD is now embedded, not standalone)

import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // Was used for SystemNavigator.pop() — removed in Phase 3
import 'package:zforce/features/pod/screens/modern_document_upload_screen.dart';
// import 'package:zforce/features/pod/screens/profile_screen.dart'; // Profile screen commented out
import 'package:zforce/features/pod/screens/unified_dashboard_screen.dart';
import 'package:zforce/features/pod/services/api_client.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    // Set context for API client after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _apiClient.setContext(context);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update context whenever dependencies change
    _apiClient.setContext(context);
  }

  Future<bool> _onWillPop() async {
    // Only show exit dialog when on the first tab (Dashboard)
    if (_currentIndex == 0) {
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.exit_to_app,
                color: const Color(0xFF450095),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Exit App',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          content: const Text(
            'Do you want to exit the app?',
            style: TextStyle(
              color: Color(0xFF7F8C8D),
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF7F8C8D),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // ============================================================
                // PHASE 3 — EMBEDDED APP FIX
                // ------------------------------------------------------------
                // Step 1: Close the dialog (pop from the dialog's context,
                //         which is within the POD navigator).
                // Step 2: Pop the SFA ROOT navigator to return to the SFA
                //         DashboardScreen. rootNavigator: true skips the POD
                //         nested Navigator and pops PodEntryScreen off SFA.
                //
                // IMPORTANT: Do NOT use Navigator.of(context).pop() alone —
                // that pops the POD navigator revealing the error page beneath.
                //
                // Original code (DO NOT RESTORE — this was for standalone POD):
                // SystemNavigator.pop();
                // exit(0);
                // ============================================================
                Navigator.of(context).pop(true); // Close the dialog
                // After dialog closes, pop the entire POD feature from SFA stack
                Navigator.of(context, rootNavigator: true).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF450095),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Exit',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
      return false; // Always return false since we handle exit in the button
    } else {
      // Navigate back to Dashboard tab instead of exiting
      setState(() {
        _currentIndex = 0;
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Upload is back in the bottom nav between Dashboard and Profile —
    // the FAB on the Dashboard is removed in tandem so Upload has
    // exactly one entry point in the persistent UI. Drawer entries
    // (if any) are unaffected.
    final List<Widget> screens = [
      const UnifiedDashboardScreen(),
      const ModernDocumentUploadScreen(),
      // const ProfileScreen(), // Profile screen commented out as per requirement
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        await _onWillPop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF450095),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.upload_file),
              label: 'Upload',
            ),
            // Profile icon commented out as per requirement
            // BottomNavigationBarItem(
            //   icon: Icon(Icons.person),
            //   label: 'Profile',
            // ),
          ],
        ),
      ),
    );
  }
}

