from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field

from services.auth.auth_service import AuthService
from services.auth.dependencies import get_current_user
from services.postgres.dependencies import get_auth_service
from utils.constants import LOG_LEVEL_ERROR
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


# ============================================================================
# Request/Response Models
# ============================================================================


class SendOtpRequest(BaseModel):
    phone: str = Field(..., example="+919876543210", description="Phone number in E.164 format")


class SendOtpResponse(BaseModel):
    success: bool
    message: str
    phone: str


class VerifyOtpRequest(BaseModel):
    phone: str = Field(..., example="+919876543210", description="Phone number in E.164 format")
    otp: str = Field(..., example="123456", min_length=6, max_length=6, description="6-digit OTP code")


class VerifyOtpResponse(BaseModel):
    token: str | None = None
    refresh_token: str | None = None
    token_type: str = "bearer"
    expires_in: int | None = None
    requires_signup: bool = False
    supabase_user_id: str | None = None
    supabase_token: str | None = None
    message: str | None = None


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(..., description="Refresh token from previous authentication")


class RefreshTokenResponse(BaseModel):
    token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


# ============================================================================
# Auth Controller
# ============================================================================


class AuthController:
    router = APIRouter(prefix="/api/auth", tags=["Authentication"])

    @staticmethod
    @router.post("/send-otp", response_model=SendOtpResponse, status_code=status.HTTP_200_OK)
    async def send_otp(
        payload: SendOtpRequest,
        request: Request,
        auth_service: Annotated[AuthService, Depends(get_auth_service)],
    ) -> SendOtpResponse:
        """
        Send OTP to user's phone number.

        Frontend Flow:
        1. User enters phone number
        2. User clicks "Get OTP"
        3. Frontend calls this endpoint
        4. User receives SMS with OTP code
        """
        try:
            result = await auth_service.send_otp(payload.phone)
            return SendOtpResponse(**result)

        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
            ) from exc

        except HTTPException:
            raise

        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Send OTP failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to send OTP"
            ) from exc

    @staticmethod
    @router.post("/verify-otp", response_model=VerifyOtpResponse, status_code=status.HTTP_200_OK)
    async def verify_otp(
        payload: VerifyOtpRequest,
        request: Request,
        auth_service: Annotated[AuthService, Depends(get_auth_service)],
    ) -> VerifyOtpResponse:
        """
        Verify OTP and authenticate user.

        Frontend Flow:
        1. User enters OTP received via SMS
        2. User clicks "Verify"
        3. Frontend calls this endpoint
        4. Backend verifies OTP with Supabase
        5. Backend checks approval status
        6. Returns token only (no user data)
        7. Frontend MUST call /api/user/me to get user data

        Response Cases:
        - Success (approved user): {token, refresh_token, requires_signup: false}
          → Frontend should call GET /api/user/me with token to get user data
        - New User: {requires_signup: true, supabase_user_id, supabase_token}
          → Frontend should show signup form
        - Pending Approval: 403 error "Account pending approval"
        - Rejected: 403 error "Account rejected"
        - Invalid OTP: 401 error "Invalid OTP"
        """
        try:
            result = await auth_service.verify_otp(payload.phone, payload.otp)
            return VerifyOtpResponse(**result)

        except HTTPException:
            raise

        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Verify OTP failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Authentication failed",
            ) from exc

    @staticmethod
    @router.post("/refresh", response_model=RefreshTokenResponse, status_code=status.HTTP_200_OK)
    async def refresh_token(
        payload: RefreshTokenRequest,
        request: Request,
        auth_service: Annotated[AuthService, Depends(get_auth_service)],
    ) -> RefreshTokenResponse:
        """
        Refresh access token using refresh token.
        
        Use this endpoint when the access token expires (typically after 1 hour).
        The refresh token has a longer lifespan (typically 7 days).
        
        Flow:
        1. Frontend detects 401 Unauthorized on API call
        2. Frontend calls this endpoint with refresh_token
        3. Backend validates refresh_token with Supabase
        4. Backend checks user approval/active status
        5. Returns new access_token and refresh_token
        6. Frontend retries original API call with new token
        
        Both tokens are rotated on each refresh for security.
        
        Returns:
            New access token and refresh token
            
        Raises:
            HTTPException(401): Invalid or expired refresh token
            HTTPException(403): User not approved or inactive
        """
        try:
            result = await auth_service.refresh_access_token(payload.refresh_token)
            return RefreshTokenResponse(**result)

        except HTTPException:
            raise

        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Refresh token failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token refresh failed",
            ) from exc

    @staticmethod
    @router.get("/user/me")
    async def get_current_user_endpoint(
        current_user: Annotated[dict, Depends(get_current_user)],
    ) -> dict:
        """
        Get current authenticated user's data from token.
        
        This endpoint uses the get_current_user dependency which:
        1. Extracts token from Authorization header (HTTPBearer)
        2. Validates JWT signature and expiry (PyJWT)
        3. Fetches user from database
        4. Checks approval and active status
        
        The dependency handles all validation, so this endpoint just returns the user.
        
        Returns:
            dict: Full user profile with all fields
            
        Raises:
            HTTPException(401): Invalid, expired, or missing token
            HTTPException(403): User not approved or inactive
            HTTPException(404): User not found
        """
        # The dependency already validated everything, just return the user
        return current_user


# Export router
auth_router = AuthController.router
