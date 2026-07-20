"""JWT token validation utilities for Supabase authentication."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
from uuid import UUID

from fastapi import HTTPException, Request, status

from utils.env_vars import EnvVars


def assert_supabase_user_matches_request(request: Request, requested_user_id: UUID) -> None:
    """Optionally verify Supabase JWT subject against the requested user id.

    JWT verification is opt-in because newer Supabase projects may issue
    asymmetric JWTs that require JWKS verification instead of the legacy HS256
    shared secret. Keep this disabled for local POC unless JWKS verification is
    implemented.
    """

    verify_jwt = EnvVars.get("SUPABASE_VERIFY_JWT", "false").lower() == "true"
    if not verify_jwt:
        return

    jwt_secret = EnvVars.get("SUPABASE_JWT_SECRET")
    if not jwt_secret:
        return

    auth_header = request.headers.get("authorization", "")
    scheme, _, token = auth_header.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Supabase bearer token",
        )

    payload = _decode_and_verify_hs256(token, jwt_secret)
    if payload.get("sub") != str(requested_user_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Supabase user token does not match requested user",
        )


def get_user_id_from_token(request: Request) -> UUID:
    """Extract and return user ID from Supabase JWT token.
    
    This function always validates the token and extracts the user ID.
    
    Args:
        request: FastAPI request object with Authorization header
        
    Returns:
        UUID: User ID from token
        
    Raises:
        HTTPException(401): Missing or invalid token
    """
    auth_header = request.headers.get("authorization", "")
    scheme, _, token = auth_header.partition(" ")
    
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication token",
        )
    
    jwt_secret = EnvVars.get("SUPABASE_JWT_SECRET")
    if not jwt_secret:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server configuration error",
        )
    
    try:
        payload = _decode_and_verify_hs256(token, jwt_secret)
        user_id = payload.get("sub")
        
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: missing user ID",
            )
        
        return UUID(user_id)
        
    except (ValueError, KeyError) as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token format",
        ) from e


def _decode_and_verify_hs256(token: str, secret: str) -> dict:
    """Decode and verify HS256 JWT token."""
    parts = token.split(".")
    if len(parts) != 3:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid JWT")

    signing_input = f"{parts[0]}.{parts[1]}".encode("utf-8")
    expected_signature = hmac.new(secret.encode("utf-8"), signing_input, hashlib.sha256).digest()
    actual_signature = _b64url_decode(parts[2])
    if not hmac.compare_digest(expected_signature, actual_signature):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid JWT signature")

    payload = json.loads(_b64url_decode(parts[1]).decode("utf-8"))
    if payload.get("iss") and "supabase" not in str(payload["iss"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid JWT issuer")
    return payload


def _b64url_decode(value: str) -> bytes:
    """Decode base64url encoded string."""
    padded = value + "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(padded.encode("utf-8"))
