import '../domain/auth_state.dart';
import '../domain/auth_user.dart';

/// Abstract auth repository interface
abstract class AuthRepository {
  /// Send OTP to phone number
  Future<void> sendOtp(String phoneNumber);

  /// Verify OTP and sign in
  Future<AuthUser> verifyOtp({
    required String phoneNumber,
    required String otp,
  });

  /// Get app profile and approval state for a Supabase auth user
  Future<AuthUser?> getAppProfile(AuthUser user);

  /// Create pending app profile after first OTP verification
  Future<AuthUser> requestSignup({
    required AuthUser user,
    required String name,
    required String role,
    String? contact,
  });

  /// Sign out
  Future<void> signOut();

  /// Get current authenticated user
  Future<AuthUser?> getCurrentUser();

  /// Get current access token
  Future<String?> getAccessToken();

  /// Check if user is authenticated
  Future<bool> isAuthenticated();

  /// Listen to auth state changes
  Stream<AuthState> authStateChanges();

  /// Refresh session
  Future<void> refreshSession();
}
