/// Base exception class for all app exceptions
abstract class AppException implements Exception {
  const AppException(this.message, [this.code]);

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException([super.message = 'Network error occurred']);
}

/// Authentication exceptions
class AuthException extends AppException {
  const AuthException(super.message, [super.code]);
}

/// API exceptions
class ApiException extends AppException {
  const ApiException(
    String message, {
    this.statusCode,
    String? code,
  }) : super(message, code);

  final int? statusCode;
}

/// Unauthorized exception (401)
class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Unauthorized'])
      : super(statusCode: 401);
}

/// Not found exception (404)
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Resource not found'])
      : super(statusCode: 404);
}

/// Server exception (500+)
class ServerException extends ApiException {
  const ServerException([super.message = 'Server error'])
      : super(statusCode: 500);
}

/// Validation exception
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Session expired exception
class SessionExpiredException extends AuthException {
  const SessionExpiredException([String message = 'Session expired'])
      : super(message, 'session_expired');
}
