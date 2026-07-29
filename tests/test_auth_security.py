from __future__ import annotations

import jwt
import pytest
from fastapi import HTTPException

from services.auth.dependencies import decode_jwt_token


def test_symmetric_jwt_algorithm_is_rejected_before_key_lookup() -> None:
    token = jwt.encode(
        {"sub": "00000000-0000-0000-0000-000000000001"},
        "not-a-production-secret-with-32-bytes",
        algorithm="HS256",
    )

    with pytest.raises(HTTPException) as exc_info:
        decode_jwt_token(token)

    assert exc_info.value.status_code == 401
    assert exc_info.value.detail == "Unsupported token signing algorithm"
