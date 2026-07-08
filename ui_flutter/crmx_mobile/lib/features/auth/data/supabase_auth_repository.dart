import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
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

  @override
  Future<void> sendOtp(String phoneNumber) async {
    try {
      await _auth.signInWithOtp(
        phone: phoneNumber,
        shouldCreateUser: true,
      );
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
    } catch (e) {
      throw AuthException('Failed to verify OTP: ${e.toString()}');
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
      final session = data.session;

      switch (event) {
        case supabase.AuthChangeEvent.signedIn:
          if (session?.user != null) {
            final user = _mapSupabaseUserToAuthUser(session!.user);
            _authStateController.add(Authenticated(user));
          }
          break;

        case supabase.AuthChangeEvent.signedOut:
          _authStateController.add(const Unauthenticated());
          break;

        case supabase.AuthChangeEvent.tokenRefreshed:
          if (session?.user != null) {
            final user = _mapSupabaseUserToAuthUser(session!.user);
            _authStateController.add(Authenticated(user));
          }
          break;

        case supabase.AuthChangeEvent.userUpdated:
          if (session?.user != null) {
            final user = _mapSupabaseUserToAuthUser(session!.user);
            _authStateController.add(Authenticated(user));
          }
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
      createdAt: user.createdAt != null
          ? DateTime.parse(user.createdAt!)
          : null,
    );
  }

  /// Dispose resources
  void dispose() {
    _authSubscription?.cancel();
    _authStateController.close();
  }
}
