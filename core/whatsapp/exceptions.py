"""WhatsApp module exceptions."""

class WhatsAppError(Exception):
    """Base exception for WhatsApp related errors."""
    pass

class WhatsAppConfigurationError(WhatsAppError):
    """Raised when there is a configuration issue with WhatsApp integration."""
    pass

class MessageValidationError(WhatsAppError):
    """Raised when a message fails validation."""
    pass

class UnknownMessageTypeError(WhatsAppError):
    """Raised when a message type is unknown or unsupported."""
    pass

class UnknownWhatsAppUserError(WhatsAppError):
    """Raised when the specified WhatsApp user cannot be found."""
    pass

class DuplicateWebhookEventError(WhatsAppError):
    """Raised when a duplicate webhook event is received."""
    pass

class UnknownInteractionActionError(WhatsAppError):
    """Raised when an unknown interaction action is encountered."""
    pass

