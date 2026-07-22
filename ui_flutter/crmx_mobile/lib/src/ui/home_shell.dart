import 'package:flutter/material.dart';

import '../data/crmx_repository.dart';
import '../models/crmx_models.dart';
import '../theme/app_theme.dart';
import 'widgets.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.repository,
    required this.session,
    required this.onLogout,
    super.key,
  });

  final CRMXRepository repository;
  final UserSession session;
  final VoidCallback onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  late Future<DashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = widget.repository.loadDashboard();
  }

  Future<void> _refresh() async {
    setState(() {
      _dashboardFuture = widget.repository.loadDashboard();
    });
    await _dashboardFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Company SIM + WhatsApp audit',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Text(
                      'CRMX',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 10),
                    if (data != null)
                      StatusPill(
                        label:
                            data.source == DataSource.api ? 'API live' : 'Mock',
                        color: data.source == DataSource.api
                            ? AppTheme.green
                            : AppTheme.amber,
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: StatusPill(
                    label: widget.session.role,
                    color: AppTheme.blue,
                  ),
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
              ),
              IconButton(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Logout',
              ),
            ],
          ),
          body: SafeArea(
            child: snapshot.connectionState == ConnectionState.waiting &&
                    data == null
                ? const Center(child: CircularProgressIndicator())
                : _Body(
                    data: data!,
                    tab: _tab,
                    repository: widget.repository,
                    session: widget.session,
                    onRefresh: _refresh,
                  ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.today_rounded), label: 'Sales'),
              NavigationDestination(
                  icon: Icon(Icons.people_alt_rounded), label: 'Clients'),
              NavigationDestination(
                  icon: Icon(Icons.graphic_eq_rounded), label: 'Audit'),
              NavigationDestination(
                  icon: Icon(Icons.analytics_rounded), label: 'Manager'),
              NavigationDestination(
                  icon: Icon(Icons.currency_rupee_rounded), label: 'Finance'),
            ],
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.data,
    required this.tab,
    required this.repository,
    required this.session,
    required this.onRefresh,
  });

  final DashboardData data;
  final int tab;
  final CRMXRepository repository;
  final UserSession session;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final pages = [
      SalesDayScreen(data: data, repository: repository, onRefresh: onRefresh),
      ClientWorkspaceScreen(
        data: data,
        repository: repository,
        session: session,
        onRefresh: onRefresh,
      ),
      CallIntelligenceScreen(data: data),
      ManagerScreen(data: data),
      FinanceScreen(data: data),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: [
        MetricStrip(data: data),
        const SizedBox(height: 14),
        pages[tab],
      ],
    );
  }
}

class MetricStrip extends StatelessWidget {
  const MetricStrip({required this.data, super.key});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: MetricCard(value: '${data.manager.calls}', label: 'calls')),
        const SizedBox(width: 10),
        Expanded(
            child: MetricCard(
                value: '${data.manager.whatsapp}', label: 'WhatsApp')),
        const SizedBox(width: 10),
        Expanded(
          child: MetricCard(
            value: '${data.manager.overdueFollowups}',
            label: 'overdue',
            color: AppTheme.red,
          ),
        ),
      ],
    );
  }
}

class SalesDayScreen extends StatefulWidget {
  const SalesDayScreen({
    required this.data,
    required this.repository,
    required this.onRefresh,
    super.key,
  });

  final DashboardData data;
  final CRMXRepository repository;
  final Future<void> Function() onRefresh;

  @override
  State<SalesDayScreen> createState() => _SalesDayScreenState();
}

class _SalesDayScreenState extends State<SalesDayScreen> {
  late int _clientId;
  late int _statusNo;
  String _requestSubtype = 'Quotation';
  final _noteController = TextEditingController(
      text: 'Client asked for bulk discount after checking quotation.');

  @override
  void initState() {
    super.initState();
    _clientId = widget.data.clients.first.clientId;
    _statusNo = widget.data.clients.first.currentStatusNo;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
            eyebrow: 'Rohit Sharma', title: 'Sales executive day'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InfoCard(
                icon: Icons.phone_in_talk_rounded,
                title: 'Company SIM',
                value: '${widget.data.manager.calls} calls',
                color: AppTheme.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InfoCard(
                icon: Icons.chat_rounded,
                title: 'WhatsApp',
                value: '${widget.data.manager.whatsapp} chats',
                color: AppTheme.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                initialValue: _clientId,
                decoration: const InputDecoration(labelText: 'Client'),
                items: widget.data.clients
                    .map(
                      (client) => DropdownMenuItem(
                        value: client.clientId,
                        child:
                            Text('${client.clientName}, ${client.companyName}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final client = widget.data.clients
                      .firstWhere((item) => item.clientId == value);
                  setState(() {
                    _clientId = value;
                    _statusNo = client.currentStatusNo;
                  });
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _statusNo,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: widget.data.statuses
                          .map(
                            (status) => DropdownMenuItem(
                              value: status.statusNo,
                              child: Text(status.statusName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _statusNo = value ?? _statusNo),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _requestSubtype,
                      decoration: const InputDecoration(labelText: 'Request'),
                      items: const [
                        'Price',
                        'Quotation',
                        'Receipt',
                        'Delivery',
                        'None'
                      ]
                          .map((item) =>
                              DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) => setState(
                          () => _requestSubtype = value ?? _requestSubtype),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                minLines: 3,
                maxLines: 5,
                decoration:
                    const InputDecoration(labelText: 'Call / WhatsApp note'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saveUpdate,
                child: const Text('Save update'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionHeader(eyebrow: 'Today', title: 'Follow-up queue'),
        const SizedBox(height: 8),
        ...widget.data.followUps.map((item) => FollowUpTile(item: item)),
      ],
    );
  }

  Future<void> _saveUpdate() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) return;

    try {
      await widget.repository.createUpdate(
        clientId: _clientId,
        newStatusNo: _statusNo,
        note: note,
        requestSubtype: _requestSubtype,
        followupDate: '2026-06-08',
        followupTime: '12:00',
      );
      await widget.onRefresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('API not reachable. UI is running in mock-safe mode.')),
      );
    }
  }
}

class ClientWorkspaceScreen extends StatefulWidget {
  const ClientWorkspaceScreen({
    required this.data,
    required this.repository,
    required this.session,
    required this.onRefresh,
    super.key,
  });

  final DashboardData data;
  final CRMXRepository repository;
  final UserSession session;
  final Future<void> Function() onRefresh;

  @override
  State<ClientWorkspaceScreen> createState() => _ClientWorkspaceScreenState();
}

class _ClientWorkspaceScreenState extends State<ClientWorkspaceScreen> {
  final _searchController = TextEditingController();
  late List<ClientInfo> _clients;
  ClientInfo? _selected;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _clients = widget.data.clients;
    _selected = _clients.isEmpty ? null : _clients.first;
  }

  @override
  void didUpdateWidget(covariant ClientWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.clients != widget.data.clients) {
      _clients = widget.data.clients;
      if (_selected != null) {
        _selected = _clients
            .where((item) => item.clientId == _selected!.clientId)
            .firstOrNull;
      }
      _selected ??= _clients.isEmpty ? null : _clients.first;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
            eyebrow: 'Client desk', title: 'Customers and leads'),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search name, company, phone',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _clients = widget.data.clients);
                          },
                        ),
                ),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openCreate,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Add lead'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _search,
                    icon: const Icon(Icons.manage_search_rounded),
                    tooltip: 'Search',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_clients.isEmpty)
          const AppCard(
            child: Text(
              'No matching client found.',
              style:
                  TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800),
            ),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _clients.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = _clients[index];
                final active = item.clientId == client?.clientId;
                return SizedBox(
                  width: 230,
                  child: ClientListCard(
                    client: item,
                    active: active,
                    onTap: () => setState(() => _selected = item),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        if (client == null)
          const SizedBox.shrink()
        else ...[
          SectionHeader(eyebrow: client.companyName, title: client.clientName),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(
                        label: client.priority,
                        color: _priorityColor(client.priority)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: StatusPill(
                            label: client.statusName, color: AppTheme.green)),
                  ],
                ),
                const SizedBox(height: 14),
                DetailRow(label: 'Phone', value: '+91 ${client.phone}'),
                DetailRow(
                    label: 'WhatsApp', value: '+91 ${client.whatsappNumber}'),
                DetailRow(
                    label: 'Email',
                    value: client.email.isEmpty ? 'Not added' : client.email),
                DetailRow(label: 'Owner', value: client.assignedToName),
                DetailRow(
                    label: 'City',
                    value: client.city.isEmpty ? 'Not added' : client.city),
                DetailRow(label: 'Value', value: currency(client.dealValue)),
                DetailRow(label: 'Need', value: client.requirementSummary),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openEdit(client),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      onPressed: () => _deleteClient(client),
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Delete client',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(
              eyebrow: 'Status path', title: 'Current movement'),
          const SizedBox(height: 8),
          StatusRail(
              statuses: widget.data.statuses,
              currentStatusNo: client.currentStatusNo),
          const SizedBox(height: 16),
          const SectionHeader(eyebrow: 'Audit trail', title: 'Latest updates'),
          const SizedBox(height: 8),
          ...client.updates.map((update) => TimelineTile(update: update)),
        ],
      ],
    );
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    try {
      final results =
          await widget.repository.searchClients(_searchController.text.trim());
      setState(() {
        _clients = results;
        _selected = results.isEmpty ? null : results.first;
      });
    } catch (_) {
      final term = _searchController.text.trim().toLowerCase();
      setState(() {
        _clients = widget.data.clients
            .where(
              (client) =>
                  client.clientName.toLowerCase().contains(term) ||
                  client.companyName.toLowerCase().contains(term) ||
                  client.phone.contains(term),
            )
            .toList();
        _selected = _clients.isEmpty ? null : _clients.first;
      });
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _openCreate() async {
    final draft = await showModalBottomSheet<ClientDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ClientFormSheet(
        statuses: widget.data.statuses,
        defaultOwner: widget.session.name,
      ),
    );
    if (draft == null) return;

    try {
      final client = await widget.repository.createClient(draft.toJson());
      await widget.onRefresh();
      setState(() => _selected = client);
    } catch (_) {
      _showError('Could not create client.');
    }
  }

  Future<void> _openEdit(ClientInfo client) async {
    final draft = await showModalBottomSheet<ClientDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ClientFormSheet(
        statuses: widget.data.statuses,
        existing: client,
        defaultOwner: widget.session.name,
      ),
    );
    if (draft == null) return;

    try {
      final updated =
          await widget.repository.updateClient(client.clientId, draft);
      await widget.onRefresh();
      setState(() => _selected = updated);
    } catch (_) {
      _showError('Could not update client.');
    }
  }

  Future<void> _deleteClient(ClientInfo client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete client?'),
        content: Text(
            '${client.clientName} and related updates will be removed from this POC data set.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.repository.deleteClient(client.clientId);
      await widget.onRefresh();
      setState(() {
        _clients = widget.data.clients
            .where((item) => item.clientId != client.clientId)
            .toList();
        _selected = _clients.isEmpty ? null : _clients.first;
      });
    } catch (_) {
      _showError('Could not delete client.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Color _priorityColor(String priority) {
    return switch (priority) {
      'Hot' => AppTheme.red,
      'Cold' => AppTheme.blue,
      _ => AppTheme.amber,
    };
  }
}

class ClientFormSheet extends StatefulWidget {
  const ClientFormSheet({
    required this.statuses,
    required this.defaultOwner,
    this.existing,
    super.key,
  });

  final List<StatusMaster> statuses;
  final ClientInfo? existing;
  final String defaultOwner;

  @override
  State<ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends State<ClientFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _emailController;
  late final TextEditingController _cityController;
  late final TextEditingController _ownerController;
  late final TextEditingController _needController;
  late final TextEditingController _valueController;
  late int _statusNo;
  late String _priority;

  @override
  void initState() {
    super.initState();
    final client = widget.existing;
    _nameController = TextEditingController(text: client?.clientName ?? '');
    _companyController = TextEditingController(text: client?.companyName ?? '');
    _phoneController = TextEditingController(text: client?.phone ?? '');
    _whatsappController =
        TextEditingController(text: client?.whatsappNumber ?? '');
    _emailController = TextEditingController(text: client?.email ?? '');
    _cityController = TextEditingController(text: client?.city ?? '');
    _ownerController =
        TextEditingController(text: client?.assignedTo ?? widget.defaultOwner);
    _needController =
        TextEditingController(text: client?.requirementSummary ?? '');
    _valueController = TextEditingController(
        text: client == null ? '' : client.dealValue.toString());
    _statusNo = client?.currentStatusNo ?? 1;
    _priority = client?.priority ?? 'Warm';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _ownerController.dispose();
    _needController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null
                          ? 'Add customer lead'
                          : 'Edit customer',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Client name')),
              const SizedBox(height: 10),
              TextField(
                  controller: _companyController,
                  decoration: const InputDecoration(labelText: 'Company')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _whatsappController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'WhatsApp'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _cityController,
                          decoration:
                              const InputDecoration(labelText: 'City'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: _ownerController,
                          decoration:
                              const InputDecoration(labelText: 'Owner'))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const ['Hot', 'Warm', 'Cold']
                          .map((item) =>
                              DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _priority = value ?? _priority),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _valueController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Deal value'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _statusNo,
                decoration: const InputDecoration(labelText: 'Status'),
                items: widget.statuses
                    .map((status) => DropdownMenuItem(
                        value: status.statusNo, child: Text(status.statusName)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _statusNo = value ?? _statusNo),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _needController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                    labelText: 'Requirement / latest context'),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_rounded),
                label: Text(
                    widget.existing == null ? 'Create client' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final owner = _ownerController.text.trim();
    final need = _needController.text.trim();
    if (name.isEmpty || phone.isEmpty || owner.isEmpty || need.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Name, phone, owner, and requirement are required.')),
      );
      return;
    }

    Navigator.pop(
      context,
      ClientDraft(
        clientName: name,
        companyName: _companyController.text.trim(),
        phone: phone,
        whatsappNumber: _whatsappController.text.trim().isEmpty
            ? phone
            : _whatsappController.text.trim(),
        email: _emailController.text.trim(),
        city: _cityController.text.trim(),
        assignedTo: owner,
        currentStatusNo: _statusNo,
        requirementSummary: need,
        priority: _priority,
        dealValue: int.tryParse(_valueController.text.trim()) ?? 0,
      ),
    );
  }
}

class CallIntelligenceScreen extends StatelessWidget {
  const CallIntelligenceScreen({required this.data, super.key});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final client = data.clients.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
            eyebrow: 'Future module', title: 'Call intelligence'),
        const SizedBox(height: 12),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recording to insight pipeline',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 12),
              PipelineStep(
                number: '1',
                title: 'Record',
                body:
                    'Capture work calls from company SIM with consent and policy controls.',
              ),
              PipelineStep(
                number: '2',
                title: 'Transcribe',
                body:
                    'Convert Hindi/English/regional calls into structured text.',
              ),
              PipelineStep(
                number: '3',
                title: 'Translate',
                body:
                    'Normalize transcript to English or company language for managers.',
              ),
              PipelineStep(
                number: '4',
                title: 'Generate insight',
                body:
                    'Extract status, request type, next action, follow-up date, risk, and owner.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusPill(label: 'LLM-ready', color: AppTheme.blue),
              const SizedBox(height: 10),
              Text(
                client.clientName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Detected: discount objection, delivery urgency, revised quotation required.',
                style: TextStyle(
                    color: AppTheme.muted,
                    height: 1.35,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ManagerScreen extends StatelessWidget {
  const ManagerScreen({required this.data, super.key});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(eyebrow: 'Today', title: 'Manager analytics'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                  value: '${data.manager.overdueFollowups}',
                  label: 'missed follow-ups'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                  value: currency(data.manager.quotedValue),
                  label: 'quoted value'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        MetricCard(
          value: '${data.manager.unloggedCalls}',
          label: 'unlogged calls requiring audit',
          color: AppTheme.red,
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recommended digest',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                '${data.manager.overdueFollowups} overdue follow-ups, '
                '${data.manager.unloggedCalls} unlogged calls, '
                '${currency(data.manager.quotedValue)} in quoted pipeline.',
                style: const TextStyle(
                    color: AppTheme.muted,
                    height: 1.35,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({required this.data, super.key});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final total =
        data.receivables.fold<int>(0, (sum, item) => sum + item.amountDue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(eyebrow: 'Receivables', title: '${currency(total)} due'),
        const SizedBox(height: 12),
        ...data.receivables.map((item) => ReceivableTile(item: item)),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WhatsApp finance summary',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                data.financeMessage,
                style: const TextStyle(
                    color: AppTheme.muted,
                    height: 1.45,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
