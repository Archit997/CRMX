import 'package:crmx_mobile/features/auth/data/auth_repository.dart';
import 'package:crmx_mobile/features/auth/domain/auth_state.dart';
import 'package:crmx_mobile/features/auth/domain/auth_user.dart';
import 'package:crmx_mobile/features/auth/presentation/auth_controller.dart';
import 'package:crmx_mobile/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login screen renders phone OTP flow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to CRMX'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.textContaining('Test OTP is 123456'), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> sendOtp(String phoneNumber) async {}

  @override
  Future<AuthUser> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    return AuthUser(id: 'test-user', phone: phoneNumber);
  }

  @override
  Future<AuthUser?> getAppProfile(AuthUser user) async => null;

  @override
  Future<AuthUser> requestSignup({
    required AuthUser user,
    required String name,
    required String role,
    String? contact,
  }) async {
    return user.copyWith(
      name: name,
      role: role,
      contact: contact,
      approvalStatus: 'pending',
    );
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser?> getCurrentUser() async => null;

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();

  @override
  Future<void> refreshSession() async {}
}
