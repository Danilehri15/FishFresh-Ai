import os
import certifi
import hashlib
import uuid
from pymongo import MongoClient
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
from dotenv import load_dotenv

load_dotenv()

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
                    print(f"[CloudDB] Logged in user from MongoDB: {email}")
                    return {"success": True, "user_id": user["user_id"], "name": user.get("name", "User"), "plan": user.get("plan", "FREE")}
                return {"success": False, "error": "Invalid email or password"}
            except Exception as e:
                print(f"[CloudDB] Error logging in: {e}")
                return {"success": False, "error": f"Database error: {e}"}
                
        for uid, u in self.local_users.items():
            if isinstance(u, dict) and u.get("email") == email.lower().strip() and u.get("password") == hashed:
                return {"success": True, "user_id": uid, "name": u.get("name", "User"), "plan": u.get("plan", "FREE")}
        return {"success": False, "error": "Invalid email or password"}

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
