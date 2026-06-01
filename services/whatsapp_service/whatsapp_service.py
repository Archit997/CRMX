import requests

from utils.env_vars import EnvVars
from .config import GRAPH_API_VERSION, MESSAGES_API_URL


class WhatsappService:

    def __init__(self):
        self.api_key = EnvVars.get("META_PORTFOLIO_ADMIN_API_KEY")
        self.business_acc_id = EnvVars.get("WA_BUSINESS_ACC_ID")
        self.sender_id = EnvVars.get("WA_SENDER_ID")

    def _messages_url(self) -> str:
        return MESSAGES_API_URL.format(
            graph_api_version=GRAPH_API_VERSION,
            sender_id=self.sender_id,
        )

    def send_message(self, to: str, message: str) -> dict:
        payload = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": to,
            "type": "text",
            "text": {"body": message},
        }
        response = requests.post(
            self._messages_url(),
            json=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.api_key}",
            },
            timeout=30,
        )
        response.raise_for_status()
        return response.json()
