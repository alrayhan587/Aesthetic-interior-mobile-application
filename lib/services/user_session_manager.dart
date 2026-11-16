import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/user/user_api_service.dart';

/// Persists the authenticated user's session token and profile
/// to a JSON file in the app's documents directory.
class UserSessionManager {
  UserSessionManager._();

  static final UserSessionManager instance = UserSessionManager._();

  static const _kFilename = 'user_session.json';

  File? _file;
  CurrentUser? _cached;
  String? _token;

  // ── Accessors ──────────────────────────────────────────────────────────────

  /// The cached JWT session token, or null if not signed in.
  String? get token => _token;

  /// The last successfully loaded [CurrentUser], or null if none cached.
  CurrentUser? get cachedUser => _cached;

  /// True if a valid session token exists.
  bool get isLoggedIn => _token != null && _token!.trim().isNotEmpty;

  bool get hasCachedRole =>
      _cached != null &&
      (_cached!.isSeniorCrm ||
          _cached!.isVisitTeam ||
          _cached!.isProcurement);

  // ── Persistence Helpers ───────────────────────────────────────────────────

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}$_kFilename');
    return _file!;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Load cached [CurrentUser] and session token from disk. Call on app startup.
  Future<CurrentUser?> loadCached() async {
    try {
      final file = await _getFile();
      if (!file.existsSync()) {
        return null;
      }
      final raw = await file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;

      _token = map['token'] as String?;
      if (map['user'] is Map<String, dynamic>) {
        _cached = CurrentUser.fromJson(map['user'] as Map<String, dynamic>);
      } else {
        _cached = CurrentUser.fromJson(map);
      }
      return _cached;
    } catch (_) {
      return null;
    }
  }

  /// Save [user] and optional [token] to disk.
  Future<void> save(CurrentUser user, {String? token}) async {
    try {
      _cached = user;
      if (token != null && token.isNotEmpty) {
        _token = token;
      }
      final file = await _getFile();
      final data = {
        'token': _token ?? '',
        'user': user.toJson(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  /// Remove the cached session (call on explicit sign-out).
  Future<void> clear() async {
    try {
      _cached = null;
      _token = null;
      final file = await _getFile();
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
