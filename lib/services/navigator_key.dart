import 'package:flutter/material.dart';

/// A single app-wide navigator key so that FCM notification taps can
/// push routes without needing a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
