import '../../../services/api/api_client.dart';

class OrganizationSummary {
  const OrganizationSummary({
    required this.id,
    required this.name,
    required this.joinCode,
  });

  final String id;
  final String name;
  final String joinCode;

  factory OrganizationSummary.fromJson(Map<String, dynamic> json) {
    return OrganizationSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      joinCode: json['join_code'] as String,
    );
  }
}

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.approvalStatus,
    required this.isActive,
    this.contact,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String role;
  final String approvalStatus;
  final bool isActive;
  final String? contact;
  final DateTime? createdAt;

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      approvalStatus: json['approval_status'] as String,
      isActive: json['is_active'] == true,
      contact: json['contact'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}

class ManagedAuditEvent {
  const ManagedAuditEvent({
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.actorId,
    required this.createdAt,
    this.requestId,
  });

  final String action;
  final String entityType;
  final String entityId;
  final String actorId;
  final DateTime createdAt;
  final String? requestId;

  factory ManagedAuditEvent.fromJson(Map<String, dynamic> json) {
    return ManagedAuditEvent(
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      actorId: json['actor_id'] as String,
      createdAt: DateTime.parse(json['created_at'].toString()),
      requestId: json['request_id'] as String?,
    );
  }
}

class AdminRepository {
  const AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<OrganizationSummary> getOrganization() async {
    final response = await _apiClient.get('/api/organizations/me');
    return OrganizationSummary.fromJson(
      response as Map<String, dynamic>,
    );
  }

  Future<OrganizationSummary> rotateJoinCode() async {
    final response = await _apiClient.post(
      '/api/organizations/join-code/rotate',
    );
    return OrganizationSummary.fromJson(
      response as Map<String, dynamic>,
    );
  }

  Future<List<ManagedUser>> listUsers({String? approvalStatus}) async {
    final response = await _apiClient.get(
      '/users',
      queryParams: {
        if (approvalStatus != null) 'approval_status': approvalStatus,
      },
    );
    return (response as List<dynamic>)
        .map(
          (item) => ManagedUser.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<ManagedAuditEvent>> listAuditEvents() async {
    final response = await _apiClient.get(
      '/api/audit-events',
      queryParams: {'limit': '50'},
    );
    return (response as List<dynamic>)
        .map(
          (item) => ManagedAuditEvent.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<ManagedUser> verifyUser({
    required String userId,
    required String approvalStatus,
    String? rejectionReason,
  }) async {
    final response = await _apiClient.patch(
      '/users/$userId/verification',
      body: {
        'approval_status': approvalStatus,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
      },
    );
    return ManagedUser.fromJson(response as Map<String, dynamic>);
  }

  Future<ManagedUser> updateAccess({
    required String userId,
    String? role,
    bool? isActive,
  }) async {
    final response = await _apiClient.patch(
      '/users/$userId/access',
      body: {
        if (role != null) 'role': role,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return ManagedUser.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteUser(String userId) async {
    await _apiClient.delete('/users/$userId');
  }
}
