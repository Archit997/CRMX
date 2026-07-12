import '../../../services/api/api_client.dart';

class AppUserProfile {
  const AppUserProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.approvalStatus,
    required this.isActive,
    this.contact,
  });

  final String id;
  final String name;
  final String phone;
  final String role;
  final String approvalStatus;
  final bool isActive;
  final String? contact;

  factory AppUserProfile.fromJson(Map<String, dynamic> json) {
    return AppUserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      approvalStatus: json['approval_status'] as String,
      isActive: json['is_active'] == true,
      contact: json['contact'] as String?,
    );
  }
}

class UserManagementRepository {
  const UserManagementRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppUserProfile>> listPendingUsers() async {
    final response = await _apiClient.get('/users/pending');
    return (response as List<dynamic>)
        .map((item) => AppUserProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AppUserProfile> verifyUser({
    required String userId,
    required String approvalStatus,
    String? verifiedBy,
    String? rejectionReason,
  }) async {
    final response = await _apiClient.patch(
      '/users/$userId/verification',
      body: {
        'approval_status': approvalStatus,
        if (verifiedBy != null) 'verified_by': verifiedBy,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
      },
    );
    return AppUserProfile.fromJson(response as Map<String, dynamic>);
  }
}
