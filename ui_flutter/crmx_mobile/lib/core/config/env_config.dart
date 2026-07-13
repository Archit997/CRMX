import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment variables utility
/// Loads variables from .env file using flutter_dotenv
class EnvConfig {
  /// Load environment variables from .env file
  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
  }

  /// Get environment variable with optional default value
  static String get(String key, {String defaultValue = ''}) {
    return dotenv.get(key, fallback: defaultValue);
  }

  /// Check if environment variable exists
  static bool has(String key) {
    return dotenv.env.containsKey(key);
  }

  /// Get all environment variables
  static Map<String, String> get all => dotenv.env;

  // ============================================================================
  // Convenience getters for common environment variables
  // ============================================================================

  /// Supabase Project URL
  static String get supabaseUrl => get('SUPABASE_URL');

  /// Supabase Anon/Public Key
  static String get supabaseAnonKey => get('SUPABASE_ANON_KEY');

  /// Backend API Base URL
  static String get backendApiBase => get(
        'BACKEND_API_BASE',
        defaultValue: 'http://127.0.0.1:8000',
      );

  /// App Environment (development, staging, production)
  static String get appEnv => get('APP_ENV', defaultValue: 'development');

  /// Whether the app is in development mode
  static bool get isDevelopment => appEnv == 'development';

  /// Whether the app is in production mode
  static bool get isProduction => appEnv == 'production';

  /// Validate required environment variables
  static void validate() {
    final required = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'];
    final missing = <String>[];

    for (final key in required) {
      if (!has(key) || get(key).isEmpty) {
        missing.add(key);
      }
    }

    if (missing.isNotEmpty) {
      throw Exception(
        'Missing required environment variables: ${missing.join(", ")}\n'
        'Please check your .env file and ensure all required variables are set.',
      );
    }
  }
}
