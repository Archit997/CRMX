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
  ///
  /// If [forceRefresh] is true, bypasses cache and fetches fresh data from backend.
  /// Useful when you know the user's approval status may have changed (e.g., after admin approval).
  Future<AuthUser?> getAppProfile(AuthUser user, {bool forceRefresh = false});

  /// Create pending app profile after first OTP verification
  Future<AuthUser> requestSignup({
    required AuthUser user,
    required String name,
    required String role,
    required String organizationCode,
    String? contact,
  });

  /// Create the first organization and immediately activate its admin.
  Future<AuthUser> bootstrapOrganization({
    required AuthUser user,
    required String organizationName,
    required String adminName,
    String? contact,
  });

  /// Sign out
  Future<void> signOut();

  /// Get current authenticated user
  Future<AuthUser?> getCurrentUser();

  /// Get current access token
  Future<String?> getAccessToken();

  /// Get the current refresh token.
  Future<String?> getRefreshToken();

  /// Persist a rotated access/refresh token pair.
  Future<void> updateTokens(String accessToken, String refreshToken);

  /// Check if user is authenticated
  Future<bool> isAuthenticated();

  /// Listen to auth state changes
  Stream<AuthState> authStateChanges();

  /// Refresh session
  Future<void> refreshSession();
}
