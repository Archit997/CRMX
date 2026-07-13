import 'package:flutter/material.dart';

import '../data/crmx_repository.dart';
import '../models/crmx_models.dart';
import '../theme/app_theme.dart';
import 'widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.repository,
    required this.onSignedIn,
    super.key,
  });

  final CRMXRepository repository;
  final ValueChanged<UserSession> onSignedIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _identifierController = TextEditingController(text: 'rohit@crmx.local');
  final _passwordController = TextEditingController(text: 'sales123');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
          children: [
            const Text(
              'Company SIM + WhatsApp audit',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'CRMX',
              style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            const Text(
              'Daily follow-ups, client status, receivables, and call audit in one field-friendly mobile app.',
              style: TextStyle(
                  color: AppTheme.muted,
                  height: 1.35,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 26),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Sign in',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                    'Use phone or email. POC accounts are local dummy users.',
                    style: TextStyle(
                        color: AppTheme.muted,
                        height: 1.35,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _identifierController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Phone or email',
                      prefixIcon: Icon(Icons.account_circle_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_rounded),
                    ),
                    onSubmitted: (_) => _signIn(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                          color: AppTheme.red, fontWeight: FontWeight.w800),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _loading ? null : _signIn,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: const Text('Sign in'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('POC users',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  SizedBox(height: 10),
                  DetailRow(
                      label: 'Sales', value: 'rohit@crmx.local / sales123'),
                  DetailRow(
                      label: 'Manager', value: 'priya@crmx.local / manager123'),
                  DetailRow(
                      label: 'Finance',
                      value: 'finance@crmx.local / finance123'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await widget.repository.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );
      widget.onSignedIn(session);
    } catch (_) {
      setState(() {
        _error = 'Could not sign in with these details.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
