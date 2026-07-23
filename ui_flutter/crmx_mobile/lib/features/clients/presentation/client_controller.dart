import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/cache/cache_service.dart';
import '../../../services/api/api_client.dart';
import '../../../src/models/crmx_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/client_repository.dart';

// Providers
final cacheServiceProvider = Provider<CacheService>((ref) {
  final authRepo = ref.read(authRepositoryProvider);
  final apiClient = ApiClient(
    tokenProvider: () => authRepo.getAccessToken(),
  );
  return CacheService(apiClient);
});

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final authRepo = ref.read(authRepositoryProvider);
  final apiClient = ApiClient(
    tokenProvider: () => authRepo.getAccessToken(),
  );
  final cacheService = ref.read(cacheServiceProvider);
  return ClientRepository(apiClient, cacheService);
});

/// Auto-dispose so the controller is torn down when ClientListScreen leaves
/// the tree (e.g. logout). That sets [StateNotifier.mounted] to false and
/// prevents in-flight [loadDashboard] calls from notifying a disposed Consumer.
final clientControllerProvider = StateNotifierProvider.autoDispose<
    ClientController, AsyncValue<DashboardData>>((ref) {
  return ClientController(ref.read(clientRepositoryProvider));
});

class ClientController extends StateNotifier<AsyncValue<DashboardData>> {
  ClientController(this._repository) : super(const AsyncValue.loading());

  final ClientRepository _repository;

  /// Load dashboard data
  Future<void> loadDashboard({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      state = const AsyncValue.loading();
    }
    final result = await AsyncValue.guard(() => _repository.loadDashboard());
    // Auth may have swapped the home screen while this request was in flight.
    if (!mounted) return;
    state = result;
  }

  /// Search clients
  Future<List<ClientInfo>> searchClients(String searchTerm) async {
    try {
      return await _repository.searchClients(searchTerm);
    } catch (e, stack) {
      throw AsyncValue.error(e, stack);
    }
  }

  /// Get assignable users for dropdowns
  Future<List<AssignableUser>> getAssignableUsers({
    bool forceRefresh = false,
  }) async {
    try {
      return await _repository.getAssignableUsers(
        forceRefresh: forceRefresh,
      );
    } catch (e, stack) {
      throw AsyncValue.error(e, stack);
    }
  }

  /// Create client
  Future<ClientInfo> createClient(Map<String, dynamic> clientData) async {
    try {
      final client = await _repository.createClient(clientData);
      await loadDashboard();
      return client;
    } catch (e, stack) {
      throw AsyncValue.error(e, stack);
    }
  }

  /// Update client
  Future<void> updateClient(Map<String, dynamic> updates) async {
    try {
      await _repository.patchClient(updates);
      await loadDashboard();
    } catch (e, stack) {
      throw AsyncValue.error(e, stack);
    }
  }

  /// Change client status
  Future<void> changeClientStatus({
    required int clientId,
    required int statusId,
  }) async {
    try {
      await _repository.changeClientStatus(
        clientId: clientId,
        statusId: statusId,
      );
      await loadDashboard();
    } catch (e, stack) {
      throw AsyncValue.error(e, stack);
    }
  }

  /// Delete client
  Future<void> deleteClient(int clientId) async {
    try {
      await _repository.deleteClient(clientId);
      await loadDashboard();
    } catch (e, stack) {
      throw AsyncValue.error(e, stack);
    }
  }
}
