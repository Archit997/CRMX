import '../../../core/cache/cache_service.dart';
import '../../../services/api/api_client.dart';
import '../../../src/models/crmx_models.dart';

class ClientRepository {
  ClientRepository(this._apiClient, this._cacheService);

  final ApiClient _apiClient;
  final CacheService _cacheService;

  /// Load dashboard data (statuses + clients)
  ///
  /// Now uses caching for statuses and gets client data with
  /// assigned_to_name and current_status_name from the API directly.
  Future<DashboardData> loadDashboard() async {
    try {
      final results = await Future.wait([
        _cacheService.getStatusMaster(), // Cached status master
        _apiClient.get('/client-list'),  // Clients with names included
      ]);

      final statuses = results[0] as List<StatusMaster>;
      final clientsRaw = results[1] as List<dynamic>;

      // Parse clients - no need to manually join status names anymore!
      // The API now returns assigned_to_name and current_status_name
      final clients = clientsRaw
          .map((item) => ClientInfo.fromJson(item as Map<String, dynamic>))
          .toList();

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
  ///
  /// Now simplified - API returns all needed data including names
  Future<List<ClientInfo>> searchClients(String searchTerm) async {
    try {
      final response = await _apiClient.get('/client/$searchTerm');
      final clientsRaw = response as List<dynamic>;

      // Parse clients - API includes assigned_to_name and current_status_name
      return clientsRaw
          .map((item) => ClientInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get assignable users (for dropdowns)
  Future<List<AssignableUser>> getAssignableUsers({
    bool forceRefresh = false,
  }) async {
    return _cacheService.getAssignableUsers(forceRefresh: forceRefresh);
  }

  /// Create client
  Future<ClientInfo> createClient(Map<String, dynamic> clientData) async {
    try {
      final response = await _apiClient.post('/client', body: clientData);
      
      // Invalidate assignable users cache in case a new user was involved
      _cacheService.invalidateAssignableUsers();
      
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
