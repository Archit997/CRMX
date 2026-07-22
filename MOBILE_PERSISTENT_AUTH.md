# Mobile Persistent Authentication Guide

## Overview

This document explains how the CRMX mobile app (Flutter) maintains persistent user sessions across app launches, ensuring users don't need to log in repeatedly on Android and iOS.

## Architecture

### Token-Based Authentication

We use a **dual-token system** (access token + refresh token) similar to OAuth 2.0:

1. **Access Token**: Short-lived (default: 1 hour)
   - Used for API authentication
   - Included in `Authorization: Bearer <token>` header
   - Validated by backend using Supabase JWKS

2. **Refresh Token**: Long-lived (default: 7 days)
   - Used to obtain new access tokens
   - Stored securely in cache
   - Rotated on each refresh for security

---

## How Persistent Login Works

### 1. Initial Login Flow

```
User enters phone → OTP sent → OTP verified → Backend returns:
{
  "token": "access_token_xyz",
  "refresh_token": "refresh_token_abc",
  "expires_in": 3600
}
```

**Frontend Action:**
- Caches both tokens in memory using `CacheService`
- Token TTL: 10 minutes (configurable in `CacheConfig`)
- User redirected to main app

### 2. App Restart/Reopen

When user reopens the app:

```dart
// auth_controller.dart checks cache
final cachedToken = _cacheService.getCachedAuthToken();
final cachedRefreshToken = _cacheService.getCachedRefreshToken();

if (cachedToken != null && cachedRefreshToken != null) {
  // User is logged in, validate and restore session
  final userData = await _cacheService.getCachedCurrentUserData();
  state = Authenticated(user);
}
```

**Important:** If the access token is expired but refresh token is still valid, the app automatically refreshes it (see below).

### 3. Automatic Token Refresh

When an API call returns `401 Unauthorized`, the `ApiClient` automatically:

```dart
// api_client.dart (automatic retry with token refresh)
catch (e) {
  if (e is UnauthorizedException && !_isRefreshing) {
    _isRefreshing = true;
    
    // Call refresh endpoint
    await refreshTokenCallback!(); // Calls /api/auth/refresh
    
    // Retry original request with new token
    return _handleResponse(retryResponse);
  }
}
```

**Backend Endpoint:** `POST /api/auth/refresh`

```python
# services/auth/controller.py
@router.post("/refresh")
async def refresh_token(payload: RefreshTokenRequest):
    result = await auth_service.refresh_access_token(payload.refresh_token)
    return {
        "token": "new_access_token",
        "refresh_token": "new_refresh_token",
        "expires_in": 3600
    }
```

**Frontend Updates Cache:**
```dart
// backend_auth_repository.dart
_cacheService.cacheAuthToken(newToken);
_cacheService.cacheRefreshToken(newRefreshToken);
```

---

## Mobile Platform Specifics

### Android

**In-Memory Cache:**
- Our current implementation uses in-memory caching (`CacheManager`)
- **Limitation:** Cache is cleared when app process is killed by OS
- **Solution:** Consider persistent storage (see recommendations below)

**Recommended for Production:**

Use `flutter_secure_storage` for persistent, encrypted token storage:

```dart
// Install: flutter pub add flutter_secure_storage

final storage = FlutterSecureStorage();

// Save
await storage.write(key: 'auth_token', value: token);
await storage.write(key: 'refresh_token', value: refreshToken);

// Retrieve on app launch
final token = await storage.read(key: 'auth_token');
```

**Benefits:**
- Data persists across app restarts
- Uses Android Keystore for encryption
- Secure against rooted devices (with KeyStore)

### iOS

**Same as Android:** Use `flutter_secure_storage`

```dart
// iOS uses Keychain for secure storage
await storage.write(key: 'auth_token', value: token);
```

**Benefits:**
- Data persists across app restarts
- Uses iOS Keychain (encrypted by default)
- Survives app updates
- Can be configured to require biometric authentication

---

## Current Implementation vs. Production-Ready

### Current State (In-Memory Cache)

✅ **Pros:**
- Simple implementation
- No additional dependencies
- Works well during active app usage

❌ **Cons:**
- Tokens lost when app is killed by OS
- User needs to re-login after app restart
- Not true "persistent" authentication

### Recommended Production Approach

**Step 1:** Replace in-memory cache with `flutter_secure_storage`

Update `cache_manager.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureCacheManager {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> set(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> get(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
```

**Step 2:** Update `CacheService` to use secure storage for tokens

```dart
class CacheService {
  final SecureCacheManager _secureCache = SecureCacheManager();

  // Store auth tokens securely
  Future<void> cacheAuthToken(String token) async {
    await _secureCache.set(CacheConfig.authTokenKey, token);
  }

  Future<String?> getCachedAuthToken() async {
    return await _secureCache.get(CacheConfig.authTokenKey);
  }
  
  // Similar for refresh_token, user_data, etc.
}
```

**Step 3:** Add biometric authentication (optional)

```dart
// Require Face ID/Touch ID before accessing tokens
final androidOptions = AndroidOptions(
  resetOnError: true,
  encryptedSharedPreferences: true,
);

final iosOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
  accountName: 'CRMX User Tokens',
);

final storage = FlutterSecureStorage(
  aOptions: androidOptions,
  iOptions: iosOptions,
);
```

---

## Session Lifetime Strategy

### Recommended Configuration

| Token Type | Lifetime | Storage | Rotation |
|------------|----------|---------|----------|
| Access Token | 1 hour | Memory/Secure Storage | On refresh |
| Refresh Token | 7 days | Secure Storage | On refresh |
| User Data Cache | 10 minutes | Memory | On explicit refresh |

### Session Expiry Handling

**Scenario 1: Access token expires (< 1 hour)**
- Frontend automatically calls `/api/auth/refresh`
- New tokens returned and cached
- Original API call retried
- ✅ Seamless to user

**Scenario 2: Refresh token expires (> 7 days)**
- Backend returns `401` on refresh attempt
- Frontend clears cache and redirects to login
- ❌ User must re-authenticate

**Scenario 3: User inactive for 7+ days**
- App reopens, refresh token expired
- Frontend detects expired refresh token
- Clears cache, shows login screen
- ❌ User must re-authenticate

---

## Security Best Practices

### 1. Token Rotation
- ✅ Implemented: Both tokens rotated on refresh
- Prevents token replay attacks

### 2. Secure Storage
- ❌ Current: In-memory (not persistent)
- ✅ Recommended: `flutter_secure_storage`
- Uses platform-native encryption (Keystore/Keychain)

### 3. Backend Validation
- ✅ Implemented: Supabase JWT validation with JWKS
- ✅ Checks user approval status on refresh
- ✅ Checks user active status on refresh

### 4. Refresh Token Security
```python
# services/auth/auth_service.py
async def refresh_access_token(self, refresh_token: str):
    # Verify user still exists
    postgres_user = self.user_service.get_user(user_id)
    
    # Re-check authorization
    if postgres_user.get("approval_status") != "approved":
        raise HTTPException(403, "Account not approved")
    
    if not postgres_user.get("is_active"):
        raise HTTPException(403, "Account is inactive")
```

### 5. Client-Side Retry Logic
```dart
// api_client.dart ensures:
// 1. Only one refresh attempt per request
// 2. Prevents infinite refresh loops
// 3. Clears tokens on refresh failure
```

---

## Migration Path for Your App

### Phase 1: Current (In-Memory) ✅ DONE
- Automatic token refresh
- Cache invalidation
- Basic session management

### Phase 2: Persistent Storage (Recommended Next)
1. Add `flutter_secure_storage` dependency
2. Update `CacheManager` to use secure storage for tokens
3. Keep user data in memory (less sensitive)
4. Test on both Android/iOS

### Phase 3: Enhanced Security (Optional)
1. Add biometric authentication for sensitive actions
2. Implement token encryption at rest
3. Add app lock after inactivity
4. Implement remote logout capability

---

## Testing Persistent Login

### Test Cases

1. **Happy Path:**
   - Login → Close app → Reopen → User still logged in ✅

2. **Token Expiry:**
   - Login → Wait 1 hour → Make API call → Token refreshed automatically ✅

3. **Refresh Token Expiry:**
   - Login → Wait 8 days → Reopen app → User redirected to login ✅

4. **User Deactivated:**
   - Login → Admin deactivates user → User makes API call → 403 Forbidden ✅

5. **Manual Logout:**
   - Login → Logout → All tokens cleared → User at login screen ✅

### Testing on Real Devices

**Android:**
```bash
# Build debug APK
flutter build apk --debug

# Install on device
adb install build/app/outputs/flutter-apk/app-debug.apk

# Test: Open app → Login → Force stop app → Reopen
```

**iOS:**
```bash
# Build and run on simulator/device
flutter run --release

# Test: Open app → Login → Kill app → Reopen
```

---

## Configuration Reference

### Backend Constants

```python
# services/auth/constants.py
ACCESS_TOKEN_EXPIRY = 3600  # 1 hour
REFRESH_TOKEN_EXPIRY = 604800  # 7 days
```

### Frontend Constants

```dart
// lib/core/cache/cache_config.dart
class CacheConfig {
  static const Duration authTokenTTL = Duration(minutes: 10);
  static const Duration currentUserDataTTL = Duration(minutes: 10);
  // Add for persistent storage:
  static const Duration refreshTokenTTL = Duration(days: 7);
}
```

---

## FAQ

**Q: Why do users need to re-login after closing the app?**
A: Currently using in-memory cache. Implement `flutter_secure_storage` for persistence.

**Q: What happens if backend revokes a user's access?**
A: Next API call or token refresh will return 403, forcing re-login.

**Q: Can users stay logged in forever?**
A: No, refresh tokens expire after 7 days. This is a security best practice.

**Q: What if user changes device?**
A: Tokens are device-specific. User must re-login on new device.

**Q: How to force logout all devices?**
A: Implement token blacklist in backend or change user's Supabase auth instance ID.

---

## Summary

### Current Implementation ✅

- ✅ Automatic token refresh on 401
- ✅ Refresh endpoint with user validation
- ✅ Token rotation for security
- ✅ Cache invalidation logic
- ✅ Session state management

### Next Steps for Production 🚀

1. **Add persistent storage** using `flutter_secure_storage`
2. **Test on real devices** (Android + iOS)
3. **Configure token lifetimes** based on security requirements
4. **Add biometric protection** for sensitive operations
5. **Implement remote logout** for admin control

### Key Files Modified

**Backend:**
- `services/auth/auth_service.py` - Added `refresh_access_token()` method
- `services/auth/controller.py` - Added `/refresh` endpoint

**Frontend:**
- `services/api/api_client.dart` - Added automatic retry with token refresh
- `features/auth/data/backend_auth_repository.dart` - Added `refreshSession()` method
- `features/auth/presentation/auth_controller.dart` - Wired refresh callback to ApiClient

---

**Implementation Date:** July 22, 2026  
**Status:** Core refresh logic complete, persistent storage recommended for production
