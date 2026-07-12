"""
Test script for WhatsApp webhook endpoints.

This script helps you test the webhook verification and event receiving endpoints.
"""

import requests
from urllib.parse import urlencode

BASE_URL = "http://127.0.0.1:8000"
WEBHOOK_PATH = "/webhooks/whatsapp"


def test_webhook_verification():
    """Test the GET endpoint for webhook verification."""
    print("\n=== Testing Webhook Verification (GET) ===")
    
    # These parameters should match what Meta sends
    params = {
        "hub.mode": "subscribe",
        "hub.verify_token": "crmx_webhook_verify_token_2024_secure",  # Must match .env
        "hub.challenge": "test_challenge_string_12345"
    }
    
    url = f"{BASE_URL}{WEBHOOK_PATH}?{urlencode(params)}"
    
    try:
        response = requests.get(url)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200 and response.text == params["hub.challenge"]:
            print("✅ Webhook verification PASSED")
        else:
            print("❌ Webhook verification FAILED")
            
    except Exception as e:
        print(f"❌ Error: {e}")


def test_webhook_event_text_message():
    """Test the POST endpoint with a sample text message event."""
    print("\n=== Testing Webhook Event - Text Message (POST) ===")
    
    # Sample webhook payload for a text message
    payload = {
        "object": "whatsapp_business_account",
        "entry": [
            {
                "id": "878503991939600",
                "changes": [
                    {
                        "field": "messages",
                        "value": {
                            "messaging_product": "whatsapp",
                            "metadata": {
                                "display_phone_number": "15551234567",
                                "phone_number_id": "1172029195989182"
                            },
                            "contacts": [
                                {
                                    "profile": {"name": "Test User"},
                                    "wa_id": "919876543210"
                                }
                            ],
                            "messages": [
                                {
                                    "from": "919876543210",
                                    "id": "wamid.test123456789",
                                    "timestamp": "1234567890",
                                    "text": {"body": "Hello, this is a test message!"},
                                    "type": "text"
                                }
                            ]
                        }
                    }
                ]
            }
        ]
    }
    
    url = f"{BASE_URL}{WEBHOOK_PATH}"
    
    try:
        response = requests.post(url, json=payload)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        
        if response.status_code == 200:
            print("✅ Webhook event PROCESSED")
        else:
            print("❌ Webhook event FAILED")
            
    except Exception as e:
        print(f"❌ Error: {e}")


def test_webhook_event_status_update():
    """Test the POST endpoint with a message status update."""
    print("\n=== Testing Webhook Event - Status Update (POST) ===")
    
    # Sample webhook payload for a status update
    payload = {
        "object": "whatsapp_business_account",
        "entry": [
            {
                "id": "878503991939600",
                "changes": [
                    {
                        "field": "message_status",
                        "value": {
                            "messaging_product": "whatsapp",
                            "metadata": {
                                "display_phone_number": "15551234567",
                                "phone_number_id": "1172029195989182"
                            },
                            "statuses": [
                                {
                                    "id": "wamid.test123456789",
                                    "status": "delivered",
                                    "timestamp": "1234567890",
                                    "recipient_id": "919876543210"
                                }
                            ]
                        }
                    }
                ]
            }
        ]
    }
    
    url = f"{BASE_URL}{WEBHOOK_PATH}"
    
    try:
        response = requests.post(url, json=payload)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        
        if response.status_code == 200:
            print("✅ Status update PROCESSED")
        else:
            print("❌ Status update FAILED")
            
    except Exception as e:
        print(f"❌ Error: {e}")


if __name__ == "__main__":
    print("WhatsApp Webhook Test Suite")
    print("=" * 50)
    print("Make sure your FastAPI server is running on http://127.0.0.1:8000")
    print("=" * 50)
    
    test_webhook_verification()
    test_webhook_event_text_message()
    test_webhook_event_status_update()
    
    print("\n" + "=" * 50)
    print("Testing complete!")
