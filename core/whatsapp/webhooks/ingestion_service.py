"""Webhook data ingestion service."""

from typing import Any
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class WebhookIngestionService:
    """Handles processing of incoming WhatsApp webhook events."""

    async def process_webhook_event(self, body: dict[str, Any]) -> dict[str, str]:
        """
        Process incoming WhatsApp webhook event.
        
        Args:
            body: The webhook payload from Meta
            
        Returns:
            Status response dict
        """
        try:
            if body.get("object") != "whatsapp_business_account":
                logger.warning(f"Received webhook with unexpected object type: {body.get('object')}")
                return {"status": "ignored"}

            entries = body.get("entry", [])
            
            for entry in entries:
                entry_id = entry.get("id")
                changes = entry.get("changes", [])
                
                for change in changes:
                    field = change.get("field")
                    value = change.get("value", {})
                    
                    logger.info(f"Processing webhook change: field={field}, entry_id={entry_id}")
                    
                    if field == "messages":
                        await self._process_messages(value)
                    elif field == "message_status":
                        await self._process_status_updates(value)
                    else:
                        logger.info(f"Unhandled webhook field: {field}")
            
            return {"status": "processed"}
            
        except Exception as e:
            logger.error(f"Error processing webhook event: {e}", exc_info=True)
            return {"status": "error", "message": str(e)}

    async def _process_messages(self, value: dict[str, Any]) -> None:
        """Process incoming messages from webhook."""
        messages = value.get("messages", [])
        metadata = value.get("metadata", {})
        contacts = value.get("contacts", [])
        
        for message in messages:
            message_id = message.get("id")
            from_number = message.get("from")
            timestamp = message.get("timestamp")
            message_type = message.get("type")
            
            logger.info(
                f"Received message: id={message_id}, from={from_number}, "
                f"type={message_type}, timestamp={timestamp}"
            )
            
            if message_type == "text":
                text_body = message.get("text", {}).get("body")
                logger.info(f"Text message content: {text_body}")
                
            elif message_type == "image":
                image_id = message.get("image", {}).get("id")
                logger.info(f"Image message: image_id={image_id}")
                
            elif message_type == "audio":
                audio_id = message.get("audio", {}).get("id")
                logger.info(f"Audio message: audio_id={audio_id}")
                
            elif message_type == "video":
                video_id = message.get("video", {}).get("id")
                logger.info(f"Video message: video_id={video_id}")
                
            elif message_type == "document":
                document_id = message.get("document", {}).get("id")
                logger.info(f"Document message: document_id={document_id}")
                
            else:
                logger.info(f"Unhandled message type: {message_type}")

    async def _process_status_updates(self, value: dict[str, Any]) -> None:
        """Process message status updates from webhook."""
        statuses = value.get("statuses", [])
        
        for status_update in statuses:
            message_id = status_update.get("id")
            status_value = status_update.get("status")
            recipient_id = status_update.get("recipient_id")
            timestamp = status_update.get("timestamp")
            
            logger.info(
                f"Message status update: message_id={message_id}, "
                f"status={status_value}, recipient={recipient_id}, timestamp={timestamp}"
            )
            
            if status_value == "sent":
                logger.info(f"Message {message_id} was sent")
            elif status_value == "delivered":
                logger.info(f"Message {message_id} was delivered")
            elif status_value == "read":
                logger.info(f"Message {message_id} was read")
            elif status_value == "failed":
                error = status_update.get("errors", [{}])[0]
                logger.error(f"Message {message_id} failed: {error}")
            else:
                logger.info(f"Unhandled status: {status_value}")
