"""Webhook verification logic."""

from fastapi import HTTPException, status
from utils.env_vars import EnvVars
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class WebhookVerifier:
    """Handles WhatsApp webhook verification."""

    def __init__(self):
        self.verify_token = EnvVars.get("WHATSAPP_WEBHOOK_VERIFY_TOKEN")
        if not self.verify_token:
            logger.warning("WHATSAPP_WEBHOOK_VERIFY_TOKEN not set in environment")

    def verify_webhook_token(self, mode: str, token: str, challenge: str) -> str:
        """
        Verify webhook subscription request from Meta.
        
        Args:
            mode: Should be "subscribe"
            token: Verification token sent by Meta
            challenge: Random string to echo back
            
        Returns:
            The challenge string if verification succeeds
            
        Raises:
            HTTPException: If verification fails
        """
        if not self.verify_token:
            logger.error("Webhook verification failed: WHATSAPP_WEBHOOK_VERIFY_TOKEN not configured")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Webhook verification token not configured",
            )

        if mode != "subscribe":
            logger.warning(f"Webhook verification failed: invalid mode '{mode}'")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid verification mode",
            )

        if token != self.verify_token:
            logger.warning("Webhook verification failed: token mismatch")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid verification token",
            )

        logger.info("Webhook verification successful")
        return challenge
