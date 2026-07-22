import '../../features/auth/domain/auth_user.dart';
import '../../src/models/crmx_models.dart';
import '../../services/api/api_client.dart';
import 'cache_config.dart';
import 'cache_manager.dart';

/// High-level cache service for application data
///
/// This service provides typed, domain-specific caching methods
/// and encapsulates API calls with caching logic.
///
/// Separation of concerns:
/// - CacheManager: Low-level cache operations
/// - CacheService: High-level domain-specific caching
/// - Repository: Data fetching logic
class CacheService {
  CacheService(this._apiClient);

  final ApiClient _apiClient;
  final _cache = CacheManager.instance;

  // ==========================================================================
  // Authentication Token & User Data
  // ==========================================================================

  /// Cache authentication token
  void cacheAuthToken(String token) {
    _cache.set(
      CacheConfig.authTokenKey,
      token,
      ttl: CacheConfig.authTokenTTL,
    );
  }

  /// Get cached authentication token
  String? getCachedAuthToken() {
    final cached = _cache.get<String>(CacheConfig.authTokenKey);
    return cached.isHit ? cached.data : null;
  }

  /// Cache refresh token
  void cacheRefreshToken(String refreshToken) {
    _cache.set(
      CacheConfig.authRefreshTokenKey,
      refreshToken,
      ttl: CacheConfig.authTokenTTL,
    );
  }

  /// Get cached refresh token
  String? getCachedRefreshToken() {
    final cached = _cache.get<String>(CacheConfig.authRefreshTokenKey);
    return cached.isHit ? cached.data : null;
  }

  /// Cache current user data
  void cacheCurrentUserData(Map<String, dynamic> userData) {
    _cache.set(
      CacheConfig.currentUserDataKey,
      userData,
      ttl: CacheConfig.currentUserDataTTL,
    );
  }

  /// Get cached current user data
  Map<String, dynamic>? getCachedCurrentUserData() {
    final cached = _cache.get<Map<String, dynamic>>(
      CacheConfig.currentUserDataKey,
    );
    return cached.isHit ? cached.data : null;
  }

  /// Invalidate auth token cache
  void invalidateAuthToken() {
    _cache.invalidate(CacheConfig.authTokenKey);
  }

  /// Invalidate refresh token cache
  void invalidateRefreshToken() {
    _cache.invalidate(CacheConfig.authRefreshTokenKey);
  }

  /// Invalidate current user data cache
  void invalidateCurrentUserData() {
    _cache.invalidate(CacheConfig.currentUserDataKey);
  }

  // ==========================================================================
  // Assignable Users
  // ==========================================================================

  /// Get assignable users with caching
  ///
  /// Fetches from API only if cache is expired or [forceRefresh] is true
  Future<List<AssignableUser>> getAssignableUsers({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<AssignableUser>>(
        CacheConfig.assignableUsersKey,
      );
      if (cached.isHit) {
        return cached.data!;
      }
    }

    // Fetch from API
    final response = await _apiClient.get('/users/assignable');
    final users = (response as List<dynamic>)
        .map((item) => AssignableUser.fromJson(item as Map<String, dynamic>))
        .toList();

    // Cache the result
    _cache.set(
      CacheConfig.assignableUsersKey,
      users,
      ttl: CacheConfig.assignableUsersTTL,
    );

    return users;
  }

  /// Invalidate assignable users cache
  void invalidateAssignableUsers() {
    _cache.invalidate(CacheConfig.assignableUsersKey);
  }

  // ==========================================================================
  // Status Master
  // ==========================================================================

  /// Get status master list with caching
  ///
  /// Statuses rarely change, so we cache for longer duration
  Future<List<StatusMaster>> getStatusMaster({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<StatusMaster>>(
        CacheConfig.statusMasterKey,
      );
      if (cached.isHit) {
        return cached.data!;
      }
    }

    // Fetch from API
    final response = await _apiClient.get('/master-status');
    final statuses = (response as List<dynamic>)
        .map((item) => StatusMaster.fromJson(item as Map<String, dynamic>))
        .toList();

    // Cache the result
    _cache.set(
      CacheConfig.statusMasterKey,
      statuses,
      ttl: CacheConfig.statusMasterTTL,
    );

    return statuses;
  }

  /// Invalidate status master cache
  void invalidateStatusMaster() {
    _cache.invalidate(CacheConfig.statusMasterKey);
  }

  // ==========================================================================
  // Status Master
  // ==========================================================================

  /// Clear all caches (e.g., on logout)
  void clearAll() {
    _cache.clearAll();
  }

  /// Cleanup expired cache entries
  void cleanup() {
    _cache.cleanupExpired();
  }

  /// Get cache statistics
  CacheStats getStats() {
    return _cache.getStats();
  }
}

/// Assignable user model
class AssignableUser {
  const AssignableUser({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory AssignableUser.fromJson(Map<String, dynamic> json) {
    return AssignableUser(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  @override
  String toString() => 'AssignableUser(id: $id, name: $name)';
}
