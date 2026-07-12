"""Dependency injection for WhatsApp module."""

from core.whatsapp.webhooks.verifier import WebhookVerifier
from core.whatsapp.webhooks.ingestion_service import WebhookIngestionService


def get_webhook_verifier() -> WebhookVerifier:
    """Dependency injection for WebhookVerifier."""
    return WebhookVerifier()


def get_webhook_ingestion_service() -> WebhookIngestionService:
    """Dependency injection for WebhookIngestionService."""
    return WebhookIngestionService()
