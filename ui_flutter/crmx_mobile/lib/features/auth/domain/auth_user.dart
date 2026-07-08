class AuthUser {
  const AuthUser({
    required this.id,
    required this.phone,
    this.email,
    this.createdAt,
  });

  final String id;
  final String phone;
  final String? email;
  final DateTime? createdAt;

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
