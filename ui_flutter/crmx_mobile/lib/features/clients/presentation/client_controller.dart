import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api/api_client.dart';
import '../../../src/models/crmx_models.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/client_repository.dart';

// Providers
final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final authRepo = ref.read(authRepositoryProvider);
  final apiClient = ApiClient(
    tokenProvider: () => authRepo.getAccessToken(),
  );
  return ClientRepository(apiClient);
});

final clientControllerProvider =
    StateNotifierProvider<ClientController, AsyncValue<DashboardData>>((ref) {
  return ClientController(ref.read(clientRepositoryProvider));
});

class ClientController extends StateNotifier<AsyncValue<DashboardData>> {
  ClientController(this._repository) : super(const AsyncValue.loading());

  final ClientRepository _repository;

  /// Load dashboard data
  Future<void> loadDashboard() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.loadDashboard());
  }

  /// Search clients
  Future<List<ClientInfo>> searchClients(String searchTerm) async {
    try {
      return await _repository.searchClients(searchTerm);
    } catch (e, stack) {
      throw AsyncValue.error(e, stack);
    }
  }

  /// Create client
  Future<ClientInfo> createClient(Map<String, dynamic> clientData) async {
    try {
      final client = await _repository.createClient(clientData);
      // Reload dashboard to show new client
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
      // Reload dashboard to show updated client
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
      // Reload dashboard to show updated status
      await loadDashboard();
    } catch (e, stack) {
      throw AsyncValue.error(e, stack);
    }
  }

  /// Delete client
  Future<void> deleteClient(int clientId) async {
    try {
      await _repository.deleteClient(clientId);
      // Reload dashboard to remove deleted client
      await loadDashboard();
    } catch (e, stack) {
      throw AsyncValue.error(e, stack);
    }
  }
}
