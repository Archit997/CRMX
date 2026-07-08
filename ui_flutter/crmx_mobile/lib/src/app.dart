import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/domain/auth_state.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
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
      Authenticated() => const ClientListScreen(),
      Unauthenticated() => const LoginScreen(),
      OtpSent() => const LoginScreen(), // Stay on login, will navigate to OTP
      Authenticating() => const _LoadingScreen(),
      AuthError() => const LoginScreen(),
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
