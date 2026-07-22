from __future__ import annotations

import re
from typing import Any
from uuid import UUID

from fastapi import HTTPException, status
from supabase import Client, create_client

from services.auth.constants import (
    ERROR_AUTH_FAILED,
    ERROR_INVALID_OTP,
    ERROR_INVALID_PHONE,
    ERROR_SEND_OTP_FAILED,
    ERROR_USER_INACTIVE,
    ERROR_USER_PENDING,
    ERROR_USER_REJECTED,
    PHONE_REGEX_PATTERN,
)
from services.user.user_service import UserService
from utils.constants import LOG_LEVEL_ERROR, LOG_LEVEL_INFO
from utils.env_vars import EnvVars
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class AuthService:
    """
    Backend authentication layer that handles all Supabase interactions
    and enforces business logic (approval status, roles, active state).
    """

    def __init__(self, user_service: UserService):
        self.user_service = user_service

        # Initialize Supabase Admin Client (server-side)
        supabase_url = EnvVars.get("SUPABASE_URL")
        supabase_key = EnvVars.get("SUPABASE_SERVICE_ROLE_KEY")

        if not supabase_url or not supabase_key:
            raise ValueError(
                "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in environment"
            )

        self.supabase: Client = create_client(supabase_url, supabase_key)
        logger.log(LOG_LEVEL_INFO, "AuthService initialized with Supabase client")

    async def send_otp(self, phone: str) -> dict[str, Any]:
        """
        Send OTP to user's phone via Supabase.

        Args:
            phone: Phone number in E.164 format (e.g., "+919876543210")

        Returns:
            {"success": True, "message": "OTP sent successfully", "phone": phone}

        Raises:
            ValueError: Invalid phone format
            HTTPException: Supabase API error
        """

        # Validate phone number format
        if not self._is_valid_phone(phone):
            raise ValueError(ERROR_INVALID_PHONE)

        try:
            # Call Supabase Auth API to send OTP
            response = self.supabase.auth.sign_in_with_otp(
                {
                    "phone": phone,
                    "options": {
                        "should_create_user": True,  # Auto-create if doesn't exist
                    },
                }
            )

            logger.log(LOG_LEVEL_INFO, f"OTP sent successfully to {phone}")

            return {"success": True, "message": "OTP sent successfully", "phone": phone}

        except Exception as e:
            logger.log(LOG_LEVEL_ERROR, f"Failed to send OTP to {phone}: {e}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=ERROR_SEND_OTP_FAILED,
            ) from e

    async def verify_otp(self, phone: str, otp: str) -> dict[str, Any]:
        """
        Verify OTP and return authentication tokens only.
        
        Client must call /api/user/me to get user data after authentication.

        Args:
            phone: Phone number in E.164 format
            otp: 6-digit OTP code

        Returns:
            {
                "token": "jwt_token_string",
                "refresh_token": "refresh_token_string",
                "token_type": "bearer",
                "expires_in": 3600,
                "requires_signup": False
            }
            OR
            {
                "requires_signup": True,
                "supabase_user_id": "uuid",
                "phone": "+919876543210",
                "supabase_token": "temp_token"
            }

        Raises:
            HTTPException(401): Invalid OTP
            HTTPException(403): User not approved or inactive
        """

        try:
            # ================================================================
            # 1. Verify OTP with Supabase
            # ================================================================

            response = self.supabase.auth.verify_otp(
                {"phone": phone, "token": otp, "type": "sms"}
            )

            # Check if verification was successful
            if not response.session or not response.user:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=ERROR_INVALID_OTP,
                )

            # Extract Supabase user and session
            supabase_user = response.user
            supabase_session = response.session

            user_id = UUID(supabase_user.id)
            logger.log(LOG_LEVEL_INFO, f"OTP verified successfully for user {user_id}")

            # ================================================================
            # 2. Check if user exists in Postgres
            # ================================================================

            try:
                postgres_user = self.user_service.get_user(user_id)
            except LookupError:
                # User doesn't exist in Postgres yet - needs signup
                logger.log(LOG_LEVEL_INFO, f"User {user_id} not found in Postgres, requires signup")
                return {
                    "requires_signup": True,
                    "supabase_user_id": str(user_id),
                    "phone": supabase_user.phone,
                    "supabase_token": supabase_session.access_token,
                    "message": "Please complete signup",
                }

            # ================================================================
            # 3. Validate approval status and active state
            # ================================================================

            approval_status = postgres_user.get("approval_status")

            if approval_status != "approved":
                if approval_status == "pending":
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail=ERROR_USER_PENDING,
                    )
                elif approval_status == "rejected":
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail=ERROR_USER_REJECTED,
                    )
                else:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail=f"Account status: {approval_status}",
                    )

            if not postgres_user.get("is_active"):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=ERROR_USER_INACTIVE,
                )

            # ================================================================
            # 4. Return ONLY tokens (no user data)
            # ================================================================

            logger.log(LOG_LEVEL_INFO, f"User {user_id} authenticated successfully")

            return {
                "token": supabase_session.access_token,
                "refresh_token": supabase_session.refresh_token,
                "token_type": "bearer",
                "expires_in": supabase_session.expires_in,
                "requires_signup": False,
            }

        except HTTPException:
            # Re-raise HTTP exceptions
            raise

        except Exception as e:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Failed to verify OTP for {phone}: {e}",
                exc_info=True,
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=ERROR_AUTH_FAILED,
            ) from e

    def _is_valid_phone(self, phone: str) -> bool:
        """
        Validate phone number format (E.164).
        Examples: +919876543210, +1234567890
        """
        return bool(re.match(PHONE_REGEX_PATTERN, phone))

    async def refresh_access_token(self, refresh_token: str) -> dict[str, Any]:
        """
        Refresh access token using refresh token.
        
        This allows users to get a new access token without re-authenticating.
        
        Args:
            refresh_token: The refresh token from previous authentication
            
        Returns:
            {
                "token": "new_jwt_token",
                "refresh_token": "new_refresh_token",
                "token_type": "bearer",
                "expires_in": 3600
            }
            
        Raises:
            HTTPException(401): Invalid or expired refresh token
        """
        try:
            # Call Supabase to refresh the session
            response = self.supabase.auth.refresh_session(refresh_token)
            
            if not response.session:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid refresh token",
                )
            
            session = response.session
            user_id = UUID(response.user.id)
            
            # Verify user still exists and is approved/active
            try:
                postgres_user = self.user_service.get_user(user_id)
            except LookupError:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="User not found",
                )
            
            # Check approval and active status
            if postgres_user.get("approval_status") != "approved":
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Account not approved",
                )
            
            if not postgres_user.get("is_active"):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Account is inactive",
                )
            
            logger.log(LOG_LEVEL_INFO, f"Token refreshed successfully for user {user_id}")
            
            return {
                "token": session.access_token,
                "refresh_token": session.refresh_token,
                "token_type": "bearer",
                "expires_in": session.expires_in,
            }
            
        except HTTPException:
            raise
        
        except Exception as e:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Failed to refresh token: {e}",
                exc_info=True,
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token refresh failed",
            ) from e

