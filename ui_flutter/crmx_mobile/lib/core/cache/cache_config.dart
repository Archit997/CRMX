/// Cache configuration constants
///
/// This file contains all caching-related configuration values.
/// Centralized location for easy maintenance and updates.
class CacheConfig {
  CacheConfig._();

  // ============================================================================
  // TTL (Time To Live) Durations
  // ============================================================================

  /// How long to cache assignable users list
  /// Users change infrequently, safe to cache for 5 minutes
  static const Duration assignableUsersTTL = Duration(minutes: 5);

  /// How long to cache status master list
  /// Statuses rarely change, can be cached for the entire session
  static const Duration statusMasterTTL = Duration(hours: 24);

  /// How long to cache current user profile
  /// User profile doesn't change during session
  static const Duration currentUserTTL = Duration(hours: 24);

  // ============================================================================
  // Auto-Refresh Intervals
  // ============================================================================

  /// Auto-refresh interval for client list (when screen is active)
  /// Keeps data fresh without user intervention
  static const Duration clientListAutoRefreshInterval = Duration(seconds: 30);

  /// Debounce duration for search
  /// Prevents excessive API calls while user is typing
  static const Duration searchDebounce = Duration(milliseconds: 500);

  // ============================================================================
  // Cache Keys
  // ============================================================================

  static const String assignableUsersKey = 'cache:assignable_users';
  static const String statusMasterKey = 'cache:status_master';
  static const String currentUserKey = 'cache:current_user';

  // ============================================================================
  // Cache Behavior Flags
  // ============================================================================

  /// Enable debug logging for cache operations
  static const bool enableCacheLogging = true;

  /// Clear all caches on app logout
  static const bool clearCachesOnLogout = true;

  /// Automatically retry failed cache operations
  static const bool autoRetryFailedCache = false;
}
