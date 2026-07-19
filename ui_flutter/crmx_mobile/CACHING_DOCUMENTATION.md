# Frontend Caching System Documentation

## Overview

This document describes the frontend caching implementation for the CRMX mobile application. The caching system is designed with clean architecture principles, proper separation of concerns, and centralized configuration.

## Architecture

### Layer Structure

```
┌─────────────────────────────────────────────┐
│           UI Layer (Screens)                │
│   - ClientListScreen                        │
│   - CreateClientScreen                      │
│   - ClientDetailScreen                      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│        Controller Layer (Riverpod)          │
│   - ClientController                        │
│   - AuthController                          │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│         Repository Layer                    │
│   - ClientRepository                        │
│   - AuthRepository                          │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│         Cache Service Layer                 │
│   - CacheService (domain-specific)          │
│   - Handles typed caching operations        │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│         Cache Manager Layer                 │
│   - CacheManager (singleton)                │
│   - Low-level cache operations              │
│   - TTL management                          │
└─────────────────────────────────────────────┘
```

## Core Components

### 1. CacheConfig (`lib/core/cache/cache_config.dart`)

Centralized configuration for all caching behavior.

**Purpose:** Single source of truth for all cache-related constants.

**Key Constants:**
- `assignableUsersTTL`: Duration(minutes: 5)
- `statusMasterTTL`: Duration(hours: 24)
- `currentUserTTL`: Duration(hours: 24)
- `clientListAutoRefreshInterval`: Duration(seconds: 30)
- `searchDebounce`: Duration(milliseconds: 500)

**Benefits:**
- Easy to adjust cache behavior globally
- All configuration in one place
- No magic numbers scattered in code

### 2. CacheManager (`lib/core/cache/cache_manager.dart`)

Low-level cache operations with TTL support.

**Purpose:** Generic, reusable caching mechanism.

**Key Methods:**
```dart
// Get data from cache
CacheResult<T> get<T>(String key)

// Set data in cache with TTL
void set<T>(String key, T data, {required Duration ttl})

// Check if cache has valid data
bool has(String key)

// Invalidate specific cache entry
void invalidate(String key)

// Clear all cache entries
void clearAll()

// Get cache statistics
CacheStats getStats()
```

**Features:**
- In-memory storage (fast access)
- TTL-based expiration
- Type-safe operations
- Debug logging (configurable)
- Cache statistics

### 3. CacheService (`lib/core/cache/cache_service.dart`)

High-level, domain-specific caching service.

**Purpose:** Provide typed, business-logic-aware caching methods.

**Key Methods:**

#### Assignable Users
```dart
Future<List<AssignableUser>> getAssignableUsers({bool forceRefresh = false})
void invalidateAssignableUsers()
```

#### Status Master
```dart
Future<List<StatusMaster>> getStatusMaster({bool forceRefresh = false})
void invalidateStatusMaster()
```

#### Current User
```dart
void cacheCurrentUser(AuthUser user)
AuthUser? getCachedCurrentUser()
void invalidateCurrentUser()
```

**Benefits:**
- Abstracts cache keys and TTL values
- Handles API calls automatically
- Type-safe return values
- Easy to mock for testing

### 4. CachedData Model (`lib/core/cache/cached_data.dart`)

Wrapper for cached data with metadata.

**Properties:**
- `data`: The actual cached data
- `cachedAt`: Timestamp when cached
- `validUntil`: Expiration timestamp
- `isValid`: Whether cache is still valid
- `age`: How old the cached data is

## Usage Examples

### Example 1: Using Cached Assignable Users

```dart
// In ClientRepository
Future<List<AssignableUser>> getAssignableUsers({
  bool forceRefresh = false,
}) async {
  return _cacheService.getAssignableUsers(forceRefresh: forceRefresh);
}

// In ClientController
Future<List<AssignableUser>> getAssignableUsers({
  bool forceRefresh = false,
}) async {
  return await _repository.getAssignableUsers(
    forceRefresh: forceRefresh,
  );
}

// In UI (CreateClientScreen)
final users = await ref
    .read(clientControllerProvider.notifier)
    .getAssignableUsers();
```

### Example 2: Using Cached Status Master

```dart
// In ClientRepository (loadDashboard)
final results = await Future.wait([
  _cacheService.getStatusMaster(), // Cached!
  _apiClient.get('/client-list'),
]);
```

### Example 3: Caching Current User

```dart
// In AuthController (_stateForUser)
final profile = await _authRepository.getAppProfile(user);
_cacheService.cacheCurrentUser(profile);
```

### Example 4: Clearing Cache on Logout

```dart
// In AuthController (signOut)
await _authRepository.signOut();
_cacheService.clearAll();
```

## Cache Invalidation Strategy

### When to Invalidate

1. **On Mutation Operations:**
   - After creating a new client
   - After updating assignable users
   - After user status changes

2. **On Logout:**
   - Clear all caches to prevent data leaks

3. **Manual Refresh:**
   - Pull-to-refresh gestures
   - Explicit refresh button clicks

### Example Invalidation

```dart
// In ClientRepository (createClient)
Future<ClientInfo> createClient(Map<String, dynamic> clientData) async {
  final response = await _apiClient.post('/client', body: clientData);
  
  // Invalidate related caches
  _cacheService.invalidateAssignableUsers();
  
  return ClientInfo.fromJson(response as Map<String, dynamic>);
}
```

## Auto-Refresh Feature

The client list supports automatic background refresh.

### Implementation

```dart
// In ClientController
Timer? _autoRefreshTimer;

void startAutoRefresh() {
  _autoRefreshTimer?.cancel();
  _autoRefreshTimer = Timer.periodic(
    CacheConfig.clientListAutoRefreshInterval,
    (_) => loadDashboard(silent: true), // Silent refresh
  );
}

void stopAutoRefresh() {
  _autoRefreshTimer?.cancel();
}
```

### Usage

```dart
// In ClientListScreen
@override
void initState() {
  super.initState();
  ref.read(clientControllerProvider.notifier).startAutoRefresh();
}

@override
void dispose() {
  ref.read(clientControllerProvider.notifier).stopAutoRefresh();
  super.dispose();
}
```

## Configuration Management

### Adjusting Cache Behavior

All cache behavior is controlled via `CacheConfig`. To adjust:

1. **Change TTL Duration:**
   ```dart
   // In cache_config.dart
   static const Duration assignableUsersTTL = Duration(minutes: 10); // Was 5
   ```

2. **Change Auto-Refresh Interval:**
   ```dart
   // In cache_config.dart
   static const Duration clientListAutoRefreshInterval = Duration(minutes: 1);
   ```

3. **Enable/Disable Logging:**
   ```dart
   // In cache_config.dart
   static const bool enableCacheLogging = false; // Disable in production
   ```

## Cache Flow Diagrams

### Flow 1: First Request (Cache Miss)

```
UI Request → Controller → Repository → CacheService
                                            ↓
                                       Cache Miss
                                            ↓
                                        API Call
                                            ↓
                                    Store in Cache
                                            ↓
                                    Return to UI
```

### Flow 2: Subsequent Request (Cache Hit)

```
UI Request → Controller → Repository → CacheService
                                            ↓
                                       Cache Hit
                                            ↓
                                    Return from Cache
                                            ↓
                                    Return to UI
```

### Flow 3: Force Refresh

```
UI Request (forceRefresh: true)
     ↓
Controller → Repository → CacheService
                              ↓
                         Bypass Cache
                              ↓
                          API Call
                              ↓
                      Update Cache
                              ↓
                      Return to UI
```

## Benefits of This Architecture

### 1. Separation of Concerns
- **CacheManager:** Generic caching mechanism
- **CacheService:** Domain-specific caching
- **Repository:** Data access logic
- **Controller:** Business logic

### 2. Centralized Configuration
- All cache settings in one file
- Easy to adjust behavior
- No scattered magic numbers

### 3. Type Safety
- Generic types throughout
- Compile-time type checking
- Auto-completion support

### 4. Testability
- Easy to mock `CacheService`
- Can inject fake cache for tests
- Clear interfaces

### 5. Performance
- In-memory storage (fast)
- Reduces API calls
- Improves UX

### 6. Maintainability
- Clear code organization
- Easy to extend
- Self-documenting

## Testing Cache

### Unit Testing

```dart
test('CacheManager stores and retrieves data', () {
  final cache = CacheManager.instance;
  cache.clearAll();
  
  cache.set('test_key', 'test_value', ttl: Duration(minutes: 5));
  
  final result = cache.get<String>('test_key');
  expect(result.isHit, true);
  expect(result.data, 'test_value');
});

test('Cache expires after TTL', () async {
  final cache = CacheManager.instance;
  cache.clearAll();
  
  cache.set('test_key', 'test_value', ttl: Duration(milliseconds: 100));
  
  await Future.delayed(Duration(milliseconds: 150));
  
  final result = cache.get<String>('test_key');
  expect(result.isStale, true);
});
```

### Integration Testing

```dart
testWidgets('Assignable users are cached', (tester) async {
  // First load
  final users1 = await cacheService.getAssignableUsers();
  
  // Second load (should hit cache)
  final users2 = await cacheService.getAssignableUsers();
  
  expect(users1, equals(users2));
  // Verify only one API call was made
});
```

## Monitoring Cache Performance

### Getting Cache Statistics

```dart
final stats = CacheManager.instance.getStats();
print(stats); // CacheStats(total: 5, valid: 3, expired: 2)
```

### Debug Logging

When `CacheConfig.enableCacheLogging` is true:

```
[CacheManager] SET: cache:assignable_users (ttl: 5m)
[CacheManager] HIT: cache:assignable_users (32s old)
[CacheManager] MISS: cache:status_master (not found)
[CacheManager] STALE: cache:current_user (expired 15m ago)
[CacheManager] INVALIDATE: cache:assignable_users
[CacheManager] CLEAR ALL
```

## Best Practices

### DO:
✅ Use `CacheService` methods instead of direct `CacheManager` access
✅ Configure TTL based on data change frequency
✅ Invalidate cache after mutations
✅ Clear cache on logout
✅ Use `forceRefresh` for pull-to-refresh

### DON'T:
❌ Don't bypass CacheService to use CacheManager directly
❌ Don't use magic numbers for TTL
❌ Don't forget to invalidate cache after updates
❌ Don't cache sensitive data longer than necessary
❌ Don't ignore cache misses in error handling

## Future Enhancements

### Potential Improvements

1. **Persistent Cache:**
   - Store cache to disk using SharedPreferences
   - Survive app restarts

2. **Cache Warming:**
   - Pre-load commonly used data
   - Background cache refresh

3. **Adaptive TTL:**
   - Adjust TTL based on data staleness
   - Server-driven cache control

4. **Cache Size Limits:**
   - Implement LRU eviction
   - Prevent memory bloat

5. **Offline Support:**
   - Serve stale data when offline
   - Queue mutations for later

## Troubleshooting

### Issue: Cache Not Updating

**Symptom:** Old data displayed after mutation

**Solution:** Ensure cache invalidation after mutations
```dart
await _repository.updateClient(data);
_cacheService.invalidateAssignableUsers();
```

### Issue: Memory Usage High

**Symptom:** App using too much memory

**Solution:** Reduce TTL or implement cache size limits
```dart
// In cache_config.dart
static const Duration assignableUsersTTL = Duration(minutes: 2); // Reduced
```

### Issue: Stale Data Displayed

**Symptom:** User sees outdated information

**Solution:** Lower TTL or implement auto-refresh
```dart
// In cache_config.dart
static const Duration statusMasterTTL = Duration(hours: 1); // Was 24
```

## Summary

The CRMX caching system provides:
- **Clean Architecture:** Separation of concerns across layers
- **Centralized Config:** Single source for all cache settings
- **Type Safety:** Generic, compile-time checked operations
- **Performance:** Fast in-memory caching with TTL
- **Maintainability:** Clear, well-documented code

All cache configuration is in `lib/core/cache/cache_config.dart` for easy management.
