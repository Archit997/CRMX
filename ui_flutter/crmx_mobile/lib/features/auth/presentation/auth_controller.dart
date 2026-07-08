import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_state.dart';
import '../domain/auth_user.dart';

// Providers
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.read(authRepositoryProvider));
});

final authUserProvider = StreamProvider<AuthUser?>((ref) async* {
  final repository = ref.read(authRepositoryProvider);
  
  // Emit current user immediately
  final currentUser = await repository.getCurrentUser();
  yield currentUser;
  
  // Then listen to auth state changes
  await for (final state in repository.authStateChanges()) {
    if (state is Authenticated) {
      yield state.user;
    } else {
      yield null;
    }
  }
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authRepository) : super(const Unauthenticated());

  final AuthRepository _authRepository;

  /// Send OTP to phone number
  Future<void> sendOtp(String phoneNumber) async {
    try {
      state = const Authenticating();
      await _authRepository.sendOtp(phoneNumber);
      state = OtpSent(phoneNumber);
    } on Exception catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// Verify OTP and sign in
  Future<void> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      state = const Authenticating();
      final user = await _authRepository.verifyOtp(
        phoneNumber: phoneNumber,
        otp: otp,
      );
      state = Authenticated(user);
    } on Exception catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      state = const Authenticating();
      await _authRepository.signOut();
      state = const Unauthenticated();
    } on Exception catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// Check if there's an existing session on app start
  Future<void> checkSession() async {
    try {
      final isAuthenticated = await _authRepository.isAuthenticated();
      if (isAuthenticated) {
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          state = Authenticated(user);
        } else {
          state = const Unauthenticated();
        }
      } else {
        state = const Unauthenticated();
      }
    } catch (e) {
      state = const Unauthenticated();
    }
  }

  /// Refresh session
  Future<void> refreshSession() async {
    try {
      await _authRepository.refreshSession();
    } catch (e) {
      state = const SessionExpired();
    }
  }
}
