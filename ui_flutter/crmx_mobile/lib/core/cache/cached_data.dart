/// Cached data wrapper with metadata
class CachedData<T> {
  CachedData({
    required this.data,
    required this.cachedAt,
    required this.validUntil,
  });

  final T data;
  final DateTime cachedAt;
  final DateTime validUntil;

  /// Check if cache is still valid
  bool get isValid => DateTime.now().isBefore(validUntil);

  /// Check if cache has expired
  bool get isExpired => !isValid;

  /// Age of cached data
  Duration get age => DateTime.now().difference(cachedAt);
}

/// Cache entry status
enum CacheStatus {
  /// Cache hit - data is valid
  hit,

  /// Cache miss - no data or expired
  miss,

  /// Cache stale - data exists but expired
  stale,
}

/// Result of cache operation with status
class CacheResult<T> {
  CacheResult({
    required this.status,
    this.data,
  });

  final CacheStatus status;
  final T? data;

  bool get isHit => status == CacheStatus.hit;
  bool get isMiss => status == CacheStatus.miss;
  bool get isStale => status == CacheStatus.stale;
}
