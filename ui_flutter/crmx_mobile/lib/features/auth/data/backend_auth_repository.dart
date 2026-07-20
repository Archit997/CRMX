import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/cache/cache_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/auth_state.dart';
import '../domain/auth_user.dart';
import 'auth_repository.dart';

class BackendAuthRepository implements AuthRepository {
  BackendAuthRepository(this._cacheService) {
    _authStateController = StreamController<AuthState>.broadcast();
  }

  final CacheService _cacheService;
  late final StreamController<AuthState> _authStateController;

  String get _backendBaseUrl => AppConfig.backendBaseUrl;

  @override
  Future<void> sendOtp(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/api/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phoneNumber}),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw AuthException(error['detail'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to send OTP: ${e.toString()}');
    }
  }

  @override
  Future<AuthUser> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      // CRITICAL: Invalidate any existing cached user data before login
      // This ensures we always get fresh approval status from the backend
      // even if user was previously in "pending" state and admin just approved them
      _cacheService.invalidateCurrentUserData();

      final response = await http.post(
        Uri.parse('$_backendBaseUrl/api/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phoneNumber,
          'otp': otp,
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw AuthException(error['detail'] ?? 'OTP verification failed');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Check if signup required
      if (data['requires_signup'] == true) {
        throw SignupRequiredException(
          userId: data['supabase_user_id'],
          phone: data['phone'],
        );
      }

      // Cache tokens with 10 minute TTL
      final token = data['token'] as String;
      final refreshToken = data['refresh_token'] as String?;

      _cacheService.cacheAuthToken(token);
      if (refreshToken != null) {
        _cacheService.cacheRefreshToken(refreshToken);
      }

      // Now fetch FRESH user data from /api/auth/user/me
      // This will always return current approval status from database
      final userResponse = await http.get(
        Uri.parse('$_backendBaseUrl/api/auth/user/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (userResponse.statusCode != 200) {
        throw AuthException('Failed to fetch user data');
      }

      final userData = jsonDecode(userResponse.body) as Map<String, dynamic>;

      // Cache the FRESH user data with 10 minute TTL
      _cacheService.cacheCurrentUserData(userData);

      // Convert to AuthUser
      return AuthUser(
        id: userData['id'] as String,
        phone: userData['phone'] as String,
        email: userData['email'] as String?,
        name: userData['name'] as String?,
        role: userData['role'] as String?,
        contact: userData['contact'] as String?,
        approvalStatus: userData['approval_status'] as String?,
        isActive: userData['is_active'] == true,
      );
    } catch (e) {
      if (e is AuthException || e is SignupRequiredException) rethrow;
      throw AuthException('Failed to verify OTP: ${e.toString()}');
    }
  }

  @override
  Future<AuthUser?> getAppProfile(AuthUser user, {bool forceRefresh = false}) async {
    // If forceRefresh is true, skip cache and fetch fresh data
    if (!forceRefresh) {
      // Check cache first
      final cachedData = _cacheService.getCachedCurrentUserData();
      if (cachedData != null) {
        return AuthUser(
          id: cachedData['id'] as String,
          phone: cachedData['phone'] as String,
          email: cachedData['email'] as String?,
          name: cachedData['name'] as String?,
          role: cachedData['role'] as String?,
          contact: cachedData['contact'] as String?,
          approvalStatus: cachedData['approval_status'] as String?,
          isActive: cachedData['is_active'] == true,
        );
      }
    }

    // If not in cache OR forceRefresh=true, fetch from backend
    try {
      final token = _cacheService.getCachedAuthToken();
      if (token == null) {
        return null;
      }

      final response = await http.get(
        Uri.parse('$_backendBaseUrl/api/auth/user/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final userData = jsonDecode(response.body) as Map<String, dynamic>;

      // Cache the fresh data
      _cacheService.cacheCurrentUserData(userData);

      return AuthUser(
        id: userData['id'] as String,
        phone: userData['phone'] as String,
        email: userData['email'] as String?,
        name: userData['name'] as String?,
        role: userData['role'] as String?,
        contact: userData['contact'] as String?,
        approvalStatus: userData['approval_status'] as String?,
        isActive: userData['is_active'] == true,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<AuthUser> requestSignup({
    required AuthUser user,
    required String name,
    required String role,
    String? contact,
  }) async {
    try {
      final token = _cacheService.getCachedAuthToken();
      if (token == null) {
        throw AuthException('No authentication token');
      }

      final response = await http.post(
        Uri.parse('$_backendBaseUrl/auth/signup-request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': user.id,
          'name': name,
          'phone': user.phone,
          'role': role,
          'contact': contact,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException('Signup request failed: ${response.body}');
      }

      final userData = jsonDecode(response.body) as Map<String, dynamic>;

      return AuthUser(
        id: userData['id'] as String,
        phone: userData['phone'] as String,
        email: userData['email'] as String?,
        name: userData['name'] as String?,
        role: userData['role'] as String?,
        contact: userData['contact'] as String?,
        approvalStatus: userData['approval_status'] as String?,
        isActive: userData['is_active'] == true,
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to request signup: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // Clear all cached auth data
      _cacheService.invalidateAuthToken();
      _cacheService.invalidateRefreshToken();
      _cacheService.invalidateCurrentUserData();
      _cacheService.clearAll();

      // Emit unauthenticated state
      _authStateController.add(const Unauthenticated());
    } catch (e) {
      throw AuthException('Failed to sign out: ${e.toString()}');
    }
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    final token = _cacheService.getCachedAuthToken();
    if (token == null) return null;

    // Try to get from cache first
    final cachedData = _cacheService.getCachedCurrentUserData();
    if (cachedData != null) {
      return AuthUser(
        id: cachedData['id'] as String,
        phone: cachedData['phone'] as String,
        email: cachedData['email'] as String?,
        name: cachedData['name'] as String?,
        role: cachedData['role'] as String?,
        contact: cachedData['contact'] as String?,
        approvalStatus: cachedData['approval_status'] as String?,
        isActive: cachedData['is_active'] == true,
      );
    }

    return null;
  }

  @override
  Future<String?> getAccessToken() async {
    return _cacheService.getCachedAuthToken();
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = _cacheService.getCachedAuthToken();
    return token != null;
  }

  @override
  Stream<AuthState> authStateChanges() {
    return _authStateController.stream;
  }

  @override
  Future<void> refreshSession() async {
    // TODO: Implement token refresh if needed
    // For now, just check if token exists
    final token = _cacheService.getCachedAuthToken();
    if (token == null) {
      throw const AuthException('No active session');
    }
  }

  void dispose() {
    _authStateController.close();
  }
}

/// Exception thrown when user needs to complete signup
class SignupRequiredException implements Exception {
  const SignupRequiredException({
    required this.userId,
    required this.phone,
  });

  final String userId;
  final String phone;

  @override
  String toString() => 'SignupRequiredException: User $userId needs to complete signup';
}
