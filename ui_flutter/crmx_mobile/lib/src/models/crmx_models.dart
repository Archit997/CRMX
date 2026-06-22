class StatusMaster {
  const StatusMaster({
    required this.statusNo,
    required this.statusName,
    required this.category,
    required this.description,
  });

  final int statusNo;
  final String statusName;
  final String category;
  final String description;

  factory StatusMaster.fromJson(Map<String, dynamic> json) {
    return StatusMaster(
      statusNo: json['status_no'] as int,
      statusName: json['status_name'] as String,
      category: json['category'] as String,
      description: (json['description'] ?? '') as String,
    );
  }
}

class UserSession {
  const UserSession({
    required this.token,
    required this.userId,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
  });

  final String token;
  final int userId;
  final String name;
  final String phone;
  final String email;
  final String role;

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return UserSession(
      token: json['token'] as String,
      userId: user['user_id'] as int,
      name: user['name'] as String,
      phone: user['phone'] as String,
      email: user['email'] as String,
      role: user['role'] as String,
    );
  }
}

class ClientInfo {
  const ClientInfo({
    required this.clientId,
    required this.clientName,
    required this.companyName,
    required this.phone,
    required this.whatsappNumber,
    required this.email,
    required this.city,
    required this.assignedTo,
    required this.currentStatusNo,
    required this.statusName,
    required this.requirementSummary,
    required this.priority,
    required this.dealValue,
    this.updates = const [],
  });

  final int clientId;
  final String clientName;
  final String companyName;
  final String phone;
  final String whatsappNumber;
  final String email;
  final String city;
  final String assignedTo;
  final int currentStatusNo;
  final String statusName;
  final String requirementSummary;
  final String priority;
  final int dealValue;
  final List<ClientUpdate> updates;

  factory ClientInfo.fromJson(Map<String, dynamic> json) {
    return ClientInfo(
      clientId: json['client_id'] as int,
      clientName: json['client_name'] as String,
      companyName: (json['company_name'] ?? '') as String,
      phone: json['phone'] as String,
      whatsappNumber: (json['whatsapp_number'] ?? json['phone']) as String,
      email: (json['email'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      assignedTo: json['assigned_to'] as String,
      currentStatusNo: json['current_status_no'] as int,
      statusName: (json['status_name'] ?? 'Unknown') as String,
      requirementSummary: (json['requirement_summary'] ?? '') as String,
      priority: json['priority'] as String,
      dealValue: (json['deal_value'] ?? 0) as int,
      updates: ((json['updates'] ?? []) as List<dynamic>)
          .map((item) => ClientUpdate.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ClientDraft {
  const ClientDraft({
    required this.clientName,
    required this.companyName,
    required this.phone,
    required this.whatsappNumber,
    required this.email,
    required this.city,
    required this.assignedTo,
    required this.currentStatusNo,
    required this.requirementSummary,
    required this.priority,
    required this.dealValue,
  });

  final String clientName;
  final String companyName;
  final String phone;
  final String whatsappNumber;
  final String email;
  final String city;
  final String assignedTo;
  final int currentStatusNo;
  final String requirementSummary;
  final String priority;
  final int dealValue;

  factory ClientDraft.fromClient(ClientInfo client) {
    return ClientDraft(
      clientName: client.clientName,
      companyName: client.companyName,
      phone: client.phone,
      whatsappNumber: client.whatsappNumber,
      email: client.email,
      city: client.city,
      assignedTo: client.assignedTo,
      currentStatusNo: client.currentStatusNo,
      requirementSummary: client.requirementSummary,
      priority: client.priority,
      dealValue: client.dealValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_name': clientName,
      'company_name': companyName,
      'phone': phone,
      'whatsapp_number': whatsappNumber,
      'email': email,
      'city': city,
      'assigned_to': assignedTo,
      'current_status_no': currentStatusNo,
      'requirement_summary': requirementSummary,
      'priority': priority,
      'deal_value': dealValue,
    };
  }
}

class ClientUpdate {
  const ClientUpdate({
    required this.updateId,
    required this.clientId,
    required this.updateType,
    required this.newStatusNo,
    required this.note,
    required this.followupDate,
    required this.followupTime,
    required this.createdBy,
  });

  final int updateId;
  final int clientId;
  final String updateType;
  final int newStatusNo;
  final String note;
  final String? followupDate;
  final String? followupTime;
  final String createdBy;

  factory ClientUpdate.fromJson(Map<String, dynamic> json) {
    return ClientUpdate(
      updateId: json['update_id'] as int,
      clientId: json['client_id'] as int,
      updateType: json['update_type'] as String,
      newStatusNo: json['new_status_no'] as int,
      note: json['note'] as String,
      followupDate: json['followup_date'] as String?,
      followupTime: json['followup_time'] as String?,
      createdBy: json['created_by'] as String,
    );
  }
}

class FollowUpItem {
  const FollowUpItem({
    required this.clientId,
    required this.clientName,
    required this.companyName,
    required this.priority,
    required this.statusName,
    required this.note,
    required this.followupDate,
    required this.followupTime,
    required this.isOverdue,
  });

  final int clientId;
  final String clientName;
  final String companyName;
  final String priority;
  final String statusName;
  final String note;
  final String followupDate;
  final String? followupTime;
  final bool isOverdue;

  factory FollowUpItem.fromJson(Map<String, dynamic> json) {
    return FollowUpItem(
      clientId: json['client_id'] as int,
      clientName: json['client_name'] as String,
      companyName: (json['company_name'] ?? '') as String,
      priority: json['priority'] as String,
      statusName: json['status_name'] as String,
      note: json['note'] as String,
      followupDate: json['followup_date'] as String,
      followupTime: json['followup_time'] as String?,
      isOverdue: json['is_overdue'] as bool,
    );
  }
}

class ManagerSummary {
  const ManagerSummary({
    required this.calls,
    required this.whatsapp,
    required this.overdueFollowups,
    required this.quotedValue,
    required this.unloggedCalls,
  });

  final int calls;
  final int whatsapp;
  final int overdueFollowups;
  final int quotedValue;
  final int unloggedCalls;

  factory ManagerSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>;
    return ManagerSummary(
      calls: summary['calls'] as int,
      whatsapp: summary['whatsapp'] as int,
      overdueFollowups: summary['overdue_followups'] as int,
      quotedValue: summary['quoted_value'] as int,
      unloggedCalls: summary['unlogged_calls'] as int,
    );
  }
}

class FinanceReceivable {
  const FinanceReceivable({
    required this.clientName,
    required this.companyName,
    required this.amountDue,
    required this.status,
    required this.action,
  });

  final String clientName;
  final String companyName;
  final int amountDue;
  final String status;
  final String action;

  factory FinanceReceivable.fromJson(Map<String, dynamic> json) {
    return FinanceReceivable(
      clientName: json['client_name'] as String,
      companyName: json['company_name'] as String,
      amountDue: json['amount_due'] as int,
      status: json['status'] as String,
      action: json['action'] as String,
    );
  }
}
