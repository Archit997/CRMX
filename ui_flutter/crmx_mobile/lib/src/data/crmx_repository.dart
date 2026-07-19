import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/crmx_models.dart';

class CRMXRepository {
  CRMXRepository({
    http.Client? client,
    String? apiBaseUrl,
  })  : _client = client ?? http.Client(),
        _apiBaseUrl = apiBaseUrl ?? _defaultApiBaseUrl;

  static const _defaultApiBaseUrl = String.fromEnvironment(
    'CRMX_API_BASE',
    // Remove /api suffix - Postgres endpoints don't use it
    defaultValue: 'http://127.0.0.1:8000',
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
    return UserSession.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DashboardData> loadDashboard() async {
    // Only call Postgres endpoints that exist
    final results = await Future.wait([
      _getList('/master-status'), // Postgres statuses ✅
      _getList('/client-list'), // Postgres clients ✅
      // Removed: followups, analytics, finance - not implemented in Postgres yet
    ]);

    final statuses = results[0]
        .map((item) => StatusMaster.fromJson(item as Map<String, dynamic>))
        .toList();

    final clientsRaw = results[1];

    // Join status names with clients (Postgres endpoint doesn't include status_name)
    final clients = clientsRaw.map((item) {
      final clientMap = item as Map<String, dynamic>;
      final statusNo = clientMap['current_status_no'] as int;
      final status = statuses.firstWhere(
        (s) => s.statusNo == statusNo,
        orElse: () => StatusMaster(
          statusNo: statusNo,
          statusName: 'Unknown',
          category: '',
          description: '',
        ),
      );

      // Add missing fields for compatibility
      clientMap['status_name'] = status.statusName;
      clientMap['status_category'] = status.category;
      clientMap['deal_value'] = clientMap['deal_value'] ?? 0;

      return ClientInfo.fromJson(clientMap);
    }).toList();

    print('✅ Successfully loaded data from Postgres API: $_apiBaseUrl');
    print('   Loaded ${clients.length} clients from /client-list');
    print('   Loaded ${statuses.length} statuses from /master-status');

    return DashboardData(
      statuses: statuses,
      clients: clients,
      followUps: [], // Empty - not implemented yet
      manager: const ManagerSummary(
        calls: 0,
        whatsapp: 0,
        overdueFollowups: 0,
        quotedValue: 0,
        unloggedCalls: 0,
      ), // Empty - not implemented yet
      receivables: [], // Empty - not implemented yet
      financeMessage: '', // Empty - not implemented yet
      source: DataSource.api,
    );
  }

  Future<ClientInfo> loadClient(int clientId) async {
    final json = await _getMap('/clients/$clientId');
    return ClientInfo.fromJson(json);
  }

  Future<List<ClientInfo>> searchClients(String query) async {
    try {
      // Use Postgres search endpoint
      final response = await _client.get(
        Uri.parse('$_apiBaseUrl/client/${Uri.encodeComponent(query)}'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Search failed: ${response.statusCode}');
      }

      final clientsRaw = jsonDecode(response.body) as List<dynamic>;

      // Get statuses to join with clients
      final statusesResponse =
          await _client.get(Uri.parse('$_apiBaseUrl/master-status'));
      final statuses = (jsonDecode(statusesResponse.body) as List<dynamic>)
          .map((item) => StatusMaster.fromJson(item as Map<String, dynamic>))
          .toList();

      // Join status names with clients
      return clientsRaw.map((item) {
        final clientMap = item as Map<String, dynamic>;
        final statusNo = clientMap['current_status_no'] as int;
        final status = statuses.firstWhere(
          (s) => s.statusNo == statusNo,
          orElse: () => StatusMaster(
            statusNo: statusNo,
            statusName: 'Unknown',
            category: '',
            description: '',
          ),
        );

        clientMap['status_name'] = status.statusName;
        clientMap['status_category'] = status.category;
        clientMap['deal_value'] = clientMap['deal_value'] ?? 0;

        return ClientInfo.fromJson(clientMap);
      }).toList();
    } catch (e) {
      // Fallback to local filtering if API search fails
      throw StateError('Search failed: $e');
    }
  }

  Future<ClientInfo> createClient(Map<String, dynamic> clientData) async {
    print('📤 Creating client with data: $clientData');
    final response = await _client.post(
      Uri.parse('$_apiBaseUrl/client'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(clientData),
    );

    if (response.statusCode != 201) {
      print('❌ Create client failed: ${response.statusCode} ${response.body}');
      throw StateError(
          'Create client failed: ${response.statusCode} ${response.body}');
    }

    print('✅ Client created successfully');
    final clientInfo =
        ClientInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    return clientInfo;
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
    return ClientInfo.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
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

  Future<Map<String, dynamic>> changeClientStatus({
    required int clientId,
    required int statusId,
  }) async {
    final response = await _client.post(
      Uri.parse('$_apiBaseUrl/change-client-status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'client_id': clientId,
        'status_id': statusId,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'Change status failed: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patchClient(Map<String, dynamic> updates) async {
    print('📤 Patching client with data: $updates');
    final response = await _client.patch(
      Uri.parse('$_apiBaseUrl/client-list'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('❌ Patch client failed: ${response.statusCode} ${response.body}');
      throw StateError(
          'Patch client failed: ${response.statusCode} ${response.body}');
    }

    print('✅ Client patched successfully');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteClient(int clientId) async {
    print('📤 Deleting client: $clientId');
    final response = await _client.delete(
      Uri.parse('$_apiBaseUrl/client?client_id=$clientId'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('❌ Delete client failed: ${response.statusCode} ${response.body}');
      throw StateError(
          'Delete client failed: ${response.statusCode} ${response.body}');
    }

    print('✅ Client deleted successfully');
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
