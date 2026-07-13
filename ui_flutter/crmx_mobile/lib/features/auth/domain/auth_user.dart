class AuthUser {
  const AuthUser({
    required this.id,
    required this.phone,
    this.email,
    this.name,
    this.role,
    this.contact,
    this.approvalStatus,
    this.isActive = false,
    this.createdAt,
  });

  final String id;
  final String phone;
  final String? email;
  final String? name;
  final String? role;
  final String? contact;
  final String? approvalStatus;
  final bool isActive;
  final DateTime? createdAt;

  AuthUser copyWith({
    String? phone,
    String? email,
    String? name,
    String? role,
    String? contact,
    String? approvalStatus,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AuthUser(
      id: id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      contact: contact ?? this.contact,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          phone == other.phone;

  @override
  int get hashCode => id.hashCode ^ phone.hashCode;

  @override
  String toString() => 'AuthUser(id: $id, phone: $phone, email: $email)';
}
