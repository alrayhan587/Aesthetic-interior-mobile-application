import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../data/user/user_api_service.dart';
import '../theme/crm_colors.dart';
import '../services/notification_manager.dart';
import '../services/fcm_service.dart';
import '../services/user_session_manager.dart';
import 'login_screen.dart';
import 'procurement/procurement_home_screen.dart';
import 'visit_team/visit_team_home_screen.dart';
import 'senior_crm/senior_crm_home_screen.dart';

/// The state of the startup role-check.
enum _RootState {
  /// Checking the on-disk cache (instant, no network).
  loading,

  /// Role identified — either from cache or fresh fetch.
  ready,

  /// No network and no cache — allow the user to retry.
  networkError,

  /// User is authenticated but has no recognised department.
  noAccess,
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  _RootState _state = _RootState.loading;
  bool _isSeniorCrm = false;
  bool _isVisitTeam = false;
  bool _isProcurement = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    NotificationManager.instance.stopPolling();
    super.dispose();
  }

  // ── Boot sequence ──────────────────────────────────────────────────────────

  Future<void> _init() async {
    // ── Step 1: Try the on-disk cache first (instant, no network needed). ──
    final cached = await UserSessionManager.instance.loadCached();

    if (!UserSessionManager.instance.isLoggedIn) {
      if (!mounted) return;
      _navigateToLogin();
      return;
    }

    if (cached != null && mounted) {
      setState(() {
        _isSeniorCrm = cached.isSeniorCrm;
        _isVisitTeam = cached.isVisitTeam;
        _isProcurement = cached.isProcurement;
        _state = (cached.isSeniorCrm ||
                cached.isVisitTeam ||
                cached.isProcurement)
            ? _RootState.ready
            : _RootState.noAccess;
      });

      if (cached.isSeniorCrm ||
          cached.isVisitTeam ||
          cached.isProcurement) {
        await _startServices();
        _refreshRoleInBackground();
        return;
      }
    }

    // ── Step 2: No usable cache — fetch from network. ──
    await _fetchRole(isRetry: false);
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Full network fetch. [isRetry] is true when the user tapped "Try Again".
  Future<void> _fetchRole({required bool isRetry}) async {
    if (isRetry && mounted) {
      setState(() => _state = _RootState.loading);
    }

    final token = UserSessionManager.instance.token;
    if (token == null || token.isEmpty) {
      if (mounted) _navigateToLogin();
      return;
    }

    try {
      final user = await UserApiService().fetchMe(token);
      if (!mounted) return;

      if (user == null) {
        // If cached role already exists, stay on ready, otherwise show network error
        if (UserSessionManager.instance.hasCachedRole) {
          return;
        }
        setState(() => _state = _RootState.networkError);
        return;
      }

      // Persist for next cold start.
      await UserSessionManager.instance.save(user);

      if (!mounted) return;
      setState(() {
        _isSeniorCrm = user.isSeniorCrm;
        _isVisitTeam = user.isVisitTeam;
        _isProcurement = user.isProcurement;
        _state = (user.isSeniorCrm ||
                user.isVisitTeam ||
                user.isProcurement)
            ? _RootState.ready
            : _RootState.noAccess;
      });

      if (user.isSeniorCrm || user.isVisitTeam || user.isProcurement) {
        await _startServices(token: token);
      }
    } catch (_) {
      if (mounted && !UserSessionManager.instance.hasCachedRole) {
        setState(() => _state = _RootState.networkError);
      }
    }
  }

  /// Silent background refresh — updates the cache without jarring UI changes.
  Future<void> _refreshRoleInBackground() async {
    final token = UserSessionManager.instance.token;
    if (token == null || token.isEmpty) return;

    try {
      final user = await UserApiService().fetchMe(token);
      if (user == null) return;

      await UserSessionManager.instance.save(user);
      FcmService.registerToken(token);
    } catch (_) {
      // Silently ignored — cached session is still active
    }
  }

  /// Wires up FCM token registration and the in-app notification polling.
  Future<void> _startServices({String? token}) async {
    final resolvedToken = token ?? UserSessionManager.instance.token ?? '';
    if (resolvedToken.isEmpty) return;

    NotificationManager.instance.startPolling(
      resolvedToken,
      tokenRefresher: () async => UserSessionManager.instance.token,
    );

    FcmService.registerToken(resolvedToken);
  }

  Future<void> _handleSignOut() async {
    await UserSessionManager.instance.clear();
    if (!mounted) return;
    _navigateToLogin();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _RootState.loading:
        return const Scaffold(
          body: Center(
            child: SpinKitFoldingCube(
              color: CrmColors.brandPrimary,
              size: 40.0,
            ),
          ),
        );

      case _RootState.networkError:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Connection Problem',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Could not reach the server. '
                    'Please check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CrmColors.mutedForeground,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: () => _fetchRole(isRetry: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CrmColors.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _handleSignOut,
                    child: const Text('Sign out to log in again'),
                  ),
                ],
              ),
            ),
          ),
        );

      case _RootState.noAccess:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.block_rounded,
                    size: 64,
                    color: CrmColors.error,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Not Authorised',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your account is not assigned to SR_CRM, VISIT_TEAM, '
                    'or PROCUREMENT. Contact your administrator.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CrmColors.mutedForeground,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: _handleSignOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CrmColors.error,
                      side: const BorderSide(color: CrmColors.error),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case _RootState.ready:
        if (_isProcurement) return const ProcurementHomeScreen();
        if (_isSeniorCrm) return const SeniorCrmHomeScreen();
        if (_isVisitTeam) return const VisitTeamHomeScreen();
        return const Scaffold(
          body: Center(
            child: SpinKitFoldingCube(
              color: CrmColors.brandPrimary,
              size: 40.0,
            ),
          ),
        );
    }
  }
}
