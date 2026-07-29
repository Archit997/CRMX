from __future__ import annotations

import re


_REDACTION_RULES: tuple[tuple[re.Pattern[str], str], ...] = (
    (
        re.compile(
            r"(?i)\b(bearer)(\s+)[A-Za-z0-9._~+/=-]+"
        ),
        r"\1\2[REDACTED]",
    ),
    (
        re.compile(
            r"(?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]*"
            r"\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"
        ),
        "[REDACTED_JWT]",
    ),
    (
        re.compile(
            r"(?i)\b("
            r"access[_-]?token|refresh[_-]?token|auth[_-]?token|"
            r"service[_-]?role[_-]?key|anon[_-]?key|api[_-]?key|"
            r"password|passwd|secret|otp"
            r")([\"']?\s*[:=]\s*[\"']?)([^,\s\"'}]+)"
        ),
        r"\1\2[REDACTED]",
    ),
    (
        re.compile(
            r"(?i)(postgres(?:ql)?(?:\+\w+)?://[^:\s/]+:)"
            r"([^@\s/]+)(@)"
        ),
        r"\1[REDACTED]\3",
    ),
    (
        re.compile(r"(?<!\d)(?:\+?91[-\s]?)?([6-9]\d{5})(\d{4})(?!\d)"),
        r"[PHONE:******\2]",
    ),
    (
        re.compile(r"\bEAA[A-Za-z0-9]{20,}\b"),
        "[REDACTED_TOKEN]",
    ),
)


def redact_message(value: object) -> str:
    """Return a log-safe string with common credentials and PII masked."""
    redacted = str(value)
    for pattern, replacement in _REDACTION_RULES:
        redacted = pattern.sub(replacement, redacted)
    return redacted
