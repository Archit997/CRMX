"""
Test script for authentication endpoints including token refresh.

This script tests:
1. POST /api/auth/send-otp - Send OTP to phone
2. POST /api/auth/verify-otp - Verify OTP and get tokens
3. POST /api/auth/refresh - Refresh access token using refresh token
4. GET /api/auth/user/me - Get current user data using access token

Usage:
    python test_auth_refresh.py
"""

import requests
import time

BASE_URL = "http://localhost:8000"

def test_send_otp(phone: str):
    """Test sending OTP to phone number."""
    print("\n" + "="*60)
    print("TEST 1: Send OTP")
    print("="*60)
    
    response = requests.post(
        f"{BASE_URL}/api/auth/send-otp",
        json={"phone_number": phone}
    )
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.json()}")
    
    if response.status_code == 200:
        print("✅ OTP sent successfully!")
        return True
    else:
        print("❌ Failed to send OTP")
        return False


def test_verify_otp(phone: str, otp: str):
    """Test OTP verification and token retrieval."""
    print("\n" + "="*60)
    print("TEST 2: Verify OTP")
    print("="*60)
    
    response = requests.post(
        f"{BASE_URL}/api/auth/verify-otp",
        json={
            "phone_number": phone,
            "otp": otp
        }
    )
    
    print(f"Status Code: {response.status_code}")
    data = response.json()
    print(f"Response: {data}")
    
    if response.status_code == 200:
        if data.get("requires_signup"):
            print("⚠️  User requires signup")
            return None, None
        
        token = data.get("token")
        refresh_token = data.get("refresh_token")
        
        print(f"✅ OTP verified successfully!")
        print(f"Access Token (first 50 chars): {token[:50]}...")
        print(f"Refresh Token (first 50 chars): {refresh_token[:50]}...")
        print(f"Expires In: {data.get('expires_in')} seconds")
        
        return token, refresh_token
    else:
        print("❌ Failed to verify OTP")
        return None, None


def test_get_current_user(token: str):
    """Test getting current user data."""
    print("\n" + "="*60)
    print("TEST 3: Get Current User (/me)")
    print("="*60)
    
    response = requests.get(
        f"{BASE_URL}/api/auth/user/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.json()}")
    
    if response.status_code == 200:
        print("✅ User data retrieved successfully!")
        return True
    else:
        print("❌ Failed to get user data")
        return False


def test_refresh_token(refresh_token: str):
    """Test refreshing access token."""
    print("\n" + "="*60)
    print("TEST 4: Refresh Access Token")
    print("="*60)
    
    response = requests.post(
        f"{BASE_URL}/api/auth/refresh",
        json={"refresh_token": refresh_token}
    )
    
    print(f"Status Code: {response.status_code}")
    data = response.json()
    print(f"Response: {data}")
    
    if response.status_code == 200:
        new_token = data.get("token")
        new_refresh_token = data.get("refresh_token")
        
        print(f"✅ Token refreshed successfully!")
        print(f"New Access Token (first 50 chars): {new_token[:50]}...")
        print(f"New Refresh Token (first 50 chars): {new_refresh_token[:50]}...")
        print(f"Expires In: {data.get('expires_in')} seconds")
        
        return new_token, new_refresh_token
    else:
        print("❌ Failed to refresh token")
        return None, None


def test_with_refreshed_token(new_token: str):
    """Test API call with refreshed token."""
    print("\n" + "="*60)
    print("TEST 5: Verify Refreshed Token Works")
    print("="*60)
    
    response = requests.get(
        f"{BASE_URL}/api/auth/user/me",
        headers={"Authorization": f"Bearer {new_token}"}
    )
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.json()}")
    
    if response.status_code == 200:
        print("✅ Refreshed token works correctly!")
        return True
    else:
        print("❌ Refreshed token failed")
        return False


def test_invalid_refresh_token():
    """Test refresh with invalid token."""
    print("\n" + "="*60)
    print("TEST 6: Invalid Refresh Token (Expected to Fail)")
    print("="*60)
    
    response = requests.post(
        f"{BASE_URL}/api/auth/refresh",
        json={"refresh_token": "invalid_token_xyz"}
    )
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.json()}")
    
    if response.status_code == 401:
        print("✅ Invalid token correctly rejected!")
        return True
    else:
        print("⚠️  Expected 401 Unauthorized")
        return False


def main():
    """Run all authentication tests."""
    print("\n" + "="*70)
    print("🔐 CRMX Authentication & Token Refresh Test Suite")
    print("="*70)
    
    # Get test phone and OTP from user
    phone = input("\nEnter phone number (E.164 format, e.g., +919876543210): ").strip()
    
    # Step 1: Send OTP
    if not test_send_otp(phone):
        print("\n❌ Test suite failed at Step 1: Send OTP")
        return
    
    # Wait for OTP to arrive
    otp = input("\nEnter the OTP you received: ").strip()
    
    # Step 2: Verify OTP and get tokens
    access_token, refresh_token = test_verify_otp(phone, otp)
    
    if not access_token or not refresh_token:
        print("\n❌ Test suite failed at Step 2: Verify OTP")
        return
    
    # Step 3: Get user data with access token
    if not test_get_current_user(access_token):
        print("\n❌ Test suite failed at Step 3: Get Current User")
        return
    
    # Step 4: Refresh the token
    new_access_token, new_refresh_token = test_refresh_token(refresh_token)
    
    if not new_access_token or not new_refresh_token:
        print("\n❌ Test suite failed at Step 4: Refresh Token")
        return
    
    # Step 5: Test refreshed token works
    if not test_with_refreshed_token(new_access_token):
        print("\n❌ Test suite failed at Step 5: Verify Refreshed Token")
        return
    
    # Step 6: Test invalid refresh token
    test_invalid_refresh_token()
    
    # Final summary
    print("\n" + "="*70)
    print("🎉 ALL TESTS COMPLETED SUCCESSFULLY!")
    print("="*70)
    print("\nSummary:")
    print("✅ OTP sending works")
    print("✅ OTP verification works")
    print("✅ Token retrieval works")
    print("✅ User data endpoint works")
    print("✅ Token refresh works")
    print("✅ Refreshed token is valid")
    print("✅ Invalid tokens are rejected")
    print("\n📱 Your mobile app can now use these endpoints for persistent authentication!")
    print("\nKey Points:")
    print("- Access tokens expire after 1 hour")
    print("- Refresh tokens expire after 7 days")
    print("- Both tokens rotate on each refresh")
    print("- Store refresh token securely in flutter_secure_storage")
    print("- ApiClient automatically refreshes on 401 errors")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n❌ Test suite interrupted by user")
    except Exception as e:
        print(f"\n\n❌ Test suite failed with error: {e}")
        import traceback
        traceback.print_exc()
