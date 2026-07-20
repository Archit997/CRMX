"""User service constants."""

# User roles (must match db/postgres/models.py UserRole enum)
USER_ROLE_ADMIN = "ADMIN"
USER_ROLE_MANAGER = "MANAGER"
USER_ROLE_DEV = "DEV"
USER_ROLE_EMPLOYEE = "EMPLOYEE"

VALID_USER_ROLES = [
    USER_ROLE_ADMIN,
    USER_ROLE_MANAGER,
    USER_ROLE_DEV,
    USER_ROLE_EMPLOYEE,
]

# Approval status values
APPROVAL_STATUS_PENDING = "pending"
APPROVAL_STATUS_APPROVED = "approved"
APPROVAL_STATUS_REJECTED = "rejected"

VALID_APPROVAL_STATUSES = [
    APPROVAL_STATUS_PENDING,
    APPROVAL_STATUS_APPROVED,
    APPROVAL_STATUS_REJECTED,
]

# Error messages
ERROR_USER_NOT_FOUND = "User not found"
ERROR_USER_ALREADY_EXISTS = "User already exists"
ERROR_INVALID_ROLE = f"Invalid role. Must be one of: {', '.join(VALID_USER_ROLES)}"
ERROR_INVALID_APPROVAL_STATUS = (
    f"Invalid approval status. Must be one of: {', '.join(VALID_APPROVAL_STATUSES)}"
)
ERROR_UNAUTHORIZED = "You are not authorized to perform this action"

# Admin roles (for permission checks)
ADMIN_ROLES = [USER_ROLE_ADMIN]

# Roles excluded from client assignment
EXCLUDED_FROM_ASSIGNMENT = [USER_ROLE_DEV]
