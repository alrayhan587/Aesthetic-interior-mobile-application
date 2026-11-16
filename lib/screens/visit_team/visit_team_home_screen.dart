import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/user_session_manager.dart';
import '../../services/fcm_service.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fui_kit/fui_kit.dart';

import '../../data/user/user_api_service.dart';
import '../../theme/crm_colors.dart';
import 'dashboard_screen.dart';
import 'visits_screen.dart';
import 'today_visits_screen.dart';
import '../user_profile_view_screen.dart';
import 'control_visits_screen.dart';

class VisitTeamHomeScreen extends StatefulWidget {
  const VisitTeamHomeScreen({super.key});

  @override
  State<VisitTeamHomeScreen> createState() => _VisitTeamHomeScreenState();
}

class _VisitTeamHomeScreenState extends State<VisitTeamHomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _roleChecked = false;
  bool _isLeader = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when app resumes from background — check for pending FCM navigation.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final pending = FcmService.pendingNavTabIndex;
      if (pending != null) {
        FcmService.pendingNavTabIndex = null;
        _safeNavigateToTab(pending);
      }
    }
  }

  void _safeNavigateToTab(int tabIndex) {
    if (!mounted) return;
    final screens = _buildScreens();
    setState(() => _currentIndex = tabIndex.clamp(0, screens.length - 1));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserRole();
    // Check if a notification tap happened while app was closed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = FcmService.pendingNavTabIndex;
      if (pending != null) {
        FcmService.pendingNavTabIndex = null;
        _safeNavigateToTab(pending);
      }
    });
  }

  List<Widget> _buildScreens() {
    return [
      VisitTeamDashboardScreen(
        onNavigateToVisits: () => setState(() => _currentIndex = 1),
      ),
      const VisitsScreen(),
      const TodayVisitsScreen(),
      if (_isLeader) const ControlVisitsScreen(),
      const UserProfileViewScreen(),
    ];
  }

  Future<void> _fetchUserRole() async {
    try {
      final token = UserSessionManager.instance.token ?? '';
      if (token.isEmpty) {
        if (mounted) setState(() => _roleChecked = true);
        return;
      }
      final user = await UserApiService().fetchMe(token);
      if (!mounted) return;
      final isLeader = user?.isVisitTeamLeader ?? false;
      setState(() {
        _isLeader = isLeader;
        _roleChecked = true;
        // Land leaders directly on the Control tab (index 3)
        if (isLeader) _currentIndex = 3;
      });
    } catch (_) {
      if (mounted) setState(() => _roleChecked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleChecked) {
      return const Scaffold(
        body: Center(
          child: SpinKitFoldingCube(color: CrmColors.brandPrimary, size: 40.0),
        ),
      );
    }

    final screens = _buildScreens();

    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return PopScope(
      // Intercept the Android back-gesture / button.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentIndex != 0) {
          // Go back to the Home tab instead of closing the app.
          setState(() => _currentIndex = 0);
        }
        // If already on Home tab, do nothing (don't close the app).
      },
      child: Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: screens[safeIndex],
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
            ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: CrmColors.brandPrimary.withValues(alpha: 0.15),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CrmColors.brandPrimary,
                  );
                }
                return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: CrmColors.mutedForeground,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: CrmColors.brandPrimary, size: 30);
                }
                return const IconThemeData(color: CrmColors.mutedForeground, size: 28);
              }),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              selectedIndex: safeIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
            destinations: [
              NavigationDestination(
                icon: FUI(RegularRounded.home, color: CrmColors.mutedForeground, width: 22, height: 22),
                selectedIcon: FUI(SolidRounded.home, color: CrmColors.brandPrimary, width: 24, height: 24),
                label: 'Home',
              ),
              NavigationDestination(
                icon: FUI(RegularRounded.listCheck, color: CrmColors.mutedForeground, width: 22, height: 22),
                selectedIcon: FUI(SolidRounded.listCheck, color: CrmColors.brandPrimary, width: 24, height: 24),
                label: 'Visits',
              ),
              NavigationDestination(
                icon: FUI(RegularRounded.calendar, color: CrmColors.mutedForeground, width: 22, height: 22),
                selectedIcon: FUI(SolidRounded.calendar, color: CrmColors.brandPrimary, width: 24, height: 24),
                label: 'Today',
              ),
              if (_isLeader)
                NavigationDestination(
                  icon: FUI(RegularRounded.settings, color: CrmColors.mutedForeground, width: 22, height: 22),
                  selectedIcon: FUI(SolidRounded.settings, color: CrmColors.brandPrimary, width: 24, height: 24),
                  label: 'Control',
                ),
              NavigationDestination(
                icon: FUI(RegularRounded.user, color: CrmColors.mutedForeground, width: 22, height: 22),
                selectedIcon: FUI(SolidRounded.user, color: CrmColors.brandPrimary, width: 24, height: 24),
                label: 'Profile',
              ),
            ],
          ),
        ),
          ),
        ),
      ),
    ), // Scaffold
    ); // PopScope
  }
}
