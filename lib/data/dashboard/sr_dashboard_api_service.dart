import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import 'sr_dashboard_models.dart';

class SrDashboardApiService {
  final String _baseUrl = AppConfig.apiBaseUrl;
  final http.Client _client = http.Client();

  Future<SrDashboardData?> fetchDashboardData(String token) async {
    final uri = Uri.parse(_baseUrl).resolve('/api/sr-dashboard');

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return SrDashboardData.fromJson(body['data']);
        } else {
          final errorMsg = body['error'] ?? 'Unknown error from server';
          throw Exception(errorMsg);
        }
      } else {
        String errorMsg = 'HTTP ${response.statusCode}';
        try {
          final body = jsonDecode(response.body);
          if (body['error'] != null) errorMsg = body['error'];
        } catch (_) {
          errorMsg = 'HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}';
        }
        throw Exception(errorMsg);
      }
    } catch (_) {
      rethrow;
    }
  }
}
