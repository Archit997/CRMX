import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../src/theme/app_theme.dart';
import '../domain/auth_state.dart';
import '../domain/auth_user.dart';
import 'auth_controller.dart';

enum _SignupPath { createCompany, joinCompany }

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({
    required this.user,
    this.initialError,
    this.createOnly = false,
    super.key,
  });

  final AuthUser user;
  final String? initialError;
  final bool createOnly;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _organizationController = TextEditingController();
  final _organizationCodeController = TextEditingController();
  final _contactController = TextEditingController();
  _SignupPath _path = _SignupPath.joinCompany;
  String _role = 'EMPLOYEE';

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.name ?? '';
    if (widget.createOnly) {
      _path = _SignupPath.createCompany;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _organizationController.dispose();
    _organizationCodeController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final loading = authState is Authenticating;
    final isCreating = _path == _SignupPath.createCompany;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.createOnly ? 'Company setup' : 'Create account'),
        actions: [
          IconButton(
            onPressed: loading
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Use another number',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Icon(
                    isCreating ? Icons.business_rounded : Icons.badge_rounded,
                    size: 42,
                    color: AppTheme.green,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isCreating ? 'Set up your company' : 'Join your team',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    isCreating
                        ? 'You will become the first admin for this CRMX workspace.'
                        : 'Enter the company code shared by your admin.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!widget.createOnly) ...[
                    SegmentedButton<_SignupPath>(
                      segments: const [
                        ButtonSegment(
                          value: _SignupPath.joinCompany,
                          icon: Icon(Icons.group_add_rounded),
                          label: Text('Join company'),
                        ),
                        ButtonSegment(
                          value: _SignupPath.createCompany,
                          icon: Icon(Icons.add_business_rounded),
                          label: Text('Set up company'),
                        ),
                      ],
                      selected: {_path},
                      onSelectionChanged: loading
                          ? null
                          : (selection) {
                              setState(() => _path = selection.first);
                              _formKey.currentState?.reset();
                            },
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (widget.initialError != null) ...[
                    _MessageBanner(
                      message: widget.initialError!,
                      isError: true,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Your full name',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    validator: _required('Enter your full name'),
                    enabled: !loading,
                  ),
                  const SizedBox(height: 14),
                  if (isCreating)
                    TextFormField(
                      controller: _organizationController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Company name',
                        hintText: 'Sharma Steel Works',
                        prefixIcon: Icon(Icons.factory_rounded),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().length < 2) {
                          return 'Enter your company name';
                        }
                        return null;
                      },
                      enabled: !loading,
                    )
                  else ...[
                    TextFormField(
                      controller: _organizationCodeController,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Company code',
                        hintText: 'SHARMAST-4A2F',
                        prefixIcon: Icon(Icons.key_rounded),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().length < 3) {
                          return 'Enter the code shared by your admin';
                        }
                        return null;
                      },
                      enabled: !loading,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: const InputDecoration(
                        labelText: 'Work role',
                        prefixIcon: Icon(Icons.work_rounded),
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
                      onChanged: loading
                          ? null
                          : (value) => setState(() => _role = value ?? _role),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(
                      labelText: 'Alternate contact or note (optional)',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    minLines: 2,
                    maxLines: 3,
                    enabled: !loading,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: loading ? null : _submit,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isCreating
                                ? Icons.arrow_forward_rounded
                                : Icons.send_rounded,
                          ),
                    label: Text(
                      isCreating
                          ? 'Create company workspace'
                          : 'Send request to admin',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Verified mobile: ${widget.user.phone}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  FormFieldValidator<String> _required(String message) {
    return (value) => (value ?? '').trim().isEmpty ? message : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final contact = _contactController.text.trim();
    if (_path == _SignupPath.createCompany) {
      await ref.read(authControllerProvider.notifier).bootstrapOrganization(
            user: widget.user,
            organizationName: _organizationController.text.trim(),
            adminName: _nameController.text.trim(),
            contact: contact.isEmpty ? null : contact,
          );
      return;
    }

    await ref.read(authControllerProvider.notifier).requestSignup(
          user: widget.user,
          name: _nameController.text.trim(),
          role: _role,
          organizationCode:
              _organizationCodeController.text.trim().toUpperCase(),
          contact: contact.isEmpty ? null : contact,
        );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.red : AppTheme.green;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
