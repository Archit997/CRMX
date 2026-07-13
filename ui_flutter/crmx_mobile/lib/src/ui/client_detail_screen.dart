import 'package:flutter/material.dart';

import '../data/crmx_repository.dart';
import '../models/crmx_models.dart';
import '../theme/app_theme.dart';

class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({
    required this.client,
    required this.statuses,
    required this.repository,
    super.key,
  });

  final ClientInfo client;
  final List<StatusMaster> statuses;
  final CRMXRepository repository;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late int _currentStatusNo;
  bool _changingStatus = false;
  bool _isEditMode = false;
  bool _isSaving = false;

  // Controllers for editable fields
  late TextEditingController _clientNameController;
  late TextEditingController _companyNameController;
  late TextEditingController _phoneController;
  late TextEditingController _whatsappController;
  late TextEditingController _emailController;
  late TextEditingController _cityController;
  late TextEditingController _assignedToController;
  late TextEditingController _requirementController;
  late String _selectedPriority;

  @override
  void initState() {
    super.initState();
    _currentStatusNo = widget.client.currentStatusNo;
    _selectedPriority = widget.client.priority;

    // Initialize controllers with current values
    _clientNameController =
        TextEditingController(text: widget.client.clientName);
    _companyNameController =
        TextEditingController(text: widget.client.companyName);
    _phoneController = TextEditingController(text: widget.client.phone);
    _whatsappController =
        TextEditingController(text: widget.client.whatsappNumber);
    _emailController = TextEditingController(text: widget.client.email);
    _cityController = TextEditingController(text: widget.client.city);
    _assignedToController =
        TextEditingController(text: widget.client.assignedTo);
    _requirementController =
        TextEditingController(text: widget.client.requirementSummary);
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _companyNameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _assignedToController.dispose();
    _requirementController.dispose();
    super.dispose();
  }

  Future<void> _changeStatus(int newStatusNo) async {
    if (newStatusNo == _currentStatusNo) return;

    setState(() {
      _changingStatus = true;
    });

    try {
      await widget.repository.changeClientStatus(
        clientId: widget.client.clientId,
        statusId: newStatusNo,
      );

      setState(() {
        _currentStatusNo = newStatusNo;
        _changingStatus = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status updated to ${_getStatusName(newStatusNo)}',
            ),
            backgroundColor: AppTheme.green,
          ),
        );
        // Return updated status to previous screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _changingStatus = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  String _getStatusName(int statusNo) {
    final status = widget.statuses.firstWhere(
      (s) => s.statusNo == statusNo,
      orElse: () => StatusMaster(
        statusNo: statusNo,
        statusName: 'Unknown',
        category: '',
        description: '',
      ),
    );
    return status.statusName;
  }

  void _cancelEdit() {
    // Reset controllers to original values
    _clientNameController.text = widget.client.clientName;
    _companyNameController.text = widget.client.companyName;
    _phoneController.text = widget.client.phone;
    _whatsappController.text = widget.client.whatsappNumber;
    _emailController.text = widget.client.email;
    _cityController.text = widget.client.city;
    _assignedToController.text = widget.client.assignedTo;
    _requirementController.text = widget.client.requirementSummary;
    _selectedPriority = widget.client.priority;
    _currentStatusNo = widget.client.currentStatusNo;

    setState(() => _isEditMode = false);
  }

  Future<void> _saveClient() async {
    // Validate required fields
    if (_clientNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client name is required'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    if (_companyNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company name is required'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty ||
        _phoneController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number must be exactly 10 digits'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    if (_assignedToController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assigned to is required'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Build update payload with only changed fields
      final updates = <String, dynamic>{
        'client_id': widget.client.clientId,
      };

      if (_clientNameController.text.trim() != widget.client.clientName) {
        updates['client_name'] = _clientNameController.text.trim();
      }
      if (_companyNameController.text.trim() != widget.client.companyName) {
        updates['company_name'] = _companyNameController.text.trim();
      }
      if (_phoneController.text.trim() != widget.client.phone) {
        updates['phone'] = _phoneController.text.trim();
      }
      if (_whatsappController.text.trim() != widget.client.whatsappNumber) {
        updates['whatsapp_number'] = _whatsappController.text.trim();
      }
      if (_emailController.text.trim() != widget.client.email) {
        updates['email'] = _emailController.text.trim();
      }
      if (_cityController.text.trim() != widget.client.city) {
        updates['city'] = _cityController.text.trim();
      }
      if (_assignedToController.text.trim() != widget.client.assignedTo) {
        updates['assigned_to'] = _assignedToController.text.trim();
      }
      if (_requirementController.text.trim() !=
          widget.client.requirementSummary) {
        updates['requirement_summary'] = _requirementController.text.trim();
      }
      if (_selectedPriority != widget.client.priority) {
        updates['priority'] = _selectedPriority;
      }
      if (_currentStatusNo != widget.client.currentStatusNo) {
        updates['current_status_no'] = _currentStatusNo;
      }

      print('📝 Updating client with payload: $updates');
      await widget.repository.patchClient(updates);

      setState(() {
        _isSaving = false;
        _isEditMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Client updated successfully'),
            backgroundColor: AppTheme.green,
          ),
        );
        // Return true to indicate changes were made
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Error updating client: $e');
      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update client: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Client' : 'Client Details'),
        actions: [
          if (_isSaving || _changingStatus)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_isEditMode) ...[
            TextButton(
              onPressed: _cancelEdit,
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _saveClient,
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditMode = true),
              tooltip: 'Edit Client',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client Name and Company
            _buildHeader(),
            const SizedBox(height: 20),

            // Priority Badge
            _buildPriorityBadge(),
            const SizedBox(height: 24),

            // Basic Info Card
            _buildInfoCard(),
            const SizedBox(height: 20),

            // Status Dropdown
            _buildStatusDropdown(),
            const SizedBox(height: 20),

            // Additional Details
            _buildDetailsCard(),
            const SizedBox(height: 32),

            // Delete Button (only show in view mode, not in edit mode)
            if (!_isEditMode) _buildDeleteButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showDeleteConfirmation,
        icon: const Icon(Icons.delete_outline, color: AppTheme.red),
        label: const Text(
          'Delete Client',
          style: TextStyle(
            color: AppTheme.red,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppTheme.red.withOpacity(0.08),
          side: BorderSide(color: AppTheme.red.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    final confirmationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Client'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this client?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: confirmationController,
              decoration: const InputDecoration(
                labelText: 'Type client name to confirm',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              confirmationController.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (confirmationController.text.trim() ==
                  widget.client.clientName) {
                Navigator.pop(context);
                confirmationController.dispose();
                _deleteClient();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Client name does not match'),
                    backgroundColor: AppTheme.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.red,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClient() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      print('🗑️ Deleting client ${widget.client.clientId}');
      await widget.repository.deleteClient(widget.client.clientId);

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Client "${widget.client.clientName}" deleted successfully'),
          backgroundColor: AppTheme.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Return to client list with refresh flag
      Navigator.pop(context, true);
    } catch (e) {
      print('❌ Error deleting client: $e');

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete client: $e'),
          backgroundColor: AppTheme.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildHeader() {
    if (_isEditMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _clientNameController,
            decoration: const InputDecoration(
              labelText: 'Client Name *',
              prefixIcon: Icon(Icons.person),
            ),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'Company Name *',
              prefixIcon: Icon(Icons.business),
            ),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.client.clientName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (widget.client.companyName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.client.companyName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPriorityBadge() {
    if (_isEditMode) {
      return DropdownButtonFormField<String>(
        value: _selectedPriority,
        decoration: InputDecoration(
          labelText: 'Priority',
          prefixIcon: const Icon(Icons.flag),
          filled: true,
          fillColor: _priorityColor(_selectedPriority).withOpacity(0.1),
        ),
        items: const [
          DropdownMenuItem(value: 'Hot', child: Text('🔴 Hot')),
          DropdownMenuItem(value: 'Warm', child: Text('🟡 Warm')),
          DropdownMenuItem(value: 'Cold', child: Text('🔵 Cold')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedPriority = value);
          }
        },
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _priorityColor(widget.client.priority).withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flag_rounded,
            size: 20,
            color: _priorityColor(widget.client.priority),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.client.priority} Priority',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _priorityColor(widget.client.priority),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    if (_isEditMode) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: Icon(Icons.phone),
                  prefix: Text('+91 '),
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp Number',
                  prefixIcon: Icon(Icons.chat),
                  prefix: Text('+91 '),
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.phone, 'Phone', '+91 ${widget.client.phone}'),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.email,
              'Email',
              widget.client.email.isEmpty
                  ? 'Not provided'
                  : widget.client.email,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, size: 20, color: AppTheme.muted),
                SizedBox(width: 8),
                Text(
                  'Current Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _currentStatusNo,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.green.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.green,
              ),
              icon: const Icon(
                Icons.arrow_drop_down,
                color: AppTheme.green,
              ),
              isExpanded: true,
              items: widget.statuses.map((status) {
                return DropdownMenuItem<int>(
                  value: status.statusNo,
                  child: Text(
                    '${status.statusNo}. ${status.statusName}',
                    style: TextStyle(
                      fontWeight: status.statusNo == _currentStatusNo
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
              onChanged: _isEditMode
                  ? (newValue) {
                      if (newValue != null) {
                        setState(() => _currentStatusNo = newValue);
                      }
                    }
                  : (_changingStatus
                      ? null
                      : (newValue) {
                          if (newValue != null) {
                            _changeStatus(newValue);
                          }
                        }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    if (_isEditMode) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Additional Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _assignedToController,
                decoration: const InputDecoration(
                  labelText: 'Assigned To *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _requirementController,
                decoration: const InputDecoration(
                  labelText: 'Requirement Summary',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              'City',
              widget.client.city.isEmpty ? 'Not provided' : widget.client.city,
            ),
            const Divider(height: 24),
            _buildDetailRow('Assigned To', widget.client.assignedTo),
            const Divider(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Requirement Summary',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.client.requirementSummary.isEmpty
                      ? 'No requirement summary provided'
                      : widget.client.requirementSummary,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
