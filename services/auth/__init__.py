from services.auth.auth_service import AuthService
from services.auth.constants import (
    ACCESS_TOKEN_EXPIRY,
    ERROR_AUTH_FAILED,
    ERROR_INVALID_OTP,
    ERROR_INVALID_PHONE,
    ERROR_MISSING_TOKEN,
    ERROR_SEND_OTP_FAILED,
    ERROR_USER_INACTIVE,
    ERROR_USER_PENDING,
    ERROR_USER_REJECTED,
    OTP_EXPIRY_SECONDS,
    OTP_LENGTH,
    PHONE_REGEX_PATTERN,
    PUBLIC_ROUTES,
    REFRESH_TOKEN_EXPIRY,
)
from services.auth.controller import auth_router
from services.auth.dependencies import (
    decode_jwt_token,
    get_authenticated_user_for_signup,
    get_current_user,
    get_current_user_optional,
    get_user_id_from_current_user,
    require_active_user,
    require_admin,
    require_developer,
    require_manager_or_admin,
    security,
)

__all__ = [
    # Core service and router
    "AuthService",
    "auth_router",
    # Constants
    "ACCESS_TOKEN_EXPIRY",
    "ERROR_AUTH_FAILED",
    "ERROR_INVALID_OTP",
    "ERROR_INVALID_PHONE",
    "ERROR_MISSING_TOKEN",
    "ERROR_SEND_OTP_FAILED",
    "ERROR_USER_INACTIVE",
    "ERROR_USER_PENDING",
    "ERROR_USER_REJECTED",
    "OTP_EXPIRY_SECONDS",
    "OTP_LENGTH",
    "PHONE_REGEX_PATTERN",
    "PUBLIC_ROUTES",
    "REFRESH_TOKEN_EXPIRY",
    # Authentication dependencies (HTTPBearer + PyJWT)
    "security",
    "decode_jwt_token",
    "get_current_user",
    "get_current_user_optional",
    "get_authenticated_user_for_signup",
    "get_user_id_from_current_user",
    "require_admin",
    "require_manager_or_admin",
    "require_developer",
    "require_active_user",
]
