import 'package:crmx_mobile/features/auth/data/auth_repository.dart';
import 'package:crmx_mobile/features/auth/domain/auth_state.dart';
import 'package:crmx_mobile/features/auth/domain/auth_user.dart';
import 'package:crmx_mobile/features/auth/presentation/auth_controller.dart';
import 'package:crmx_mobile/features/auth/presentation/login_screen.dart';
import 'package:crmx_mobile/features/auth/presentation/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login screen renders phone OTP flow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    expect(find.textContaining('Configured test numbers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new user can choose company setup or team join', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(
          home: SignupScreen(
            user: AuthUser(id: 'new-user', phone: '+919999999999'),
          ),
        ),
      ),
    );

    expect(find.text('Join company'), findsOneWidget);
    expect(find.text('Set up company'), findsOneWidget);
    expect(find.text('Company code'), findsOneWidget);

    await tester.tap(find.text('Set up company'));
    await tester.pumpAndSettle();

    expect(find.text('Company name'), findsOneWidget);
    expect(find.text('Create company workspace'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
  Future<AuthUser?> getAppProfile(
    AuthUser user, {
    bool forceRefresh = false,
  }) async =>
      null;

  @override
  Future<AuthUser> requestSignup({
    required AuthUser user,
    required String name,
    required String role,
    required String organizationCode,
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
  Future<AuthUser> bootstrapOrganization({
    required AuthUser user,
    required String organizationName,
    required String adminName,
    String? contact,
  }) async {
    return user.copyWith(
      name: adminName,
      role: 'ADMIN',
      contact: contact,
      approvalStatus: 'approved',
      isActive: true,
      organizationId: 'organization-id',
      organizationName: organizationName,
    );
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser?> getCurrentUser() async => null;

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> updateTokens(
    String accessToken,
    String refreshToken,
  ) async {}

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();

  @override
  Future<void> refreshSession() async {}
}
