"""Webhook route definitions."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status

from core.whatsapp.webhooks.verifier import WebhookVerifier
from core.whatsapp.webhooks.ingestion_service import WebhookIngestionService
from core.whatsapp.dependencies import get_webhook_verifier, get_webhook_ingestion_service
from utils.constants import LOG_LEVEL_ERROR
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class WhatsAppWebhookController:
    """Controller for WhatsApp webhook endpoints."""
    
    router = APIRouter(
        prefix="/webhooks/whatsapp",
        tags=["WhatsApp"],
    )

    @staticmethod
    @router.get("")
    async def verify_webhook(
        request: Request,
        mode: str = Query(alias="hub.mode"),
        token: str = Query(alias="hub.verify_token"),
        challenge: str = Query(alias="hub.challenge"),
        verifier: Annotated[WebhookVerifier, Depends(get_webhook_verifier)] = None,
    ) -> Response:
        """
        Webhook verification endpoint for WhatsApp.
        
        Meta will call this endpoint once during webhook setup to verify
        that we own the callback URL.
        
        Query Parameters:
            hub.mode: Should be "subscribe"
            hub.verify_token: Verification token configured in Meta dashboard
            hub.challenge: Random string that must be echoed back
            
        Returns:
            Plain text response with the challenge string
        """
        try:
            logger.info(f"Webhook verification request from {request.client.host}")
            challenge_response = verifier.verify_webhook_token(mode, token, challenge)
            return Response(content=challenge_response, media_type="text/plain")
        except HTTPException:
            raise
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Webhook verification failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Webhook verification failed",
            ) from exc

    @staticmethod
    @router.post("")
    async def receive_webhook(
        request: Request,
        ingestion_service: Annotated[WebhookIngestionService, Depends(get_webhook_ingestion_service)] = None,
    ) -> dict:
        """
        Webhook event receiver for WhatsApp.
        
        Receives incoming messages, status updates, and other events from Meta's
        WhatsApp Business API.
        
        Returns:
            Status response dict
        """
        try:
            body = await request.json()
            
            logger.info(f"Received webhook event from {request.client.host}")
            logger.debug(f"Webhook payload: {body}")
            
            result = await ingestion_service.process_webhook_event(body)
            
            return result
            
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Webhook processing failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            # Return 200 even on error to prevent Meta from retrying
            # Log the error but acknowledge receipt
            return {"status": "error", "message": "Internal processing error"}


whatsapp_webhook_router = WhatsAppWebhookController.router
