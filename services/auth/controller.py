from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field

from services.auth.auth_service import AuthService
from services.auth.jwt_utils import get_user_id_from_token
from services.postgres.dependencies import get_auth_service, get_user_service
from services.user.user_service import UserService
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
    @router.get("/user/me")
    async def get_current_user(
        request: Request,
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """
        Get current authenticated user's data from token.
        
        This endpoint extracts the user ID from the JWT token
        and returns the full user profile from the database.
        
        Usage:
        1. After login, frontend receives token
        2. Frontend calls this endpoint with Authorization: Bearer <token>
        3. Backend validates token, extracts user_id, returns user data
        
        This ensures frontend always has fresh user data from the database.
        """
        try:
            # Extract user ID from JWT token
            user_id = get_user_id_from_token(request)
            
            # Get user data from database
            user_data = user_service.get_user(user_id)
            
            return user_data
            
        except HTTPException:
            raise
        except LookupError as exc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            ) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Get current user failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to fetch user data"
            ) from exc


# Export router
auth_router = AuthController.router
