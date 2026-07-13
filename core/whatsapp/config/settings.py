"""WhatsApp settings and configuration."""

from utils.env_vars import EnvVars
from whatsapp.exceptions import WhatsAppConfigurationError

class WhatsAppSettings:
    @classmethod
    def _get_env_or_raise(cls, var_name):
        value = EnvVars.get(var_name)
        if not value:
            raise WhatsAppConfigurationError(f"Missing configuration: {var_name}")
        return value

    access_token = _get_env_or_raise.__func__(None, "WHATSAPP_ACCESS_TOKEN")
    phone_number_id = _get_env_or_raise.__func__(None, "WHATSAPP_PHONE_NUMBER_ID")
    business_acc_id = _get_env_or_raise.__func__(None, "WHATSAPP_BUSINESS_ACCOUNT_ID")
    app_secret = _get_env_or_raise.__func__(None, "WHATSAPP_APP_SECRET")
    webhook_verify_token = _get_env_or_raise.__func__(None, "WHATSAPP_WEBHOOK_VERIFY_TOKEN")
    graph_api_version = _get_env_or_raise.__func__(None, "WHATSAPP_GRAPH_API_VERSION")
