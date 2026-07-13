import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../src/theme/app_theme.dart';
import '../domain/auth_user.dart';
import 'auth_controller.dart';

class ApprovalStatusScreen extends ConsumerWidget {
  const ApprovalStatusScreen({
    required this.user,
    required this.rejected,
    super.key,
  });

  final AuthUser user;
  final bool rejected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 34, 18, 24),
          children: [
            Icon(
              rejected ? Icons.block_rounded : Icons.hourglass_top_rounded,
              size: 78,
              color: rejected ? AppTheme.red : AppTheme.amber,
            ),
            const SizedBox(height: 22),
            Text(
              rejected ? 'Access rejected' : 'Waiting for manager approval',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              rejected
                  ? 'A manager rejected this signup request. Contact your company admin if this is incorrect.'
                  : 'Your mobile number is verified. A manager must approve your profile before you can use client data.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.muted,
                  height: 1.4,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 26),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row(label: 'Name', value: user.name ?? 'Not added'),
                    _Row(label: 'Phone', value: user.phone),
                    _Row(label: 'Role', value: user.role ?? 'Not selected'),
                    _Row(
                        label: 'Status',
                        value: user.approvalStatus ?? 'pending'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).checkSession(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check again'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}
