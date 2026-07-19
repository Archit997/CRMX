import 'cache_config.dart';
import 'cached_data.dart';

/// In-memory cache manager with TTL support
///
/// This class provides a centralized caching layer for the application.
/// All caching logic is contained here to avoid code duplication.
///
/// Usage:
/// ```dart
/// final cache = CacheManager.instance;
/// await cache.set('key', data, ttl: Duration(minutes: 5));
/// final result = cache.get<DataType>('key');
/// ```
class CacheManager {
  CacheManager._();

  static final CacheManager _instance = CacheManager._();
  static CacheManager get instance => _instance;

  // Internal cache storage
  final Map<String, CachedData<dynamic>> _cache = {};

  /// Get data from cache
  ///
  /// Returns CacheResult with status indicating hit/miss/stale
  CacheResult<T> get<T>(String key) {
    final entry = _cache[key];

    if (entry == null) {
      _log('MISS: $key (not found)');
      return CacheResult<T>(status: CacheStatus.miss);
    }

    if (entry.isExpired) {
      _log('STALE: $key (expired ${entry.age.inMinutes}m ago)');
      return CacheResult<T>(
        status: CacheStatus.stale,
        data: entry.data as T,
      );
    }

    _log('HIT: $key (${entry.age.inSeconds}s old)');
    return CacheResult<T>(
      status: CacheStatus.hit,
      data: entry.data as T,
    );
  }

  /// Set data in cache with TTL
  ///
  /// [key] Cache key
  /// [data] Data to cache
  /// [ttl] Time-to-live duration
  void set<T>(String key, T data, {required Duration ttl}) {
    final now = DateTime.now();
    _cache[key] = CachedData<T>(
      data: data,
      cachedAt: now,
      validUntil: now.add(ttl),
    );
    _log('SET: $key (ttl: ${ttl.inMinutes}m)');
  }

  /// Check if cache has valid data for key
  bool has(String key) {
    final entry = _cache[key];
    return entry != null && entry.isValid;
  }

  /// Invalidate (remove) cache entry
  void invalidate(String key) {
    _cache.remove(key);
    _log('INVALIDATE: $key');
  }

  /// Clear all cache entries
  void clearAll() {
    _cache.clear();
    _log('CLEAR ALL');
  }

  /// Clear all expired entries
  void cleanupExpired() {
    final expiredKeys = _cache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _cache.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      _log('CLEANUP: Removed ${expiredKeys.length} expired entries');
    }
  }

  /// Get cache statistics
  CacheStats getStats() {
    final total = _cache.length;
    final expired = _cache.values.where((entry) => entry.isExpired).length;
    final valid = total - expired;

    return CacheStats(
      totalEntries: total,
      validEntries: valid,
      expiredEntries: expired,
    );
  }

  // Debug logging
  void _log(String message) {
    if (CacheConfig.enableCacheLogging) {
      print('[CacheManager] $message');
    }
  }
}

/// Cache statistics
class CacheStats {
  const CacheStats({
    required this.totalEntries,
    required this.validEntries,
    required this.expiredEntries,
  });

  final int totalEntries;
  final int validEntries;
  final int expiredEntries;

  @override
  String toString() {
    return 'CacheStats(total: $totalEntries, valid: $validEntries, expired: $expiredEntries)';
  }
}
