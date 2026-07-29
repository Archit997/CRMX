from __future__ import annotations

from utils.logging import redact_message


def test_redact_message_masks_credentials_and_phone_numbers() -> None:
    message = (
        "phone=+918607385222 otp=123456 "
        "Authorization: Bearer abc.def.ghi "
        "password=database-secret "
        "url=postgresql://postgres:database-secret@db.example.com/postgres"
    )

    redacted = redact_message(message)

    assert "123456" not in redacted
    assert "database-secret" not in redacted
    assert "abc.def.ghi" not in redacted
    assert "8607385222" not in redacted
    assert "[PHONE:******5222]" in redacted
    assert "postgresql://postgres:[REDACTED]@db.example.com" in redacted


def test_redact_message_keeps_operational_context() -> None:
    message = (
        "request_completed method=POST path=/api/auth/verify-otp "
        "status=200 duration_ms=81.25"
    )

    assert redact_message(message) == message
