import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'procurement_models.dart';

class ProcurementApiService {
  ProcurementApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).trim();

  final http.Client _client;
  final String _baseUrl;

  Map<String, String> _headers(String token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Fetch procurement dashboard KPI metrics, user wallet overview, and recent items.
  Future<ProcurementDashboardData?> fetchDashboard(String token) async {
    if (_baseUrl.isEmpty || token.isEmpty) return null;

    final uri = Uri.parse(_baseUrl).resolve('/api/mobile/procurement/dashboard');

    try {
      final res = await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is Map<String, dynamic> && json['ok'] == true && json['data'] != null) {
          return ProcurementDashboardData.fromJson(
              json['data'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetch material requisitions list with optional status and search filter.
  Future<List<MaterialRequisitionSummary>> fetchRequisitions(
    String token, {
    String? status,
    String? search,
  }) async {
    if (_baseUrl.isEmpty || token.isEmpty) return [];

    final queryParams = <String, String>{};
    if (status != null && status != 'ALL') queryParams['status'] = status;
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final baseUri = Uri.parse(_baseUrl).resolve('/api/mobile/procurement/requisitions');
    final uri = queryParams.isEmpty
        ? baseUri
        : baseUri.replace(queryParameters: queryParams);

    try {
      final res = await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is Map<String, dynamic> && json['ok'] == true && json['data'] is List) {
          return (json['data'] as List<dynamic>)
              .map((e) => MaterialRequisitionSummary.fromJson(
                  e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Fetch detailed requisition with items and active suppliers.
  Future<({MaterialRequisitionDetail requisition, List<SupplierModel> suppliers})?>
      fetchRequisitionDetail(String token, String id) async {
    if (_baseUrl.isEmpty || token.isEmpty || id.isEmpty) return null;

    final uri = Uri.parse(_baseUrl).resolve('/api/mobile/procurement/requisitions/$id');

    try {
      final res = await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is Map<String, dynamic> && json['ok'] == true && json['data'] != null) {
          final data = json['data'] as Map<String, dynamic>;
          final reqJson = data['requisition'] as Map<String, dynamic>;
          final supList = (data['suppliers'] as List<dynamic>?)
                  ?.map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];

          return (
            requisition: MaterialRequisitionDetail.fromJson(reqJson),
            suppliers: supList,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Update requisition status: 'SUBMITTED' | 'IN_PROCUREMENT' | 'FULFILLED'
  Future<bool> updateRequisitionStatus(
    String token,
    String id,
    String status,
  ) async {
    if (_baseUrl.isEmpty || token.isEmpty || id.isEmpty) return false;

    final uri = Uri.parse(_baseUrl).resolve('/api/mobile/procurement/requisitions/$id');

    try {
      final res = await _client
          .patch(
            uri,
            headers: _headers(token),
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return json is Map<String, dynamic> && json['ok'] == true;
      }
    } catch (_) {}
    return false;
  }

  /// Log item purchase for a requisition line item.
  Future<bool> logItemPurchase({
    required String token,
    required String requisitionId,
    required String itemId,
    String? supplierId,
    String? supplierName,
    required double unitRate,
    required double purchasedQty,
    String? notes,
    String? receiptUrl,
  }) async {
    if (_baseUrl.isEmpty || token.isEmpty) return false;

    final uri = Uri.parse(_baseUrl).resolve(
      '/api/mobile/procurement/requisitions/$requisitionId/item-purchase',
    );

    final body = jsonEncode({
      'itemId': itemId,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'unitRate': unitRate,
      'purchasedQty': purchasedQty,
      'notes': notes,
      'receiptUrl': receiptUrl,
      'isBought': true,
    });

    try {
      final res = await _client
          .post(uri, headers: _headers(token), body: body)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return json is Map<String, dynamic> && json['ok'] == true;
      }
    } catch (_) {}
    return false;
  }

  /// Fetch full wallet details and transactions.
  Future<ProcurementWalletData?> fetchWallet(String token) async {
    if (_baseUrl.isEmpty || token.isEmpty) return null;

    final uri = Uri.parse(_baseUrl).resolve('/api/mobile/procurement/wallet');

    try {
      final res = await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is Map<String, dynamic> && json['ok'] == true && json['data'] != null) {
          return ProcurementWalletData.fromJson(
              json['data'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Record a procurement expense.
  Future<({bool success, String? error})> logExpense({
    required String token,
    required double amount,
    double charge = 0,
    String paymentMethod = 'CASH',
    String paidFrom = 'COMPANY_ADVANCE', // COMPANY_ADVANCE | PERSONAL_POCKET
    String category = 'RAW_MATERIALS',
    required String particular,
    String? voucherNo,
    String? receiptUrl,
    String? leadId,
  }) async {
    if (_baseUrl.isEmpty || token.isEmpty) {
      return (success: false, error: 'Not authenticated or URL missing');
    }

    final uri = Uri.parse(_baseUrl).resolve('/api/mobile/procurement/wallet');

    final body = jsonEncode({
      'amount': amount,
      'charge': charge,
      'paymentMethod': paymentMethod,
      'paidFrom': paidFrom,
      'category': category,
      'particular': particular,
      'voucherNo': voucherNo,
      'receiptUrl': receiptUrl,
      'leadId': leadId,
    });

    try {
      final res = await _client
          .post(uri, headers: _headers(token), body: body)
          .timeout(const Duration(seconds: 15));

      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && json is Map<String, dynamic> && json['ok'] == true) {
        return (success: true, error: null);
      }

      final msg = json is Map<String, dynamic>
          ? (json['error'] as String? ?? 'Failed to record expense')
          : 'Server error (${res.statusCode})';
      return (success: false, error: msg);
    } catch (e) {
      return (
        success: false,
        error: 'Network error: Please check your connection and try again.'
      );
    }
  }

  /// Fetch active suppliers with optional category and search filter.
  Future<List<SupplierModel>> fetchSuppliers(
    String token, {
    String? category,
    String? search,
  }) async {
    if (_baseUrl.isEmpty || token.isEmpty) return [];

    final queryParams = <String, String>{};
    if (category != null && category != 'ALL') queryParams['category'] = category;
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final baseUri = Uri.parse(_baseUrl).resolve('/api/mobile/procurement/suppliers');
    final uri = queryParams.isEmpty
        ? baseUri
        : baseUri.replace(queryParameters: queryParams);

    try {
      final res = await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is Map<String, dynamic> && json['ok'] == true && json['data'] is List) {
          return (json['data'] as List<dynamic>)
              .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
