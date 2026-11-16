import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'navigator_key.dart';
import 'notification_manager.dart';

/// Top-level background message handler — must be a top-level function (not a method).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  final plugin = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await plugin.initialize(settings: initSettings);

  // Create channel — required on first run or fresh install.
  await plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'crm_notifications_channel',
          'CRM Notifications',
          description: 'Updates for CRM events',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

  final title = message.notification?.title ?? message.data['title'] ?? 'New Notification';
  final body = message.notification?.body ?? message.data['body'] ?? '';

  await plugin.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'crm_notifications_channel',
        'CRM Notifications',
        channelDescription: 'Updates for CRM events',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}

// ── Visit notification type constants ───────────────────────────────────────

const _visitTypes = {
  'VISIT_ASSIGNED',
  'VISIT_DUE',
  'VISIT_REMINDER_30M',
  'VISIT_DUE_10H',
  'VISIT_DUE_20H',
  'VISIT_DUE_24H',
  'VISIT_DUE_36H',
  'VISIT_DUE_48H',
  'VISIT_DUE_72H',
  'VISIT_RESCHEDULED',
  'VISIT_CANCELLED',
};

const _leaderboardTypes = {
  'VISIT_RANK_CHANGE',
};

// ── Deep link navigation ─────────────────────────────────────────────────────

/// Routes the user to the correct tab / screen based on the FCM data payload.
///
/// Tab indices for VisitTeamHomeScreen:
///   0 → Home / Dashboard
///   1 → Visits (All Visits)
///   2 → Today's Visits
///   3 → Control (leaders only) / Profile
///   4 → Profile (leaders only)
void _handleNotificationNavigation(Map<String, dynamic> data) {
  final type = data['type'] as String? ?? '';

  // Navigate to Visits tab (index 1) for all visit-type notifications
  if (_visitTypes.contains(type)) {
    _navigateToVisitTab(tabIndex: 1);
    return;
  }

  // Navigate to Home/Dashboard (index 0) for rank change notifications
  if (_leaderboardTypes.contains(type)) {
    _navigateToVisitTab(tabIndex: 0);
    return;
  }
}

void _navigateToVisitTab({required int tabIndex}) {
  final context = navigatorKey.currentContext;
  if (context == null) {
    return;
  }
  // Post-frame to avoid navigation during build/layout phases
  Future.delayed(Duration.zero, () {
    // The VisitTeamHomeScreen is a bottom-nav shell. We use a global callback
    // pattern — it listens on the notification stream and handles internally.
    FcmService.pendingNavTabIndex = tabIndex;
  });
}

// ── FcmService ───────────────────────────────────────────────────────────────

class FcmService {
  FcmService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localPlugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Set by notification deep-links; consumed by VisitTeamHomeScreen on resume.
  static int? pendingNavTabIndex;

  static Future<void> initialize() async {
    if (_initialized) return;

    // Register the top-level background handler.
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);

    // Request permission (iOS + Android 13+).
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set up local notifications plugin for foreground display.
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
    await _localPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // User tapped a local notification while app was foregrounded
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            _handleNotificationNavigation(data);
          } catch (_) {}
        }
      },
    );

    // Create the Android notification channel explicitly.
    await _localPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'crm_notifications_channel',
            'CRM Notifications',
            description: 'Updates for CRM events — visits, follow-ups, and more',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

    await _localPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // ── Foreground messages ────────────────────────────────────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? message.data['title'] ?? 'New Notification';
      final body = message.notification?.body ?? message.data['body'] ?? '';

      // Encode data payload as JSON string for the local notification
      final payloadJson = jsonEncode(message.data);
      _showLocalNotification(title, body, id: message.hashCode, payload: payloadJson);

      // Refresh the in-app notification bell list
      NotificationManager.instance.forceFetch();
    });

    // ── Notification opened app from background ────────────────────────────
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationNavigation(message.data);
      NotificationManager.instance.forceFetch();
    });

    // ── App launched from terminated state via notification ────────────────
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // Small delay so the widget tree is fully rendered before navigating
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleNotificationNavigation(initialMessage.data);
      });
    }

    _initialized = true;
  }

  static Future<void> _showLocalNotification(
    String title,
    String body, {
    int id = 0,
    String? payload,
  }) async {
    await _localPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'crm_notifications_channel',
          'CRM Notifications',
          channelDescription: 'Updates for CRM events',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Gets the FCM token and registers it with the backend.
  static Future<void> registerToken(String authToken) async {
    try {
      // On iOS, FCM requires APNs token first. Request it explicitly.
      // On Android this is a no-op.
      await _messaging.getAPNSToken().catchError((_) => null);

      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) {
        return;
      }

      final uri = Uri.parse(AppConfig.apiBaseUrl).resolve('/api/device-tokens');

      await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'token': fcmToken,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      ).timeout(const Duration(seconds: 15));

      // Listen for token refreshes and re-register.
      _messaging.onTokenRefresh.listen((newToken) {
        _reRegisterToken(authToken, newToken);
      });
    } catch (_) {}
  }

  static Future<void> _reRegisterToken(String authToken, String fcmToken) async {
    try {
      final uri = Uri.parse(AppConfig.apiBaseUrl).resolve('/api/device-tokens');
      await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'token': fcmToken,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  /// Removes the token when the user signs out.
  static Future<void> unregisterToken(String authToken) async {
    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) return;

      final uri = Uri.parse(AppConfig.apiBaseUrl).resolve('/api/device-tokens');
      await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'token': fcmToken}),
      ).timeout(const Duration(seconds: 15));

      await _messaging.deleteToken();
    } catch (_) {}
  }
}
