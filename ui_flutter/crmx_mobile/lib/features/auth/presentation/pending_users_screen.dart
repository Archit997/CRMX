import 'package:flutter/material.dart';
import '../../../services/api/api_client.dart';
import '../../../src/theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../data/user_management_repository.dart';
import '../domain/auth_user.dart';

class PendingUsersScreen extends StatefulWidget {
  const PendingUsersScreen({
    required this.authRepository,
    required this.currentUser,
    super.key,
  });

  final AuthRepository authRepository;
  final AuthUser currentUser;

  @override
  State<PendingUsersScreen> createState() => _PendingUsersScreenState();
}

class _PendingUsersScreenState extends State<PendingUsersScreen> {
  late final UserManagementRepository _repository;
  late Future<List<AppUserProfile>> _future;

  @override
  void initState() {
    super.initState();
    _repository = UserManagementRepository(
      ApiClient(tokenProvider: widget.authRepository.getAccessToken),
    );
    _future = _repository.listPendingUsers();
  }

  void _reload() {
    setState(() {
      _future = _repository.listPendingUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending approvals'),
        actions: [
          IconButton(
              onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: FutureBuilder<List<AppUserProfile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Failed to load users: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(
              child: Text(
                'No pending signup requests',
                style: TextStyle(
                    color: AppTheme.muted, fontWeight: FontWeight.w800),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _PendingUserCard(
              user: users[index],
              onApprove: () => _verify(users[index], 'approved'),
              onReject: () => _verify(users[index], 'rejected'),
            ),
          );
        },
      ),
    );
  }

  Future<void> _verify(AppUserProfile user, String approvalStatus) async {
    try {
      await _repository.verifyUser(
        userId: user.id,
        approvalStatus: approvalStatus,
        verifiedBy: widget.currentUser.id,
        rejectionReason:
            approvalStatus == 'rejected' ? 'Rejected by manager' : null,
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update ${user.name}: $error')),
      );
    }
  }
}

class _PendingUserCard extends StatelessWidget {
  const _PendingUserCard({
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

  final AppUserProfile user;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(user.phone,
                style: const TextStyle(
                    color: AppTheme.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Requested role: ${user.role}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            if (user.contact?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(user.contact!,
                  style: const TextStyle(color: AppTheme.muted)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
