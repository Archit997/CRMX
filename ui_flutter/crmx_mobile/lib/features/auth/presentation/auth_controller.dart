import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/cache/cache_service.dart';
import '../../../core/errors.dart';
import '../../../services/api/api_client.dart';
import '../data/auth_repository.dart';
import '../data/backend_auth_repository.dart';
import '../domain/auth_state.dart';
import '../domain/auth_user.dart';

// Providers

/// Provider for cache service with automatic token refresh
final Provider<CacheService> baseCacheServiceProvider = Provider<CacheService>((ref) {
  // Create cache service holder
  late CacheService cacheService;
  
  // Create API client with token refresh capability
  final apiClient = ApiClient(
    tokenProvider: () async {
      return cacheService.getCachedAuthToken();
    },
    refreshTokenProvider: () async {
      // Return the refresh token from cache
      return cacheService.getCachedRefreshToken();
    },
    tokenUpdater: (newToken, newRefreshToken) async {
      // Update cache with new tokens after refresh
      cacheService.cacheAuthToken(newToken);
      cacheService.cacheRefreshToken(newRefreshToken);
    },
  );
  
  // Create the cache service
  cacheService = CacheService(apiClient);
  
  return cacheService;
});

/// Provider for auth repository using backend API
final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((ref) {
  final cacheService = ref.read(baseCacheServiceProvider);
  return BackendAuthRepository(cacheService);
});

/// Alias for auth cache service (for backward compatibility)
final Provider<CacheService> authCacheServiceProvider = Provider<CacheService>((ref) {
  return ref.read(baseCacheServiceProvider);
});

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.read(authRepositoryProvider),
    ref.read(authCacheServiceProvider),
  );
});

final StreamProvider<AuthUser?> authUserProvider = StreamProvider<AuthUser?>((ref) async* {
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
  AuthController(this._authRepository, this._cacheService)
      : super(const Unauthenticated());

  final AuthRepository _authRepository;
  final CacheService _cacheService;

  /// Send OTP to phone number
  Future<void> sendOtp(String phoneNumber) async {
    try {
      state = const Authenticating();
      await _authRepository.sendOtp(phoneNumber);
      state = OtpSent(phoneNumber);
    } on Exception catch (e) {
      state = AuthError(ErrorHandler.getUserFriendlyMessage(e));
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
      state = await _stateForUser(user);
    } on Exception catch (e) {
      state = AuthError(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  Future<void> requestSignup({
    required AuthUser user,
    required String name,
    required String role,
    String? contact,
  }) async {
    try {
      state = const Authenticating();
      final pendingUser = await _authRepository.requestSignup(
        user: user,
        name: name,
        role: role,
        contact: contact,
      );
      state = ApprovalPending(pendingUser);
    } on Exception catch (e) {
      state = AuthError(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      state = const Authenticating();
      await _authRepository.signOut();
      
      // Clear all caches on logout
      _cacheService.clearAll();
      
      state = const Unauthenticated();
    } on Exception catch (e) {
      state = AuthError(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  /// Check if there's an existing session on app start
  Future<void> checkSession() async {
    try {
      final isAuthenticated = await _authRepository.isAuthenticated();
      if (isAuthenticated) {
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          state = await _stateForUser(user);
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

  /// Check approval status with fresh data from backend
  /// 
  /// This method is specifically for when a user on the approval pending screen
  /// clicks "Check again" - it bypasses cache to get the latest approval status
  /// from the backend in case an admin just approved/rejected them.
  Future<void> checkApprovalStatus() async {
    try {
      state = const Authenticating();
      
      // Invalidate cached user data to force fresh fetch
      _cacheService.invalidateCurrentUserData();
      
      final isAuthenticated = await _authRepository.isAuthenticated();
      if (isAuthenticated) {
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          // Force refresh to bypass cache and get fresh approval status
          state = await _stateForUser(user, forceRefresh: true);
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

  Future<AuthState> _stateForUser(AuthUser user, {bool forceRefresh = false}) async {
    final profile = await _authRepository.getAppProfile(user, forceRefresh: forceRefresh);
    if (profile == null) {
      return SignupRequired(user);
    }

    // Cache the current user data (no longer caching AuthUser object, just data)
    _cacheService.cacheCurrentUserData(profile.toMap());

    return switch (profile.approvalStatus) {
      'approved' when profile.isActive => Authenticated(profile),
      'rejected' => ApprovalRejected(profile),
      _ => ApprovalPending(profile),
    };
  }
}
