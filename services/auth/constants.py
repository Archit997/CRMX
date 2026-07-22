"""Authentication service constants."""

# Token expiry times (in seconds)
ACCESS_TOKEN_EXPIRY = 3600  # 1 hour
REFRESH_TOKEN_EXPIRY = 604800  # 7 days

# Phone number validation
PHONE_REGEX_PATTERN = r"^\+[1-9]\d{1,14}$"  # E.164 format

# OTP configuration
OTP_LENGTH = 6
OTP_EXPIRY_SECONDS = 300  # 5 minutes

# Auth endpoints that don't require authentication
PUBLIC_ROUTES = [
    "/api/auth/send-otp",
    "/api/auth/verify-otp",
    "/docs",
    "/openapi.json",
    "/redoc",
]

# Error messages
ERROR_INVALID_PHONE = "Invalid phone number format. Use E.164 format: +[country code][number]"
ERROR_INVALID_OTP = "Invalid OTP or OTP expired"
ERROR_MISSING_TOKEN = "Missing or invalid authentication token"
ERROR_USER_PENDING = "Your account is pending approval. Please wait for admin approval."
ERROR_USER_REJECTED = "Your account has been rejected. Please contact administrator."
ERROR_USER_INACTIVE = "Your account is inactive. Please contact administrator."
ERROR_SEND_OTP_FAILED = "Failed to send OTP"
ERROR_AUTH_FAILED = "Authentication failed"
