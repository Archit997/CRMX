import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/crmx_models.dart';
import 'mock_data.dart';

class CRMXRepository {
  CRMXRepository({
    http.Client? client,
    String? apiBaseUrl,
  })  : _client = client ?? http.Client(),
        _apiBaseUrl = apiBaseUrl ?? _defaultApiBaseUrl;

  static const _defaultApiBaseUrl = String.fromEnvironment(
    'CRMX_API_BASE',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  final http.Client _client;
  final String _apiBaseUrl;

  Future<UserSession> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_apiBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
      }),
    );
    if (response.statusCode != 200) {
      throw StateError('Login failed');
    }
    return UserSession.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DashboardData> loadDashboard() async {
    try {
      final results = await Future.wait([
        _getList('/statuses'),
        _getList('/clients'),
        _getList('/followups/today'),
        _getMap('/analytics/manager'),
        _getMap('/finance/receivables'),
      ]);

      final statuses = (results[0] as List<dynamic>)
          .map((item) => StatusMaster.fromJson(item as Map<String, dynamic>))
          .toList();
      final clients = (results[1] as List<dynamic>)
          .map((item) => ClientInfo.fromJson(item as Map<String, dynamic>))
          .toList();
      final followUps = (results[2] as List<dynamic>)
          .map((item) => FollowUpItem.fromJson(item as Map<String, dynamic>))
          .toList();
      final manager = ManagerSummary.fromJson(results[3] as Map<String, dynamic>);
      final financeJson = results[4] as Map<String, dynamic>;
      final receivables = ((financeJson['items'] ?? []) as List<dynamic>)
          .map((item) => FinanceReceivable.fromJson(item as Map<String, dynamic>))
          .toList();

      return DashboardData(
        statuses: statuses,
        clients: clients,
        followUps: followUps,
        manager: manager,
        receivables: receivables,
        financeMessage: financeJson['daily_message'] as String,
        source: DataSource.api,
      );
    } catch (_) {
      return MockData.dashboard;
    }
  }

  Future<ClientInfo> loadClient(int clientId) async {
    try {
      final json = await _getMap('/clients/$clientId');
      return ClientInfo.fromJson(json);
    } catch (_) {
      return MockData.dashboard.clients.first;
    }
  }

  Future<List<ClientInfo>> searchClients(String query) async {
    final response = await _client.get(
      Uri.parse('$_apiBaseUrl/clients/search?q=${Uri.encodeQueryComponent(query)}'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Search failed: ${response.statusCode}');
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => ClientInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ClientInfo> createClient(ClientDraft draft) async {
    final response = await _client.post(
      Uri.parse('$_apiBaseUrl/clients'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(draft.toJson()),
    );
    if (response.statusCode != 201) {
      throw StateError('Create client failed: ${response.statusCode}');
    }
    return ClientInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ClientInfo> updateClient(int clientId, ClientDraft draft) async {
    final response = await _client.patch(
      Uri.parse('$_apiBaseUrl/clients/$clientId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(draft.toJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Update client failed: ${response.statusCode}');
    }
    return ClientInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteClient(int clientId) async {
    final response = await _client.delete(Uri.parse('$_apiBaseUrl/clients/$clientId'));
    if (response.statusCode != 204) {
      throw StateError('Delete client failed: ${response.statusCode}');
    }
  }

  Future<void> createUpdate({
    required int clientId,
    required int newStatusNo,
    required String note,
    required String requestSubtype,
    required String followupDate,
    required String followupTime,
  }) async {
    final requestType = requestSubtype == 'None'
        ? 'None'
        : ['Quotation', 'Receipt', 'Delivery'].contains(requestSubtype)
            ? 'Document'
            : 'Information';

    await _client.post(
      Uri.parse('$_apiBaseUrl/clients/$clientId/updates'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'update_type': 'Follow-up',
        'new_status_no': newStatusNo,
        'request_type': requestType,
        'request_subtype': requestSubtype,
        'note': note,
        'followup_date': followupDate,
        'followup_time': followupTime,
        'created_by': 'Flutter POC',
      }),
    );
  }

  Future<List<dynamic>> _getList(String path) async {
    final response = await _client.get(Uri.parse('$_apiBaseUrl$path'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('GET $path failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    final response = await _client.get(Uri.parse('$_apiBaseUrl$path'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('GET $path failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

class DashboardData {
  const DashboardData({
    required this.statuses,
    required this.clients,
    required this.followUps,
    required this.manager,
    required this.receivables,
    required this.financeMessage,
    required this.source,
  });

  final List<StatusMaster> statuses;
  final List<ClientInfo> clients;
  final List<FollowUpItem> followUps;
  final ManagerSummary manager;
  final List<FinanceReceivable> receivables;
  final String financeMessage;
  final DataSource source;
}

enum DataSource { api, mock }
