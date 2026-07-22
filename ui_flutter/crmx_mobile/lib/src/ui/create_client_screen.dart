import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cache/cache_service.dart';
import '../../core/errors.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/clients/presentation/client_controller.dart';
import '../models/crmx_models.dart';
import '../theme/app_theme.dart';

class CreateClientScreen extends ConsumerStatefulWidget {
  const CreateClientScreen({
    required this.statuses,
    required this.currentUser,
    super.key,
  });

  final List<StatusMaster> statuses;
  final AuthUser currentUser;

  @override
  ConsumerState<CreateClientScreen> createState() =>
      _CreateClientScreenState();
}

class _CreateClientScreenState extends ConsumerState<CreateClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _requirementController = TextEditingController();

  int _selectedStatusNo = 1; // Default: New Lead
  String _selectedPriority = 'Warm'; // Default: Warm
  String? _selectedAssignedTo; // UUID of selected user
  List<AssignableUser> _assignableUsers = [];
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadAssignableUsers();
  }

  Future<void> _loadAssignableUsers() async {
    try {
      final users = await ref
          .read(clientControllerProvider.notifier)
          .getAssignableUsers();

      if (mounted) {
        setState(() {
          _assignableUsers = users;
          _loadingUsers = false;
          // Default to current user if available
          _selectedAssignedTo = users
              .firstWhere(
                (u) => u.id == widget.currentUser.id,
                orElse: () => users.isNotEmpty ? users.first : const AssignableUser(id: '', name: ''),
              )
              .id;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingUsers = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getOperationError('load', e)),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _companyNameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _requirementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Client'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Client Name (Required)
            TextFormField(
              controller: _clientNameController,
              decoration: const InputDecoration(
                labelText: 'Client Name *',
                hintText: 'Enter client name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Client name is required';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Company Name (Required)
            TextFormField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                labelText: 'Company Name *',
                hintText: 'Enter company name',
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Company name is required';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Phone Number (Required)
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                hintText: 'Enter 10-digit phone number',
                prefixIcon: Icon(Icons.phone),
                prefix: Text('+91 '),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone number is required';
                }
                if (value.trim().length != 10) {
                  return 'Phone number must be 10 digits';
                }
                return null;
              },
              maxLength: 10,
            ),
            const SizedBox(height: 16),

            // WhatsApp Number (Optional)
            TextFormField(
              controller: _whatsappController,
              decoration: const InputDecoration(
                labelText: 'WhatsApp Number',
                hintText: 'Enter WhatsApp number (optional)',
                prefixIcon: Icon(Icons.chat),
                prefix: Text('+91 '),
              ),
              keyboardType: TextInputType.phone,
              maxLength: 10,
            ),
            const SizedBox(height: 16),

            // Email (Optional)
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter email (optional)',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // City (Optional)
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'City',
                hintText: 'Enter city (optional)',
                prefixIcon: Icon(Icons.location_city),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Assigned To Dropdown
            DropdownButtonFormField<String>(
              value: _selectedAssignedTo,
              decoration: const InputDecoration(
                labelText: 'Assigned To',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: _loadingUsers
                  ? []
                  : _assignableUsers.map((user) {
                      return DropdownMenuItem<String>(
                        value: user.id,
                        child: Text(
                          user.name,
                          style: TextStyle(
                            fontWeight: user.id == widget.currentUser.id
                                ? FontWeight.w900
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
              onChanged: _loadingUsers
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _selectedAssignedTo = value;
                        });
                      }
                    },
              hint: _loadingUsers
                  ? const Text('Loading users...')
                  : const Text('Select a user'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a user to assign';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Status Dropdown
            DropdownButtonFormField<int>(
              value: _selectedStatusNo,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.timeline),
              ),
              items: widget.statuses.map((status) {
                return DropdownMenuItem<int>(
                  value: status.statusNo,
                  child: Text('${status.statusNo}. ${status.statusName}'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedStatusNo = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Priority Dropdown
            DropdownButtonFormField<String>(
              value: _selectedPriority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                prefixIcon: Icon(Icons.flag),
              ),
              items: const [
                DropdownMenuItem(value: 'Hot', child: Text('🔴 Hot')),
                DropdownMenuItem(value: 'Warm', child: Text('🟡 Warm')),
                DropdownMenuItem(value: 'Cold', child: Text('🔵 Cold')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPriority = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Requirement Summary (Optional, larger text box)
            TextFormField(
              controller: _requirementController,
              decoration: const InputDecoration(
                labelText: 'Requirement Summary',
                hintText: 'Describe the client requirements (optional)',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Submit Button
            FilledButton.icon(
              onPressed: _submitForm,
              icon: const Icon(Icons.save),
              label: const Text('Create Client'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),

            // Cancel Button
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAssignedTo == null || _selectedAssignedTo!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a user to assign'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    // Get created_date as today's date
    final now = DateTime.now();
    final createdDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // WhatsApp defaults to phone if not provided
    final whatsapp = _whatsappController.text.trim().isEmpty
        ? _phoneController.text.trim()
        : _whatsappController.text.trim();

    final clientData = {
      'client_name': _clientNameController.text.trim(),
      'company_name': _companyNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'whatsapp_number': whatsapp,
      'email': _emailController.text.trim(),
      'city': _cityController.text.trim(),
      'assigned_to': _selectedAssignedTo!,
      'current_status_no': _selectedStatusNo,
      'requirement_summary': _requirementController.text.trim(),
      'priority': _selectedPriority,
      'created_date': createdDate,
    };

    // Return the data to the previous screen
    Navigator.pop(context, clientData);
  }
}
