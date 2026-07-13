import 'env_config.dart';

class AppConfig {
  // Backend API Configuration (loaded from .env)
  static String get backendBaseUrl => EnvConfig.backendApiBase;

  // App Configuration
  static const String appName = 'CRMX';
  static const String appVersion = '0.1.0';

  // API Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 15);

  // Pagination
  static const int defaultPageSize = 20;

  // Phone Validation
  static const String phoneRegex = r'^\+[1-9]\d{1,14}$'; // E.164 format

  // OTP Configuration
  static const int otpLength = 6;
  static const Duration otpResendDelay = Duration(seconds: 60);
}
