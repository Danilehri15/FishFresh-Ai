from datetime import datetime, timezone
from typing import Dict, Any

class SubscriptionService:
    def __init__(self):
        # In-memory storage for user quotas (can connect to Firestore / DB)
        self.user_tiers = {}
        self.daily_scans = {}

    def get_user_status(self, user_id: str = "default_user") -> Dict[str, Any]:
        tier = self.user_tiers.get(user_id, "FREE")
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        key = f"{user_id}_{today}"
        used = self.daily_scans.get(key, 0)
        daily_limit = 20 if tier == "FREE" else 999999

        return {
            "status": "SUCCESS",
            "user_id": user_id,
            "tier": tier,
            "is_premium": (tier == "PREMIUM"),
            "daily_limit": "UNLIMITED" if tier == "PREMIUM" else 20,
            "scans_used_today": used,
            "scans_remaining_today": "UNLIMITED" if tier == "PREMIUM" else max(0, daily_limit - used),
            "features": [
                "Real-time Species Identification (8 Classes)",
                "Multi-Organ Freshness & Biological Shelf-Life",
                "Live Market Prices Cross-Check (PKR/kg)",
                "AI Fishery & Recipe Chatbot Assistant"
            ] if tier == "FREE" else [
                "Unlimited Daily AI Fish Scans",
                "Priority GPU Inference Pipeline",
                "Export Full Commercial Quality Reports (PDF/CSV)",
                "Real-Time Wholesale Market Price Alert Feeds",
                "24/7 Unlimited AI Fishery Chatbot Access"
            ]
        }

    def record_scan(self, user_id: str = "default_user") -> bool:
        tier = self.user_tiers.get(user_id, "FREE")
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        key = f"{user_id}_{today}"
        used = self.daily_scans.get(key, 0)

        if tier == "FREE" and used >= 20:
            return False  # Limit reached

        self.daily_scans[key] = used + 1
        return True

    def upgrade_to_premium(self, user_id: str, payment_method: str = "JazzCash", amount_pkr: int = 999) -> Dict[str, Any]:
        self.user_tiers[user_id] = "PREMIUM"
        return {
            "status": "SUCCESS",
            "user_id": user_id,
            "tier": "PREMIUM",
            "payment_method": payment_method,
            "amount_paid_pkr": amount_pkr,
            "transaction_id": f"TXN-PK-{int(datetime.now().timestamp())}",
            "message": "Congratulations! Your account has been upgraded to Premium Access with Unlimited AI Fish Scans."
        }
