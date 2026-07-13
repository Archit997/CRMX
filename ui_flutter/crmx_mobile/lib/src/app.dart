import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/domain/auth_state.dart';
import '../features/auth/presentation/approval_status_screen.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import 'theme/app_theme.dart';
import 'ui/client_list_screen.dart';

class CRMXMobileApp extends ConsumerStatefulWidget {
  const CRMXMobileApp({super.key});

  @override
  ConsumerState<CRMXMobileApp> createState() => _CRMXMobileAppState();
}

class _CRMXMobileAppState extends ConsumerState<CRMXMobileApp> {
  @override
  void initState() {
    super.initState();
    // Check for existing session on app start
    Future.microtask(() {
      ref.read(authControllerProvider.notifier).checkSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CRMX',
      theme: AppTheme.light(),
      home: _buildHome(authState),
    );
  }

  Widget _buildHome(AuthState authState) {
    return switch (authState) {
      Authenticated(:final user) => ClientListScreen(currentUser: user),
      SignupRequired(:final user) => SignupScreen(user: user),
      ApprovalPending(:final user) =>
        ApprovalStatusScreen(user: user, rejected: false),
      ApprovalRejected(:final user) =>
        ApprovalStatusScreen(user: user, rejected: true),
      Unauthenticated() => const LoginScreen(),
      OtpSent(:final phoneNumber) => OtpScreen(phoneNumber: phoneNumber),
      Authenticating() => const _LoadingScreen(),
      AuthError(:final message) => LoginScreen(initialError: message),
      SessionExpired() => const LoginScreen(),
    };
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
