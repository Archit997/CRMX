import 'auth_user.dart';

/// Base auth state
sealed class AuthState {
  const AuthState();
}

/// Initial/unauthenticated state
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// OTP sent successfully
class OtpSent extends AuthState {
  const OtpSent(this.phoneNumber);
  
  final String phoneNumber;
}

/// Authentication in progress
class Authenticating extends AuthState {
  const Authenticating();
}

/// Successfully authenticated
class Authenticated extends AuthState {
  const Authenticated(this.user);
  
  final AuthUser user;
}

/// Authentication error
class AuthError extends AuthState {
  const AuthError(this.message, [this.code]);
  
  final String message;
  final String? code;
}

/// Session expired
class SessionExpired extends AuthState {
  const SessionExpired();
}
