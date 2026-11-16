import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';

class CurrentUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final List<String> roles;
  final List<String> departments;

  const CurrentUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    required this.roles,
    required this.departments,
  });

  bool get isVisitTeamLeader {
    return roles.any((r) {
      final normalized = r.toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
      return normalized == 'VISIT_TEAM_LEADER' ||
          normalized == 'VISIT_TEAM_CO_LEADER';
    });
  }

  bool get isSeniorCrm {
    return departments.any((d) {
      final normalized = d.toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
      return normalized == 'SR_CRM' || normalized == 'SENIOR_CRM';
    }) || roles.any((r) {
      final normalized = r.toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
      return normalized == 'SR_CRM' || normalized == 'SENIOR_CRM';
    });
  }

  bool get isVisitTeam {
    return departments.any((d) {
      final normalized = d.toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
      return normalized == 'VISIT_TEAM';
    }) || roles.any((r) {
      final normalized = r.toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
      return normalized == 'VISIT_TEAM' || normalized == 'VISIT_TEAM_MEMBER';
    });
  }

  bool get isProcurement {
    return departments.any((d) {
      final normalized = d.toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
      return normalized.contains('PROCUREMENT') ||
          normalized.contains('SUPPLY_CHAIN') ||
          normalized == 'ADMIN';
    }) || roles.any((r) {
      final normalized = r.toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
      return normalized.contains('PROCUREMENT') ||
          normalized.contains('SUPPLY_CHAIN') ||
          normalized == 'ADMIN';
    });
  }

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    // Support both the raw API shape (nested userRoles/userDepartments) and
    // the flat cached shape written by toJson().
    final rolesList = <String>[];
    if (json['userRoles'] is List) {
      for (final item in json['userRoles']) {
        if (item['role'] is Map && item['role']['name'] is String) {
          rolesList.add(item['role']['name'] as String);
        }
      }
    } else if (json['roles'] is List) {
      for (final r in json['roles']) {
        if (r is String) rolesList.add(r);
      }
    }

    final depsList = <String>[];
    if (json['userDepartments'] is List) {
      for (final item in json['userDepartments']) {
        if (item['department'] is Map &&
            item['department']['name'] is String) {
          depsList.add(item['department']['name'] as String);
        }
      }
    } else if (json['departments'] is List) {
      for (final d in json['departments']) {
        if (d is String) depsList.add(d);
      }
    }

    return CurrentUser(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      roles: rolesList,
      departments: depsList,
    );
  }

  /// Flat serialization used by [UserSessionManager] for on-disk caching.
  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'roles': roles,
        'departments': departments,
      };
}

class AuthLoginResult {
  final bool success;
  final String? token;
  final CurrentUser? user;
  final String? errorMessage;

  const AuthLoginResult({
    required this.success,
    this.token,
    this.user,
    this.errorMessage,
  });
}

class UserApiService {
  UserApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).trim();

  final http.Client _client;
  final String _baseUrl;

  /// Authenticate against backend /api/mobile/auth/login
  Future<AuthLoginResult> login(String email, String password) async {
    if (_baseUrl.isEmpty) {
      return const AuthLoginResult(
        success: false,
        errorMessage: 'API base URL is not configured',
      );
    }

    final uri = Uri.parse(_baseUrl).resolve('/api/mobile/auth/login');
    final normalizedEmail = email.trim().toLowerCase();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final body = jsonEncode({
      'email': normalizedEmail,
      'password': password,
    });

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        return AuthLoginResult(
          success: false,
          errorMessage:
              'Backend Route Not Found (404) on $_baseUrl.\n\n'
              'The new mobile authentication endpoints have not been deployed to this server yet. '
              'Please deploy the backend to Vercel/production or configure API_BASE_URL.',
        );
      }

      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        return AuthLoginResult(
          success: false,
          errorMessage:
              'Server returned non-JSON response (HTTP ${response.statusCode}).',
        );
      }

      if (response.statusCode == 200 &&
          data is Map<String, dynamic> &&
          data['ok'] == true) {
        final token = data['token'] as String?;
        final userMap = data['user'] as Map<String, dynamic>?;
        if (token != null && userMap != null) {
          return AuthLoginResult(
            success: true,
            token: token,
            user: CurrentUser.fromJson(userMap),
          );
        }
      }

      final errorMsg = data is Map<String, dynamic>
          ? (data['error'] as String? ?? 'Invalid email or password')
          : 'Authentication failed (Code: ${response.statusCode})';

      return AuthLoginResult(
        success: false,
        errorMessage: errorMsg,
      );
    } catch (e) {
      return AuthLoginResult(
        success: false,
        errorMessage: 'Connection Exception: $e',
      );
    }
  }

  /// Fetch user profile using mobile Bearer token
  Future<CurrentUser?> fetchMe(String token) async {
    if (_baseUrl.isEmpty || token.isEmpty) {
      return null;
    }

    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    for (final path in ['/api/mobile/auth/me', '/api/me']) {
      try {
        final uri = Uri.parse(_baseUrl).resolve(path);
        final response = await _client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            final userJson = data['user'] is Map<String, dynamic>
                ? data['user'] as Map<String, dynamic>
                : data;
            return CurrentUser.fromJson(userJson);
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
