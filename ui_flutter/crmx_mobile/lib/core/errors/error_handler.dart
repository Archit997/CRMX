import 'dart:io';
import 'package:http/http.dart' as http;
import 'app_exception.dart';

/// Utility class to convert technical errors into user-friendly messages
class ErrorHandler {
  /// Convert any exception to a user-friendly error message
  static String getUserFriendlyMessage(dynamic error) {
    // Handle app-specific exceptions
    if (error is AppException) {
      return _handleAppException(error);
    }

    // Handle HTTP exceptions
    if (error is http.ClientException) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }

    // Handle socket exceptions (network issues)
    if (error is SocketException) {
      return 'No internet connection. Please check your network settings.';
    }

    // Handle timeout exceptions
    if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    }

    // Handle format exceptions
    if (error is FormatException) {
      return 'Unable to process the response. Please try again later.';
    }

    // Generic error fallback
    return 'Something went wrong. Please try again.';
  }

  /// Handle app-specific exceptions with detailed user-friendly messages
  static String _handleAppException(AppException exception) {
    if (exception is UnauthorizedException) {
      return 'Your session has expired. Please log in again.';
    }

    if (exception is SessionExpiredException) {
      return 'Your session has expired. Please log in again.';
    }

    if (exception is AuthException) {
      // Check for specific auth messages from backend
      final message = exception.message.toLowerCase();
      if (message.contains('not approved')) {
        return 'Your account is pending approval. Please contact an administrator.';
      }
      if (message.contains('inactive')) {
        return 'Your account has been deactivated. Please contact support.';
      }
      if (message.contains('token')) {
        return 'Your session has expired. Please log in again.';
      }
      return 'Authentication failed. Please try logging in again.';
    }

    if (exception is NotFoundException) {
      return 'The requested item was not found. It may have been deleted.';
    }

    if (exception is ServerException) {
      return 'Server error occurred. Please try again later.';
    }

    if (exception is ValidationException) {
      // Return the validation message as-is (it's usually user-friendly)
      return exception.message;
    }

    if (exception is NetworkException) {
      return 'Network error. Please check your connection and try again.';
    }

    if (exception is ApiException) {
      // Check for specific status codes
      switch (exception.statusCode) {
        case 400:
          return _cleanBackendMessage(exception.message, 
              fallback: 'Invalid request. Please check your input and try again.');
        case 403:
          return 'You do not have permission to perform this action.';
        case 404:
          return 'The requested item was not found.';
        case 409:
          return _cleanBackendMessage(exception.message,
              fallback: 'This action conflicts with existing data.');
        case 422:
          return _cleanBackendMessage(exception.message,
              fallback: 'Invalid data provided. Please check your input.');
        case 429:
          return 'Too many requests. Please wait a moment and try again.';
        case 500:
        case 502:
        case 503:
        case 504:
          return 'Server error. Please try again later.';
        default:
          return _cleanBackendMessage(exception.message,
              fallback: 'An error occurred. Please try again.');
      }
    }

    // Return the exception message if it's user-friendly enough
    return _cleanBackendMessage(exception.message,
        fallback: 'An error occurred. Please try again.');
  }

  /// Clean backend error messages to make them more user-friendly
  static String _cleanBackendMessage(String message, {required String fallback}) {
    // If message is empty or too technical, use fallback
    if (message.isEmpty) {
      return fallback;
    }

    final lowerMessage = message.toLowerCase();

    // Technical error patterns that should use fallback
    final technicalPatterns = [
      'exception',
      'error:',
      'traceback',
      'stack trace',
      'null pointer',
      'undefined',
      'syntax error',
      'parse error',
      'internal error',
    ];

    for (final pattern in technicalPatterns) {
      if (lowerMessage.contains(pattern)) {
        return fallback;
      }
    }

    // Clean up common backend message patterns
    String cleaned = message;

    // Remove "detail:" prefix if present
    if (cleaned.toLowerCase().startsWith('detail:')) {
      cleaned = cleaned.substring(7).trim();
    }

    // Capitalize first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    // Ensure it ends with punctuation
    if (cleaned.isNotEmpty && 
        !cleaned.endsWith('.') && 
        !cleaned.endsWith('!') && 
        !cleaned.endsWith('?')) {
      cleaned += '.';
    }

    return cleaned.isNotEmpty ? cleaned : fallback;
  }

  /// Get a user-friendly message for common operations
  static String getOperationError(String operation, dynamic error) {
    final baseMessage = getUserFriendlyMessage(error);
    
    switch (operation.toLowerCase()) {
      case 'load':
      case 'fetch':
        return 'Unable to load data. $baseMessage';
      case 'create':
      case 'add':
        return 'Unable to create item. $baseMessage';
      case 'update':
      case 'save':
        return 'Unable to save changes. $baseMessage';
      case 'delete':
      case 'remove':
        return 'Unable to delete item. $baseMessage';
      case 'login':
      case 'signin':
        return 'Unable to log in. $baseMessage';
      case 'signup':
      case 'register':
        return 'Unable to complete registration. $baseMessage';
      default:
        return baseMessage;
    }
  }
}

/// Timeout exception class
class TimeoutException implements Exception {
  const TimeoutException([this.message = 'Operation timed out']);
  final String message;

  @override
  String toString() => message;
}
