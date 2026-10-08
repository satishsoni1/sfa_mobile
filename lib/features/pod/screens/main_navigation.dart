// import 'dart:io'; // Was used for exit(0) — removed in Phase 3 (POD is now embedded, not standalone)

import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // Was used for SystemNavigator.pop() — removed in Phase 3
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/screens/modern_document_upload_screen.dart';
// import 'package:zforce/features/pod/screens/profile_screen.dart'; // Profile screen commented out
import 'package:zforce/features/pod/screens/secondary_sales_dashboard_screen.dart';
import 'package:zforce/features/pod/screens/unified_dashboard_screen.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/services/secondary_sales_background_monitor.dart';
import 'package:zforce/features/pod/widgets/secondary_sales_leave_upload_dialog.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

/// Public so [PodEntryScreen] can forward Android system back into the module.
class MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;
  final ApiClient _apiClient = ApiClient();

  /// Same path as AppBar Back / nested [Navigator.maybePop] → leave confirm.
  Future<void> handleSystemBack() => _onWillPop();

  void selectTab(int index) {
    if (!mounted) return;
    final next = index.clamp(0, 1);
    if (_currentIndex == next) return;
    setState(() => _currentIndex = next);
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 1);
    // Set context for API client after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _apiClient.setContext(context);
      if (isSecondarySalesUpload) {
        SecondarySalesBackgroundMonitor.instance.attachMessengerContext(context);
        SecondarySalesBackgroundMonitor.instance.ensureStarted();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update context whenever dependencies change
    _apiClient.setContext(context);
    if (isSecondarySalesUpload) {
      SecondarySalesBackgroundMonitor.instance.attachMessengerContext(context);
    }
  }

  Future<bool> _onWillPop() async {
    debugPrint(
      '[SecondarySales] leave flow start tab=$_currentIndex '
      '(0=Dashboard, 1=Upload)',
    );
    // Dashboard tab — confirm before leaving the Secondary Sales module.
    if (_currentIndex == 0) {
      debugPrint('[SecondarySales] showing leave confirmation');
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.exit_to_app,
                color: Color(0xFF450095),
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Leave Secondary Sales',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Do you want to return to Home?',
            style: TextStyle(
              color: Color(0xFF7F8C8D),
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
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
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF450095),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Leave',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
      if (leave == true && mounted) {
        debugPrint('[SecondarySales] user confirmed leave');
        // Pop PodEntryScreen from the SFA root stack only after confirm.
        // Do not pop the nested POD navigator (that would show a blank route).
        final root = Navigator.of(context, rootNavigator: true);
        debugPrint('[SecondarySales] root canPop=${root.canPop()}');
        if (root.canPop()) {
          root.pop();
        }
      } else {
        debugPrint('[SecondarySales] user cancelled');
      }
      return false;
    }

    // Upload tab — confirm before leaving Upload screen (same as Upload AppBar).
    final leave = await showSecondarySalesLeaveUploadDialog(context);
    if (leave && mounted) {
      debugPrint('[SecondarySales] leave upload → Dashboard tab');
      setState(() {
        _currentIndex = 0;
      });
    } else {
      debugPrint('[SecondarySales] user cancelled leave upload');
    }
    return false;
  }

  Future<void> _onModuleBackPressed() async {
    // AppBar back on Dashboard / Upload — same as Android system back.
    debugPrint('[SecondarySales] AppBar back received');
    await _onWillPop();
  }

  @override
  Widget build(BuildContext context) {
    // Upload is back in the bottom nav between Dashboard and Profile —
    // the FAB on the Dashboard is removed in tandem so Upload has
    // exactly one entry point in the persistent UI. Drawer entries
    // (if any) are unaffected.
    final List<Widget> screens = [
      isSecondarySalesUpload
          ? SecondarySalesDashboardScreen(
              onBackPressed: _onModuleBackPressed,
            )
          : const UnifiedDashboardScreen(),
      ModernDocumentUploadScreen(
        isActive: _currentIndex == 1,
        onBackPressed: _onModuleBackPressed,
      ),
      // const ProfileScreen(), // Profile screen commented out as per requirement
    ];

    // Handles nested Navigator.maybePop() (forwarded from PodEntryScreen).
    // Alone this is NOT enough for Android system back: the SFA root navigator
    // owns the system pop and would otherwise dismiss PodEntryScreen silently.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        debugPrint(
          '[SecondarySales] MainNavigation PopScope invoked didPop=$didPop',
        );
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

