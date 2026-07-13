import '../../../services/api/api_client.dart';
import '../../../src/models/crmx_models.dart';

class ClientRepository {
  ClientRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Load dashboard data (statuses + clients)
  Future<DashboardData> loadDashboard() async {
    try {
      final results = await Future.wait([
        _apiClient.get('/master-status'),
        _apiClient.get('/client-list'),
      ]);

      final statuses = (results[0] as List<dynamic>)
          .map((item) => StatusMaster.fromJson(item as Map<String, dynamic>))
          .toList();

      final clientsRaw = results[1] as List<dynamic>;

      // Join status names with clients
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

        clientMap['status_name'] = status.statusName;
        clientMap['status_category'] = status.category;
        clientMap['deal_value'] = clientMap['deal_value'] ?? 0;

        return ClientInfo.fromJson(clientMap);
      }).toList();

      return DashboardData(
        statuses: statuses,
        clients: clients,
        followUps: [],
        manager: const ManagerSummary(
          calls: 0,
          whatsapp: 0,
          overdueFollowups: 0,
          quotedValue: 0,
          unloggedCalls: 0,
        ),
        receivables: [],
        financeMessage: '',
        source: DataSource.api,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Search clients
  Future<List<ClientInfo>> searchClients(String searchTerm) async {
    try {
      final response = await _apiClient.get('/client/$searchTerm');
      final clientsRaw = response as List<dynamic>;

      // Get statuses to join
      final statusesResponse = await _apiClient.get('/master-status');
      final statuses = (statusesResponse as List<dynamic>)
          .map((item) => StatusMaster.fromJson(item as Map<String, dynamic>))
          .toList();

      // Join status names
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
      rethrow;
    }
  }

  /// Create client
  Future<ClientInfo> createClient(Map<String, dynamic> clientData) async {
    try {
      final response = await _apiClient.post('/client', body: clientData);
      return ClientInfo.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Update client
  Future<Map<String, dynamic>> patchClient(
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _apiClient.patch('/client-list', body: updates);
      return response as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Change client status
  Future<Map<String, dynamic>> changeClientStatus({
    required int clientId,
    required int statusId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/change-client-status',
        body: {
          'client_id': clientId,
          'status_id': statusId,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete client
  Future<void> deleteClient(int clientId) async {
    try {
      await _apiClient.delete(
        '/client',
        queryParams: {'client_id': clientId.toString()},
      );
    } catch (e) {
      rethrow;
    }
  }
}
