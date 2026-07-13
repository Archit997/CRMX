import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../src/theme/app_theme.dart';
import '../domain/auth_state.dart';
import '../domain/auth_user.dart';
import 'auth_controller.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({
    required this.user,
    super.key,
  });

  final AuthUser user;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  String _role = 'sales';

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final loading = authState is Authenticating;

    return Scaffold(
      appBar: AppBar(title: const Text('Complete signup')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text(
                'Request access',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Your mobile ${widget.user.phone} is verified. Add your details so a manager can approve your CRMX access.',
                style: const TextStyle(
                    color: AppTheme.muted,
                    height: 1.35,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'Role requested',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'sales', child: Text('Sales')),
                  DropdownMenuItem(value: 'finance', child: Text('Finance')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                ],
                onChanged: loading
                    ? null
                    : (value) => setState(() => _role = value ?? _role),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Alternate contact / note',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: loading ? null : _submit,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.how_to_reg_rounded),
                label: const Text('Send for approval'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: loading
                    ? null
                    : () => ref.read(authControllerProvider.notifier).signOut(),
                child: const Text('Use another number'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).requestSignup(
          user: widget.user,
          name: _nameController.text.trim(),
          role: _role,
          contact: _contactController.text.trim().isEmpty
              ? null
              : _contactController.text.trim(),
        );
  }
}
