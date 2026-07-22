import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/pending_users_screen.dart';
import '../../features/clients/presentation/client_controller.dart';
import '../models/crmx_models.dart';
import '../theme/app_theme.dart';
import 'client_detail_screen.dart';
import 'create_client_screen.dart';

class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({
    required this.currentUser,
    super.key,
  });

  final AuthUser currentUser;

  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends ConsumerState<ClientListScreen> {
  final _searchController = TextEditingController();
  List<ClientInfo> _filteredClients = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Load clients on screen init
    Future.microtask(() {
      ref.read(clientControllerProvider.notifier).loadDashboard();
      // Start auto-refresh to pick up changes from detail screen
      ref.read(clientControllerProvider.notifier).startAutoRefresh();
    });
  }

  @override
  void dispose() {
    // Stop auto-refresh when leaving the screen
    ref.read(clientControllerProvider.notifier).stopAutoRefresh();
    _searchController.dispose();
    super.dispose();
  }

  void _filterClients(List<ClientInfo> allClients, String query) {
    final searchTerm = query.toLowerCase().trim();

    if (searchTerm.isEmpty) {
      setState(() {
        _filteredClients = allClients;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _filteredClients = allClients.where((client) {
        return client.clientName.toLowerCase().contains(searchTerm) ||
            client.companyName.toLowerCase().contains(searchTerm) ||
            client.phone.contains(searchTerm) ||
            client.statusName.toLowerCase().contains(searchTerm);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(clientControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CRMX',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            Text(
              'Client Management',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
        actions: [
          if (_canVerifyUsers)
            IconButton(
              icon: const Icon(Icons.verified_user_rounded),
              onPressed: _openPendingApprovals,
              tooltip: 'Pending user approvals',
            ),
          // API status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: dashboardState.hasValue
                      ? AppTheme.green.withOpacity(0.15)
                      : AppTheme.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      dashboardState.hasValue
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      size: 16,
                      color: dashboardState.hasValue
                          ? AppTheme.green
                          : AppTheme.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dashboardState.hasValue ? 'API' : 'Loading',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: dashboardState.hasValue
                            ? AppTheme.green
                            : AppTheme.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Create client button
          IconButton(
            onPressed: () => _navigateToCreateClient(dashboardState),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppTheme.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 20,
              ),
            ),
            tooltip: 'Create New Client',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(clientControllerProvider.notifier).loadDashboard();
            },
            tooltip: 'Refresh',
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, company, phone, or status',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          dashboardState.whenData((data) {
                            _filterClients(data.clients, '');
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                dashboardState.whenData((data) {
                  _filterClients(data.clients, value);
                });
              },
            ),
          ),

          // Client list
          Expanded(
            child: dashboardState.when(
              data: (data) {
                final clients = _isSearching ? _filteredClients : data.clients;

                if (clients.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(clientControllerProvider.notifier)
                        .loadDashboard();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: clients.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final client = clients[index];
                      return ClientListCard(
                        client: client,
                        onTap: () => _navigateToDetail(client, data.statuses),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canVerifyUsers =>
      widget.currentUser.role == 'MANAGER' ||
      widget.currentUser.role == 'ADMIN';

  void _openPendingApprovals() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PendingUsersScreen(
          authRepository: ref.read(authRepositoryProvider),
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 64,
              color: AppTheme.muted,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No clients found'
                  : 'No clients match your search',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.red,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                ref.read(clientControllerProvider.notifier).loadDashboard();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToDetail(
    ClientInfo client,
    List<StatusMaster> statuses,
  ) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ClientDetailScreen(
          client: client,
          statuses: statuses,
          repository: ref.read(clientRepositoryProvider),
        ),
      ),
    );

    // Refresh dashboard when returning from detail screen
    // (changes might have been made that need to be reflected)
    if (mounted) {
      ref.read(clientControllerProvider.notifier).loadDashboard(silent: true);
    }
  }

  Future<void> _navigateToCreateClient(
    AsyncValue<DashboardData> dashboardState,
  ) async {
    await dashboardState.whenOrNull(
      data: (data) async {
        if (data.statuses.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait for data to load'),
              backgroundColor: AppTheme.amber,
            ),
          );
          return;
        }

        final clientData = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => CreateClientScreen(
              statuses: data.statuses,
              currentUser: widget.currentUser,
            ),
          ),
        );

        if (clientData != null && mounted) {
          _createClient(clientData);
        }
      },
    );
  }

  Future<void> _createClient(Map<String, dynamic> clientData) async {
    try {
      await ref
          .read(clientControllerProvider.notifier)
          .createClient(clientData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Client "${clientData['client_name']}" created successfully'),
          backgroundColor: AppTheme.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getOperationError('create', e)),
          backgroundColor: AppTheme.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

class ClientListCard extends StatelessWidget {
  const ClientListCard({
    required this.client,
    required this.onTap,
    super.key,
  });

  final ClientInfo client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.clientName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (client.companyName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            client.companyName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _priorityColor(client.priority).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      client.priority,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _priorityColor(client.priority),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: AppTheme.muted),
                  const SizedBox(width: 8),
                  Text(
                    '+91 ${client.phone}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        client.statusName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.green,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 16, color: AppTheme.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Assigned to: ${client.assignedToName}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _priorityColor(String priority) {
    return switch (priority) {
      'Hot' => AppTheme.red,
      'Cold' => AppTheme.blue,
      _ => AppTheme.amber,
    };
  }
}
