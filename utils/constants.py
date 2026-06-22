APP_TITLE = "CRMX Backend"
APP_VERSION = "0.1.0"
DEFAULT_SERVER_HOST = "127.0.0.1"
DEFAULT_SERVER_PORT = 8000

DEFAULT_DB_NAME = "crmx"

COLLECTION_STATUS_MASTER = "status_master"
COLLECTION_CLIENTS = "clients"
COLLECTION_CLIENT_UPDATES = "client_updates"

GRAPH_API_VERSION = "v23.0"
MESSAGES_API_URL = "https://graph.facebook.com/{graph_api_version}/{sender_id}/messages"

STATUS_MASTER_SEED = [
    {"status_no": 1, "status_name": "New Lead", "category": "Lead", "is_active": True},
    {"status_no": 2, "status_name": "Contacted", "category": "Lead", "is_active": True},
    {"status_no": 3, "status_name": "Asked for Information", "category": "Lead", "is_active": True},
    {"status_no": 4, "status_name": "Information Sent", "category": "Lead", "is_active": True},
    {"status_no": 5, "status_name": "Asked for Document", "category": "Lead", "is_active": True},
    {"status_no": 6, "status_name": "Document Sent", "category": "Lead", "is_active": True},
    {"status_no": 7, "status_name": "Follow-up Required", "category": "Lead", "is_active": True},
    {"status_no": 8, "status_name": "Negotiation Phase", "category": "Client", "is_active": True},
    {"status_no": 9, "status_name": "Payment Pending", "category": "Client", "is_active": True},
    {"status_no": 10, "status_name": "Order Confirmed", "category": "Client", "is_active": True},
    {"status_no": 11, "status_name": "Delivered / Completed", "category": "Client", "is_active": True},
    {"status_no": 12, "status_name": "After-Sales Follow-up", "category": "Client", "is_active": True},
    {"status_no": 13, "status_name": "On Hold", "category": "Critical", "is_active": True},
    {"status_no": 14, "status_name": "Lost", "category": "Critical", "is_active": True},
]
