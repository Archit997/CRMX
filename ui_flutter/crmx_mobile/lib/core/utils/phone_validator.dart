import '../config/app_config.dart';

class PhoneValidator {
  /// Validates phone number in E.164 format
  /// Example: +919876543210, +14155552671
  static bool isValid(String phone) {
    if (phone.isEmpty) return false;

    final regex = RegExp(AppConfig.phoneRegex);
    return regex.hasMatch(phone);
  }

  /// Formats phone number by removing spaces and special characters.
  /// Plain 10-digit mobile numbers are treated as Indian numbers.
  static String format(String phone) {
    if (phone.isEmpty) return phone;

    // Remove all spaces and dashes
    var formatted = phone.replaceAll(RegExp(r'[\s\-()]'), '');

    if (RegExp(r'^[6-9]\d{9}$').hasMatch(formatted)) {
      return '+91$formatted';
    }

    // Ensure it starts with +
    if (!formatted.startsWith('+')) {
      formatted = '+$formatted';
    }

    return formatted;
  }

  /// Validates and formats phone number
  /// Returns null if invalid, formatted string if valid
  static String? validateAndFormat(String phone) {
    final formatted = format(phone);
    return isValid(formatted) ? formatted : null;
  }

  /// Get validation error message
  static String? getErrorMessage(String phone) {
    if (phone.isEmpty) {
      return 'Phone number is required';
    }

    if (!phone.startsWith('+')) {
      return 'Phone number must start with + and country code';
    }

    if (!isValid(phone)) {
      return 'Invalid phone number format. Use E.164 format (e.g., +919876543210)';
    }

    return null;
  }
}
