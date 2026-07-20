import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../core/config/app_config.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/auth_state.dart';
import '../domain/auth_user.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository() {
    _authStateController = StreamController<AuthState>.broadcast();
    _listenToAuthChanges();
  }

  late final StreamController<AuthState> _authStateController;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  supabase.GoTrueClient get _auth => SupabaseConfig.auth;
  String get _backendBaseUrl => AppConfig.backendBaseUrl;

  @override
  Future<void> sendOtp(String phoneNumber) async {
    try {
      await _auth.signInWithOtp(
        phone: phoneNumber,
        shouldCreateUser: true,
      );
    } on supabase.AuthException catch (e) {
      throw AuthException('OTP request failed: ${e.message}');
    } catch (e) {
      throw AuthException('Failed to send OTP: ${e.toString()}');
    }
  }

  @override
  Future<AuthUser> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final response = await _auth.verifyOTP(
        phone: phoneNumber,
        token: otp,
        type: supabase.OtpType.sms,
      );

      if (response.user == null) {
        throw const AuthException('Verification failed: No user returned');
      }

      return _mapSupabaseUserToAuthUser(response.user!);
    } on supabase.AuthException catch (e) {
      throw AuthException('OTP verification failed: ${e.message}');
    } catch (e) {
      throw AuthException('Failed to verify OTP: ${e.toString()}');
    }
  }

  @override
  Future<AuthUser?> getAppProfile(AuthUser user, {bool forceRefresh = false}) async {
    try {
      final response = await http.get(
        Uri.parse('$_backendBaseUrl/auth/profile/${user.id}'),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        throw AuthException('Failed to fetch profile: ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['exists'] != true) {
        return null;
      }

      return _mergeProfile(user, body);
    } catch (e) {
      throw AuthException('Failed to fetch profile: ${e.toString()}');
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
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/auth/signup-request'),
        headers: await _headers(),
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

      return _mergeProfile(
          user, jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      throw AuthException('Failed to request signup: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthException('Failed to sign out: ${e.toString()}');
    }
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      return _mapSupabaseUserToAuthUser(user);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      final session = _auth.currentSession;
      return session?.accessToken;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      final session = _auth.currentSession;
      return session != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<AuthState> authStateChanges() {
    return _authStateController.stream;
  }

  @override
  Future<void> refreshSession() async {
    try {
      final response = await _auth.refreshSession();
      if (response.session == null) {
        throw const AuthException('Failed to refresh session');
      }
    } catch (e) {
      throw AuthException('Failed to refresh session: ${e.toString()}');
    }
  }

  /// Listen to Supabase auth changes and emit app-level auth states
  void _listenToAuthChanges() {
    _authSubscription = _auth.onAuthStateChange.listen((data) {
      final event = data.event;

      switch (event) {
        case supabase.AuthChangeEvent.signedIn:
          break;

        case supabase.AuthChangeEvent.signedOut:
          _authStateController.add(const Unauthenticated());
          break;

        case supabase.AuthChangeEvent.tokenRefreshed:
          break;

        case supabase.AuthChangeEvent.userUpdated:
          break;

        default:
          break;
      }
    });
  }

  /// Map Supabase User to AuthUser
  AuthUser _mapSupabaseUserToAuthUser(supabase.User user) {
    return AuthUser(
      id: user.id,
      phone: user.phone ?? '',
      email: user.email,
      createdAt: DateTime.parse(user.createdAt),
    );
  }

  AuthUser _mergeProfile(AuthUser user, Map<String, dynamic> profile) {
    return user.copyWith(
      phone: (profile['phone'] ?? user.phone) as String,
      name: profile['name'] as String?,
      role: profile['role'] as String?,
      contact: profile['contact'] as String?,
      approvalStatus: profile['approval_status'] as String?,
      isActive: profile['is_active'] == true,
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = _auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Dispose resources
  void dispose() {
    _authSubscription?.cancel();
    _authStateController.close();
  }
}
