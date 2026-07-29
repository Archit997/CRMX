import 'package:flutter/material.dart';

import '../../../core/errors.dart';
import '../../../services/api/api_client.dart';
import '../../../src/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_user.dart';
import '../data/admin_repository.dart';

enum _AdminView { pending, team, activity }

class AdminWorkspaceScreen extends StatefulWidget {
  const AdminWorkspaceScreen({
    required this.authRepository,
    required this.currentUser,
    super.key,
  });

  final AuthRepository authRepository;
  final AuthUser currentUser;

  @override
  State<AdminWorkspaceScreen> createState() => _AdminWorkspaceScreenState();
}

class _AdminWorkspaceScreenState extends State<AdminWorkspaceScreen> {
  late final AdminRepository _repository;
  late Future<_AdminData> _future;
  _AdminView _view = _AdminView.pending;

  @override
  void initState() {
    super.initState();
    _repository = AdminRepository(
      ApiClient(
        tokenProvider: widget.authRepository.getAccessToken,
        refreshTokenProvider: widget.authRepository.getRefreshToken,
        tokenUpdater: widget.authRepository.updateTokens,
      ),
    );
    _future = _load();
  }

  Future<_AdminData> _load() async {
    final results = await Future.wait([
      _repository.getOrganization(),
      _repository.listUsers(approvalStatus: 'pending'),
      _repository.listUsers(approvalStatus: 'approved'),
      _repository.listAuditEvents(),
    ]);
    return _AdminData(
      organization: results[0] as OrganizationSummary,
      pending: results[1] as List<ManagedUser>,
      approved: results[2] as List<ManagedUser>,
      auditEvents: results[3] as List<ManagedAuditEvent>,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<_AdminData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: ErrorHandler.getUserFriendlyMessage(snapshot.error!),
              onRetry: _reload,
            );
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _OrganizationHeader(
                  organization: data.organization,
                  memberCount: data.approved.length,
                  pendingCount: data.pending.length,
                  onRotateJoinCode: _rotateJoinCode,
                ),
                const SizedBox(height: 16),
                SegmentedButton<_AdminView>(
                  segments: [
                    ButtonSegment(
                      value: _AdminView.pending,
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text('Requests (${data.pending.length})'),
                    ),
                    ButtonSegment(
                      value: _AdminView.team,
                      icon: const Icon(Icons.groups_rounded),
                      label: Text('Team (${data.approved.length})'),
                    ),
                    const ButtonSegment(
                      value: _AdminView.activity,
                      icon: Icon(Icons.history_rounded),
                      label: Text('Activity'),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (value) =>
                      setState(() => _view = value.first),
                ),
                const SizedBox(height: 16),
                switch (_view) {
                  _AdminView.pending => _PendingList(
                      users: data.pending,
                      onApprove: (user) => _approve(user),
                      onReject: (user) => _reject(user),
                    ),
                  _AdminView.team => _TeamList(
                      users: data.approved,
                      currentUserId: widget.currentUser.id,
                      onRoleChanged: _changeRole,
                      onActiveChanged: _changeActive,
                      onDelete: _delete,
                    ),
                  _AdminView.activity => _AuditList(events: data.auditEvents),
                },
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _approve(ManagedUser user) async {
    await _runAction(
      () => _repository.verifyUser(
        userId: user.id,
        approvalStatus: 'approved',
      ),
      success: '${user.name} can now access CRMX',
    );
  }

  Future<void> _reject(ManagedUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject request?'),
        content: Text(
          '${user.name} will not be able to access this company workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      () => _repository.verifyUser(
        userId: user.id,
        approvalStatus: 'rejected',
        rejectionReason: 'Rejected by organization admin',
      ),
      success: 'Request rejected',
    );
  }

  Future<void> _changeRole(ManagedUser user, String role) async {
    await _runAction(
      () => _repository.updateAccess(userId: user.id, role: role),
      success: '${user.name} is now ${_roleLabel(role)}',
    );
  }

  Future<void> _changeActive(ManagedUser user, bool active) async {
    await _runAction(
      () => _repository.updateAccess(
        userId: user.id,
        isActive: active,
      ),
      success: active ? '${user.name} reactivated' : '${user.name} deactivated',
    );
  }

  Future<void> _delete(ManagedUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive user?'),
        content: Text(
          'Archive ${user.name}? Their history stays available for audit purposes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      () => _repository.deleteUser(user.id),
      success: '${user.name} archived',
    );
  }

  Future<void> _rotateJoinCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rotate company code?'),
        content: const Text(
          'The current code will stop working. Share the new code only with employees who should join this company.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rotate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      _repository.rotateJoinCode,
      success: 'Company code rotated',
    );
  }

  Future<void> _runAction(
    Future<Object?> Function() action, {
    required String success,
  }) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getUserFriendlyMessage(error)),
          backgroundColor: AppTheme.red,
        ),
      );
    }
  }
}

class _OrganizationHeader extends StatelessWidget {
  const _OrganizationHeader({
    required this.organization,
    required this.memberCount,
    required this.pendingCount,
    required this.onRotateJoinCode,
  });

  final OrganizationSummary organization;
  final int memberCount;
  final int pendingCount;
  final VoidCallback onRotateJoinCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4EF),
        border: Border.all(color: const Color(0xFFB8DCCF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.factory_rounded, color: AppTheme.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  organization.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'COMPANY CODE',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  organization.joinCode,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRotateJoinCode,
                icon: const Icon(Icons.autorenew_rounded),
                tooltip: 'Rotate company code',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$memberCount active people  •  $pendingCount requests',
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingList extends StatelessWidget {
  const _PendingList({
    required this.users,
    required this.onApprove,
    required this.onReject,
  });

  final List<ManagedUser> users;
  final ValueChanged<ManagedUser> onApprove;
  final ValueChanged<ManagedUser> onReject;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const _EmptyState(
        icon: Icons.task_alt_rounded,
        title: 'No pending requests',
        message: 'New employee requests will appear here.',
      );
    }
    return Column(
      children: [
        for (final user in users) ...[
          _UserSurface(
            user: user,
            footer: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onApprove(user),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => onReject(user),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Reject',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TeamList extends StatelessWidget {
  const _TeamList({
    required this.users,
    required this.currentUserId,
    required this.onRoleChanged,
    required this.onActiveChanged,
    required this.onDelete,
  });

  final List<ManagedUser> users;
  final String currentUserId;
  final void Function(ManagedUser, String) onRoleChanged;
  final void Function(ManagedUser, bool) onActiveChanged;
  final ValueChanged<ManagedUser> onDelete;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const _EmptyState(
        icon: Icons.groups_rounded,
        title: 'No team members yet',
        message: 'Approved employees will appear here.',
      );
    }
    return Column(
      children: [
        for (final user in users) ...[
          _UserSurface(
            user: user,
            footer: user.id == currentUserId
                ? const Text(
                    'This is your admin account',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              user.role == 'MANAGER' ? 'MANAGER' : 'EMPLOYEE',
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'EMPLOYEE',
                              child: Text('Employee'),
                            ),
                            DropdownMenuItem(
                              value: 'MANAGER',
                              child: Text('Manager'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null && value != user.role) {
                              onRoleChanged(user, value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Switch(
                        value: user.isActive,
                        onChanged: (value) => onActiveChanged(user, value),
                      ),
                      IconButton(
                        onPressed: user.isActive ? null : () => onDelete(user),
                        icon: const Icon(Icons.archive_outlined),
                        tooltip: 'Archive inactive user',
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _UserSurface extends StatelessWidget {
  const _UserSurface({
    required this.user,
    required this.footer,
  });

  final ManagedUser user;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.blue.withValues(alpha: 0.10),
                foregroundColor: AppTheme.blue,
                child: Text(
                  user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.phone,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (user.contact?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.contact!,
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                    ],
                  ],
                ),
              ),
              _RoleBadge(role: user.role),
            ],
          ),
          const SizedBox(height: 14),
          footer,
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _roleLabel(role),
        style: const TextStyle(
          color: AppTheme.green,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AuditList extends StatelessWidget {
  const _AuditList({required this.events});

  final List<ManagedAuditEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _EmptyState(
        icon: Icons.history_rounded,
        title: 'No recorded activity',
        message: 'Administrative changes will appear here.',
      );
    }
    return Column(
      children: [
        for (final event in events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(
              _auditActionLabel(event.action),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${event.entityType} ${event.entityId}\n${_formatAuditTime(event.createdAt)}',
            ),
            isThreeLine: true,
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppTheme.green),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppTheme.red,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminData {
  const _AdminData({
    required this.organization,
    required this.pending,
    required this.approved,
    required this.auditEvents,
  });

  final OrganizationSummary organization;
  final List<ManagedUser> pending;
  final List<ManagedUser> approved;
  final List<ManagedAuditEvent> auditEvents;
}

String _roleLabel(String role) {
  return switch (role) {
    'ADMIN' => 'Admin',
    'MANAGER' => 'Manager',
    _ => 'Employee',
  };
}

String _auditActionLabel(String action) {
  return action
      .split('.')
      .map((part) => part.isEmpty
          ? part
          : '${part[0].toUpperCase()}${part.substring(1).replaceAll('_', ' ')}')
      .join(' ');
}

String _formatAuditTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
