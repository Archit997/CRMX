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
  // Current User
  // ==========================================================================

  /// Cache current user profile
  void cacheCurrentUser(AuthUser user) {
    _cache.set(
      CacheConfig.currentUserKey,
      user,
      ttl: CacheConfig.currentUserTTL,
    );
  }

  /// Get cached current user
  AuthUser? getCachedCurrentUser() {
    final cached = _cache.get<AuthUser>(CacheConfig.currentUserKey);
    return cached.isHit ? cached.data : null;
  }

  /// Invalidate current user cache
  void invalidateCurrentUser() {
    _cache.invalidate(CacheConfig.currentUserKey);
  }

  // ==========================================================================
  // Cache Management
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
