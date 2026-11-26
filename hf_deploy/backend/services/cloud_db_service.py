import os
import certifi
import hashlib
import uuid
from pymongo import MongoClient
from datetime import datetime, timedelta, timezone
from typing import Dict, Any, List, Optional
from dotenv import load_dotenv

load_dotenv()

DISABLED_MSG = "This account has been disabled by an administrator."
PREMIUM_PERIOD_DAYS = 30
PREMIUM_PRICE_PKR = 999


def _utc(dt):
    """MongoDB returns naive UTC datetimes; make them timezone-aware."""
    if isinstance(dt, datetime) and dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _iso(dt):
    dt = _utc(dt)
    return dt.isoformat() if isinstance(dt, datetime) else None


def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode('utf-8')).hexdigest()

class CloudDBService:
    def __init__(self):
        self.mongo_uri = os.getenv("MONGODB_URI")
        self.client = None
        self.db = None
        
        if self.mongo_uri:
            try:
                self.client = MongoClient(
                    self.mongo_uri,
                    tlsCAFile=certifi.where(),
                    serverSelectionTimeoutMS=2000,
                    connectTimeoutMS=2000
                )
                self.client.admin.command('ping')
                self.db = self.client["fish_fresh_db"]
                try:
                    self.db.users.create_index("email", unique=True)
                except Exception:
                    pass
                print("[CloudDB] Successfully connected to MongoDB Atlas!")
            except Exception as e:
                print(f"[CloudDB] Failed to connect to MongoDB Atlas: {e}")

        self.local_users = {}
        self.local_scans = []

    def register_user(self, email: str, password: str, name: str) -> Dict[str, Any]:
        user_id = str(uuid.uuid4())
        hashed = hash_password(password)
        
        user_doc = {
            "user_id": user_id,
            "email": email.lower().strip(),
            "password": hashed,
            "name": name.strip(),
            "plan": "FREE",
            "created_at": datetime.now(timezone.utc)
        }
        
        if self.db is not None:
            try:
                if self.db.users.find_one({"email": email.lower().strip()}):
                    return {"success": False, "error": "Email is already registered"}
                    
                self.db.users.insert_one(user_doc)
                print(f"[CloudDB] Registered user in MongoDB: {email}")
                return {"success": True, "user_id": user_id, "name": name, "plan": "FREE"}
            except Exception as e:
                print(f"[CloudDB] Error registering user: {e}")
                return {"success": False, "error": f"Database error: {e}"}
                
        if any(u.get("email") == email.lower().strip() for u in self.local_users.values() if isinstance(u, dict)):
            return {"success": False, "error": "Email is already registered"}
        self.local_users[user_id] = user_doc
        return {"success": True, "user_id": user_id, "name": name, "plan": "FREE"}

    def login_user(self, email: str, password: str) -> Dict[str, Any]:
        hashed = hash_password(password)
        
        if self.db is not None:
            try:
                user = self.db.users.find_one({"email": email.lower().strip(), "password": hashed})
                if user:
                    if user.get("disabled"):
                        return {"success": False, "error": DISABLED_MSG}
                    self.db.users.update_one({"_id": user["_id"]}, {"$set": {"last_login": datetime.now(timezone.utc)}})
                    print(f"[CloudDB] Logged in user from MongoDB: {email}")
                    return {"success": True, "user_id": user["user_id"], "name": user.get("name", "User"),
                            "email": user.get("email"), "plan": user.get("plan", "FREE")}
                return {"success": False, "error": "Invalid email or password"}
            except Exception as e:
                print(f"[CloudDB] Error logging in: {e}")
                return {"success": False, "error": f"Database error: {e}"}
                
        for uid, u in self.local_users.items():
            if isinstance(u, dict) and u.get("email") == email.lower().strip() and u.get("password") == hashed:
                return {"success": True, "user_id": uid, "name": u.get("name", "User"), "plan": u.get("plan", "FREE")}
        return {"success": False, "error": "Invalid email or password"}

    def google_login_or_register(self, email: str, name: str, google_id: Optional[str] = None, photo_url: Optional[str] = None) -> Dict[str, Any]:
        clean_email = email.lower().strip()
        clean_name = name.strip() if name and name.strip() else clean_email.split("@")[0].capitalize()
        gid = google_id or str(uuid.uuid4())
        
        if self.db is not None:
            try:
                user = self.db.users.find_one({"email": clean_email})
                if user and user.get("disabled"):
                    return {"success": False, "error": DISABLED_MSG}
                if user:
                    # User already exists in MongoDB: update login timestamp and Google details
                    update_data = {
                        "auth_provider": "google",
                        "google_id": gid,
                        "last_login": datetime.now(timezone.utc)
                    }
                    if photo_url:
                        update_data["photo_url"] = photo_url
                    if not user.get("name") or user.get("name") == "User":
                        update_data["name"] = clean_name

                    self.db.users.update_one({"_id": user["_id"]}, {"$set": update_data})
                    print(f"[CloudDB] Existing user logged in with Google via MongoDB: {clean_email}")
                    return {
                        "success": True,
                        "user_id": user["user_id"],
                        "name": user.get("name", clean_name),
                        "email": clean_email,
                        "photo_url": user.get("photo_url", photo_url),
                        "plan": user.get("plan", "FREE"),
                        "auth_provider": "google",
                        "is_new_user": False
                    }
                else:
                    # New user: AUTOMATICALLY register into MongoDB Atlas
                    user_id = str(uuid.uuid4())
                    user_doc = {
                        "user_id": user_id,
                        "email": clean_email,
                        "name": clean_name,
                        "google_id": gid,
                        "photo_url": photo_url,
                        "auth_provider": "google",
                        "plan": "FREE",
                        "created_at": datetime.now(timezone.utc),
                        "last_login": datetime.now(timezone.utc)
                    }
                    self.db.users.insert_one(user_doc)
                    print(f"[CloudDB] Automatically registered new Google user in MongoDB: {clean_email} (user_id: {user_id})")
                    return {
                        "success": True,
                        "user_id": user_id,
                        "name": clean_name,
                        "email": clean_email,
                        "photo_url": photo_url,
                        "plan": "FREE",
                        "auth_provider": "google",
                        "is_new_user": True
                    }
            except Exception as e:
                print(f"[CloudDB] Error in Google auth with MongoDB: {e}")
                
        # In-memory fallback if database connection is offline
        for uid, u in self.local_users.items():
            if isinstance(u, dict) and u.get("email") == clean_email:
                u["auth_provider"] = "google"
                if photo_url:
                    u["photo_url"] = photo_url
                return {
                    "success": True,
                    "user_id": uid,
                    "name": u.get("name", clean_name),
                    "email": clean_email,
                    "photo_url": u.get("photo_url", photo_url),
                    "plan": u.get("plan", "FREE"),
                    "auth_provider": "google",
                    "is_new_user": False
                }

        user_id = str(uuid.uuid4())
        user_doc = {
            "user_id": user_id,
            "email": clean_email,
            "name": clean_name,
            "google_id": gid,
            "photo_url": photo_url,
            "auth_provider": "google",
            "plan": "FREE",
            "created_at": datetime.now(timezone.utc),
            "last_login": datetime.now(timezone.utc)
        }
        self.local_users[user_id] = user_doc
        return {
            "success": True,
            "user_id": user_id,
            "name": clean_name,
            "email": clean_email,
            "photo_url": photo_url,
            "plan": "FREE",
            "auth_provider": "google",
            "is_new_user": True
        }

    def save_scan_history(self, user_id: str, scan_data: Dict[str, Any]):
        scan_record = {
            "user_id": user_id,
            "timestamp": datetime.now(timezone.utc),
            "scan_data": scan_data
        }
        if self.db is not None:
            try:
                self.db.scans.insert_one(scan_record)
                return True
            except Exception as e:
                print(f"[CloudDB] Error saving scan: {e}")
        self.local_scans.append(scan_record)
        return True

    def get_user_scans(self, user_id: str) -> List[Dict[str, Any]]:
        if self.db is not None:
            try:
                cursor = self.db.scans.find({"user_id": user_id}).sort("timestamp", -1).limit(20)
                results = []
                for doc in cursor:
                    doc["_id"] = str(doc["_id"])
                    results.append(doc)
                return results
            except Exception as e:
                print(f"[CloudDB] Error fetching scans: {e}")
        return [s for s in self.local_scans if s["user_id"] == user_id]

    def upgrade_user_plan(self, user_id: str, plan_name: str) -> bool:
        if self.db is not None:
            try:
                self.db.users.update_one(
                    {"user_id": user_id},
                    {"$set": {"plan": plan_name, "updated_at": datetime.now(timezone.utc)}},
                    upsert=True
                )
                return True
            except Exception as e:
                print(f"[CloudDB] Error upgrading plan: {e}")
        
        if user_id not in self.local_users or not isinstance(self.local_users[user_id], dict):
            self.local_users[user_id] = {}
        self.local_users[user_id]["plan"] = plan_name
        return True

    def get_user_plan(self, user_id: str) -> str:
        if self.db is not None:
            try:
                user = self.db.users.find_one({"user_id": user_id})
                if user and "plan" in user:
                    return user["plan"]
                return "FREE"
            except Exception as e:
                print(f"[CloudDB] Error fetching plan: {e}")
        u = self.local_users.get(user_id)
        if isinstance(u, dict):
            return u.get("plan", "FREE")
        return "FREE"

    # ------------------------------------------------------------------
    # Subscriptions (persisted in MongoDB: users.plan / plan_expires_at,
    # every payment stored in the `payments` collection)
    # ------------------------------------------------------------------

    @staticmethod
    def _days_left(expires: Optional[datetime]) -> Optional[int]:
        if not expires:
            return None
        secs = (expires - datetime.now(timezone.utc)).total_seconds()
        return max(0, int(-(-secs // 86400)))  # ceil to whole days

    def get_effective_plan(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Plan for a stored user, auto-downgrading expired Premium. None if user unknown."""
        if self.db is None:
            return None
        try:
            user = self.db.users.find_one({"user_id": user_id})
        except Exception as e:
            print(f"[CloudDB] Error reading plan: {e}")
            return None
        if not user:
            return None
        plan = user.get("plan", "FREE")
        expires = _utc(user.get("plan_expires_at"))
        if plan == "PREMIUM" and expires and expires <= datetime.now(timezone.utc):
            self.db.users.update_one({"_id": user["_id"]}, {"$set": {"plan": "FREE", "plan_expired_at": expires}})
            plan, expires = "FREE", None
        if plan != "PREMIUM":
            expires = None
        return {"plan": plan, "plan_expires_at": expires, "days_remaining": self._days_left(expires)}

    def activate_premium(self, user_id: str, payment_method: str, amount_pkr: int, transaction_id: str,
                         days: int = PREMIUM_PERIOD_DAYS, granted_by: Optional[str] = None) -> Optional[datetime]:
        """Start or extend Premium by `days` and record the payment. Returns the new expiry."""
        if self.db is None:
            return None
        user = self.db.users.find_one({"user_id": user_id})
        if not user:
            return None
        now = datetime.now(timezone.utc)
        current = _utc(user.get("plan_expires_at"))
        still_active = user.get("plan") == "PREMIUM" and current is not None and current > now
        base = current if still_active else now
        new_expiry = base + timedelta(days=days)
        update = {"plan": "PREMIUM", "plan_expires_at": new_expiry, "updated_at": now}
        if not still_active:
            update["plan_started_at"] = now
        self.db.users.update_one({"_id": user["_id"]}, {"$set": update})
        self.db.payments.insert_one({
            "transaction_id": transaction_id,
            "user_id": user_id,
            "email": user.get("email"),
            "name": user.get("name"),
            "amount_pkr": int(amount_pkr),
            "payment_method": payment_method,
            "days": days,
            "granted_by": granted_by,
            "created_at": now,
        })
        return new_expiry

    def revoke_premium(self, user_id: str) -> bool:
        if self.db is None:
            return False
        res = self.db.users.update_one(
            {"user_id": user_id},
            {"$set": {"plan": "FREE", "plan_expires_at": None, "updated_at": datetime.now(timezone.utc)}})
        return res.matched_count > 0

    # ------------------------------------------------------------------
    # Admin queries
    # ------------------------------------------------------------------

    def _serialize_user(self, u: Dict[str, Any], scan_counts: Dict[str, int], paid: Dict[str, int],
                        admin_emails) -> Dict[str, Any]:
        plan = u.get("plan", "FREE")
        expires = _utc(u.get("plan_expires_at"))
        if plan == "PREMIUM" and expires and expires <= datetime.now(timezone.utc):
            plan = "FREE"  # expired; DB is corrected on the user's next status check
        if plan != "PREMIUM":
            expires = None
        uid = u.get("user_id")
        email = (u.get("email") or "").lower()
        return {
            "user_id": uid,
            "name": u.get("name") or "User",
            "email": email,
            "photo_url": u.get("photo_url"),
            "plan": plan,
            "auth_provider": u.get("auth_provider") or "email",
            "created_at": _iso(u.get("created_at")),
            "last_login": _iso(u.get("last_login")),
            "plan_started_at": _iso(u.get("plan_started_at")) if plan == "PREMIUM" else None,
            "plan_expires_at": _iso(expires),
            "days_remaining": self._days_left(expires),
            "scan_count": scan_counts.get(uid, 0),
            "total_paid_pkr": paid.get(uid, 0),
            "disabled": bool(u.get("disabled")),
            "is_admin": email in admin_emails,
        }

    def _scan_counts(self) -> Dict[str, int]:
        pipeline = [{"$group": {"_id": "$user_id", "n": {"$sum": 1}}}]
        return {d["_id"]: d["n"] for d in self.db.scans.aggregate(pipeline)}

    def _paid_totals(self) -> Dict[str, int]:
        pipeline = [{"$group": {"_id": "$user_id", "total": {"$sum": "$amount_pkr"}}}]
        return {d["_id"]: d["total"] for d in self.db.payments.aggregate(pipeline)}

    def admin_list_users(self, admin_emails) -> List[Dict[str, Any]]:
        counts, paid = self._scan_counts(), self._paid_totals()
        users = self.db.users.find({"user_id": {"$exists": True}, "email": {"$exists": True}},
                                   {"password": 0}).sort("created_at", -1)
        return [self._serialize_user(u, counts, paid, admin_emails) for u in users]

    @staticmethod
    def _serialize_payment(p: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "transaction_id": p.get("transaction_id"),
            "user_id": p.get("user_id"),
            "email": p.get("email"),
            "name": p.get("name"),
            "amount_pkr": int(p.get("amount_pkr") or 0),
            "payment_method": p.get("payment_method"),
            "days": p.get("days"),
            "granted_by": p.get("granted_by"),
            "created_at": _iso(p.get("created_at")),
        }

    def admin_user_detail(self, user_id: str, admin_emails) -> Optional[Dict[str, Any]]:
        u = self.db.users.find_one({"user_id": user_id}, {"password": 0})
        if not u:
            return None
        scans = []
        for s in self.db.scans.find({"user_id": user_id}).sort("timestamp", -1).limit(200):
            data = dict(s.get("scan_data") or {})
            data["scanned_at"] = _iso(s.get("timestamp"))
            scans.append(data)
        payments = [self._serialize_payment(p)
                    for p in self.db.payments.find({"user_id": user_id}).sort("created_at", -1)]
        info = self._serialize_user(
            u,
            {user_id: self.db.scans.count_documents({"user_id": user_id})},
            {user_id: sum(p["amount_pkr"] for p in payments)},
            admin_emails,
        )
        return {"user": info, "scans": scans, "payments": payments}

    def admin_list_payments(self, limit: int = 200) -> List[Dict[str, Any]]:
        return [self._serialize_payment(p) for p in self.db.payments.find().sort("created_at", -1).limit(limit)]

    def admin_set_disabled(self, user_id: str, disabled: bool) -> bool:
        return self.db.users.update_one({"user_id": user_id}, {"$set": {"disabled": disabled}}).matched_count > 0

    def admin_delete_user(self, user_id: str) -> bool:
        """Deletes the account and its scan history. Payment records are kept for accounting."""
        res = self.db.users.delete_one({"user_id": user_id})
        if res.deleted_count:
            self.db.scans.delete_many({"user_id": user_id})
        return res.deleted_count > 0

    def admin_stats(self, admin_emails) -> Dict[str, Any]:
        now = datetime.now(timezone.utc)
        today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        month_start = today.replace(day=1)
        week_ago = now - timedelta(days=7)
        long_ago = now - timedelta(days=3650)

        users = self.admin_list_users(admin_emails)
        premium = [u for u in users if u["plan"] == "PREMIUM"]

        def parse(s):
            return datetime.fromisoformat(s) if s else long_ago

        signups = {(today - timedelta(days=i)).strftime("%Y-%m-%d"): 0 for i in range(13, -1, -1)}
        for u in users:
            key = parse(u["created_at"]).strftime("%Y-%m-%d")
            if key in signups:
                signups[key] += 1

        months = []
        y, m = month_start.year, month_start.month
        for _ in range(6):
            months.insert(0, f"{y:04d}-{m:02d}")
            y, m = (y - 1, 12) if m == 1 else (y, m - 1)
        revenue_by_month = {k: 0 for k in months}
        total_revenue = revenue_month = 0
        payments = list(self.db.payments.find({}, {"amount_pkr": 1, "created_at": 1}))
        for p in payments:
            amt = int(p.get("amount_pkr") or 0)
            total_revenue += amt
            c = _utc(p.get("created_at"))
            if c:
                if c >= month_start:
                    revenue_month += amt
                k = c.strftime("%Y-%m")
                if k in revenue_by_month:
                    revenue_by_month[k] += amt

        species_pipeline = [
            {"$match": {"scan_data.species_detection.predicted_species": {"$exists": True}}},
            {"$group": {"_id": "$scan_data.species_detection.predicted_species", "n": {"$sum": 1}}},
            {"$sort": {"n": -1}},
            {"$limit": 6},
        ]
        species = [{"species": d["_id"], "count": d["n"]} for d in self.db.scans.aggregate(species_pipeline)]

        expiring = sorted(
            [{"user_id": u["user_id"], "name": u["name"], "email": u["email"], "days_remaining": u["days_remaining"]}
             for u in premium if u["days_remaining"] is not None and u["days_remaining"] <= 7],
            key=lambda x: x["days_remaining"])

        return {
            "total_users": len(users),
            "premium_users": len(premium),
            "free_users": len(users) - len(premium),
            "google_users": sum(1 for u in users if u["auth_provider"] == "google"),
            "email_users": sum(1 for u in users if u["auth_provider"] != "google"),
            "disabled_users": sum(1 for u in users if u["disabled"]),
            "new_users_7d": sum(1 for u in users if parse(u["created_at"]) >= week_ago),
            "active_users_7d": sum(1 for u in users if parse(u["last_login"]) >= week_ago),
            "total_revenue_pkr": total_revenue,
            "revenue_this_month_pkr": revenue_month,
            "projected_monthly_revenue_pkr": len(premium) * PREMIUM_PRICE_PKR,
            "total_payments": len(payments),
            "total_scans": self.db.scans.count_documents({}),
            "scans_today": self.db.scans.count_documents({"timestamp": {"$gte": today}}),
            "scans_7d": self.db.scans.count_documents({"timestamp": {"$gte": week_ago}}),
            "fresh_scans": self.db.scans.count_documents({"scan_data.freshness_detection.is_fresh": True}),
            "spoiled_scans": self.db.scans.count_documents({"scan_data.freshness_detection.is_fresh": False}),
            "top_species": species,
            "expiring_soon": expiring,
            "signups_last_14_days": [{"date": k, "count": v} for k, v in signups.items()],
            "revenue_last_6_months": [{"month": k, "amount_pkr": v} for k, v in revenue_by_month.items()],
        }
