"""Authentication dependencies for protecting API endpoints.

This module provides FastAPI dependencies for:
1. Token extraction (HTTPBearer)
2. JWT validation (PyJWT with JWKS for ES256)
3. User authentication
4. Role-based access control

Usage Examples:
    # Basic authentication
    @router.get("/protected")
    async def protected_route(
        current_user: Annotated[dict, Depends(get_current_user)]
    ):
        return {"user": current_user}

    # Admin-only endpoint
    @router.get("/admin-only")
    async def admin_route(
        admin: Annotated[dict, Depends(require_admin)]
    ):
        return {"message": "Admin access granted"}

    # Manager or Admin
    @router.post("/approve-client")
    async def approve_client(
        manager: Annotated[dict, Depends(require_manager_or_admin)]
    ):
        return {"approved": True}
"""

from __future__ import annotations

from functools import lru_cache
from typing import Annotated
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jwt import PyJWKClient
from jwt.exceptions import (
    ExpiredSignatureError,
    InvalidTokenError,
    PyJWKClientError,
)
from starlette.concurrency import run_in_threadpool

from services.postgres.dependencies import get_user_service
from services.user.constants import USER_ROLE_ADMIN, USER_ROLE_DEV, USER_ROLE_MANAGER
from services.user.user_service import UserService
from utils.env_vars import EnvVars


# ============================================================================
# HTTPBearer Security Scheme
# ============================================================================

security = HTTPBearer(
    scheme_name="Bearer",
    description="Enter your JWT token",
)

ALLOWED_JWT_ALGORITHMS = {"ES256", "RS256"}


@lru_cache(maxsize=4)
def _get_jwk_client(jwks_url: str) -> PyJWKClient:
    return PyJWKClient(
        jwks_url,
        cache_keys=True,
        cache_jwk_set=True,
        lifespan=300,
        timeout=5,
    )


# ============================================================================
# JWT Validation Helper
# ============================================================================


def decode_jwt_token(token: str) -> dict:
    """
    Validate and decode JWT token using Supabase JWKS.
    
    This function:
    - Fetches public keys from Supabase JWKS endpoint
    - Verifies JWT signature using ES256
    - Checks token expiry automatically
    - Validates token structure
    
    Args:
        token: JWT token string (without "Bearer " prefix)
        
    Returns:
        dict: Decoded JWT payload
        
    Raises:
        HTTPException(401): Token expired, invalid signature, or malformed
        HTTPException(500): Missing Supabase URL configuration
    """
    supabase_url = (EnvVars.get("SUPABASE_URL") or "").rstrip("/")
    
    if not supabase_url:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server configuration error: Missing SUPABASE_URL",
        )
    
    try:
        header = jwt.get_unverified_header(token)
        algorithm = header.get("alg")

        if algorithm not in ALLOWED_JWT_ALGORITHMS:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Unsupported token signing algorithm",
            )
        
        jwks_url = f"{supabase_url}/auth/v1/.well-known/jwks.json"
        signing_key = _get_jwk_client(jwks_url).get_signing_key_from_jwt(token)

        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=list(ALLOWED_JWT_ALGORITHMS),
            audience=EnvVars.get("SUPABASE_JWT_AUDIENCE", "authenticated"),
            issuer=f"{supabase_url}/auth/v1",
        )
        
        return payload
        
    except ExpiredSignatureError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
        ) from e
    
    except InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
        ) from e
    except PyJWKClientError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication key service is unavailable",
        ) from e
    
    except HTTPException:
        raise
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token validation failed",
        ) from e


# ============================================================================
# Core Authentication Dependency
# ============================================================================


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)],
    user_service: Annotated[UserService, Depends(get_user_service)],
) -> dict:
    """
    Extract, validate JWT token, and return authenticated user.
    
    This is the core dependency for protecting endpoints.
    
    Flow:
    1. HTTPBearer extracts token from Authorization header
    2. JWT validation (signature, expiry, format)
    3. Fetch user from database
    4. Check approval status
    5. Check active status
    
    Returns:
        dict: User data from database with all fields
        
    Raises:
        HTTPException(401): Invalid, expired, or missing token
        HTTPException(403): User not approved or inactive
        HTTPException(404): User not found in database
    """
    # Step 1: Extract token (HTTPBearer does this)
    token = credentials.credentials
    
    # Step 2: Validate JWT and decode payload
    payload = await run_in_threadpool(decode_jwt_token, token)
    
    # Step 3: Extract user ID from token
    user_id_str = payload.get("sub")
    if not user_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: missing user ID",
        )
    
    try:
        user_id = UUID(user_id_str)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: malformed user ID",
        ) from e
    
    # Step 4: Fetch user from database
    try:
        user = user_service.get_user(user_id)
    except LookupError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        ) from e
    
    # Step 5: Check approval status
    if user.get("approval_status") != "approved":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account not approved",
        )
    
    # Step 6: Check active status
    if not user.get("is_active"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is inactive",
        )

    if user.get("organization_id") and not user.get(
        "organization_is_active", False
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Organization is inactive",
        )
    
    return user


# ============================================================================
# Optional Authentication (for public/private hybrid endpoints)
# ============================================================================


async def get_current_user_optional(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(security)],
    user_service: Annotated[UserService, Depends(get_user_service)],
) -> dict | None:
    """
    Get current user if authenticated, otherwise return None.
    
    Use this for endpoints that work both authenticated and unauthenticated.
    For example, a public endpoint that shows more data for logged-in users.
    
    Returns:
        dict | None: User data if authenticated, None otherwise
    """
    if not credentials:
        return None
    
    try:
        return await get_current_user(credentials, user_service)
    except HTTPException:
        return None


# ============================================================================
# Role-Based Access Control Dependencies
# ============================================================================


async def require_admin(
    current_user: Annotated[dict, Depends(get_current_user)],
) -> dict:
    """
    Require user to have ADMIN role.
    
    Use this dependency on endpoints that only admins can access.
    
    Example:
        @router.post("/users/{user_id}/verification")
        async def verify_user(
            user_id: UUID,
            admin: Annotated[dict, Depends(require_admin)]
        ):
            # Only admins can approve users
            return approve_user(user_id)
    
    Returns:
        dict: Admin user data
        
    Raises:
        HTTPException(403): User is not an admin
    """
    if current_user.get("role") != USER_ROLE_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return current_user


async def require_manager_or_admin(
    current_user: Annotated[dict, Depends(get_current_user)],
) -> dict:
    """
    Require user to have MANAGER or ADMIN role.
    
    Use this dependency on endpoints that managers and admins can access.
    
    Example:
        @router.get("/reports/monthly")
        async def monthly_report(
            manager: Annotated[dict, Depends(require_manager_or_admin)]
        ):
            # Managers and admins can view reports
            return get_report()
    
    Returns:
        dict: Manager or admin user data
        
    Raises:
        HTTPException(403): User is not a manager or admin
    """
    user_role = current_user.get("role")
    if user_role not in [USER_ROLE_ADMIN, USER_ROLE_MANAGER]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Manager or admin access required",
        )
    return current_user


async def require_active_user(
    current_user: Annotated[dict, Depends(get_current_user)],
) -> dict:
    """
    Require user to be active (already checked in get_current_user).
    
    This is an alias for get_current_user with a more semantic name.
    Use when you want to emphasize that the endpoint requires an active user.
    
    Returns:
        dict: Active user data
    """
    return current_user


# ============================================================================
# Helper Dependencies
# ============================================================================


def get_user_id_from_current_user(
    current_user: Annotated[dict, Depends(get_current_user)],
) -> UUID:
    """
    Extract user ID from authenticated user.
    
    Helper dependency to get just the user ID when you don't need full user data.
    
    Example:
        @router.get("/my-clients")
        async def my_clients(
            user_id: Annotated[UUID, Depends(get_user_id_from_current_user)]
        ):
            return get_clients_by_user(user_id)
    
    Returns:
        UUID: User ID
    """
    return UUID(current_user["id"])


async def require_developer(
    current_user: Annotated[dict, Depends(get_current_user)],
) -> dict:
    """
    Require user to have DEV (Developer) role.
    
    Use this dependency on endpoints that only developers can access,
    such as health checks, debug endpoints, or system management tools.
    
    Example:
        @router.get("/postgres/health")
        async def postgres_health(
            dev: Annotated[dict, Depends(require_developer)]
        ):
            # Only developers can check database health
            return check_db_health()
    
    Returns:
        dict: Developer user data
        
    Raises:
        HTTPException(403): User is not a developer
    """
    if current_user.get("role") != USER_ROLE_DEV:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Developer access required",
        )
    return current_user


async def get_authenticated_user_for_signup(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)],
) -> dict:
    """
    Authenticate a user for the signup-request endpoint.

    New users have a valid Supabase JWT after OTP verification, but do NOT
    yet exist in Postgres. This dependency therefore only validates the JWT
    and returns the user id from the token — it must not require a Postgres row.

    Unlike get_current_user, this does NOT check:
    - whether the user exists in Postgres
    - approval_status
    - is_active

    Returns:
        dict: At least {"id": "<supabase_user_uuid>"} from the JWT subject

    Raises:
        HTTPException(401): Invalid, expired, or missing token
    """
    token = credentials.credentials
    payload = await run_in_threadpool(decode_jwt_token, token)

    user_id_str = payload.get("sub")
    if not user_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: missing user ID",
        )

    try:
        UUID(user_id_str)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: malformed user ID",
        ) from e

    return {
        "id": user_id_str,
        "phone": payload.get("phone"),
    }
