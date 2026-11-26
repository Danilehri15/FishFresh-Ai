"""Admin API: login (email/password or Google), dashboard stats, user management.

Only emails listed in the ADMIN_EMAILS environment variable (comma-separated)
can sign in as admin. Admin sessions use an HMAC-signed bearer token; set
ADMIN_TOKEN_SECRET so tokens survive server restarts.
"""
import base64
import hashlib
import hmac
import os
import secrets
import time
from typing import Callable, Optional

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel

TOKEN_TTL_SECONDS = 12 * 60 * 60
_SECRET = (os.getenv("ADMIN_TOKEN_SECRET") or secrets.token_hex(32)).encode()


def admin_emails() -> set:
    return {e.strip().lower() for e in os.getenv("ADMIN_EMAILS", "").split(",") if e.strip()}


def _sign(payload: str) -> str:
    return hmac.new(_SECRET, payload.encode(), hashlib.sha256).hexdigest()


def make_admin_token(email: str) -> str:
    payload = f"{email.lower()}|{int(time.time()) + TOKEN_TTL_SECONDS}"
    return base64.urlsafe_b64encode(f"{payload}|{_sign(payload)}".encode()).decode()


def read_admin_token(token: str) -> Optional[str]:
    try:
        email, exp, sig = base64.urlsafe_b64decode(token.encode()).decode().rsplit("|", 2)
    except Exception:
        return None
    if not hmac.compare_digest(sig, _sign(f"{email}|{exp}")) or int(exp) < time.time():
        return None
    return email if email in admin_emails() else None


class AdminLoginRequest(BaseModel):
    email: str
    password: str


class AdminGoogleRequest(BaseModel):
    id_token: str


class GrantPremiumRequest(BaseModel):
    days: int = 30


class DisableRequest(BaseModel):
    disabled: bool


def build_admin_router(cloud_db, verify_google_id_token: Callable[[str], dict]) -> APIRouter:
    router = APIRouter(prefix="/api/admin", tags=["admin"])

    def require_db():
        if cloud_db.db is None:
            raise HTTPException(status_code=503, detail="Database is offline.")

    def require_admin(authorization: Optional[str]) -> str:
        if not authorization or not authorization.lower().startswith("bearer "):
            raise HTTPException(status_code=401, detail="Admin login required.")
        email = read_admin_token(authorization.split(" ", 1)[1].strip())
        if not email:
            raise HTTPException(status_code=401, detail="Admin session expired. Please log in again.")
        require_db()
        return email

    def check_allowed(email: str):
        allowed = admin_emails()
        if not allowed:
            raise HTTPException(status_code=403,
                                detail="No admins configured. Set ADMIN_EMAILS on the server.")
        if email.lower() not in allowed:
            raise HTTPException(status_code=403, detail="This account is not an admin.")

    def session(email: str, name: str):
        return {"success": True, "token": make_admin_token(email), "email": email.lower(),
                "name": name, "expires_in": TOKEN_TTL_SECONDS}

    # ---------- auth ----------

    @router.post("/login")
    def admin_login(payload: AdminLoginRequest):
        check_allowed(payload.email)
        res = cloud_db.login_user(payload.email, payload.password)
        if not res.get("success"):
            raise HTTPException(status_code=401, detail=res.get("error", "Invalid email or password"))
        return session(payload.email, res.get("name", "Admin"))

    @router.post("/google")
    def admin_google(payload: AdminGoogleRequest):
        claims = verify_google_id_token(payload.id_token)
        email = claims["email"]
        check_allowed(email)
        # Creates the admin's account on first Google sign-in (Google sign-up for admins).
        res = cloud_db.google_login_or_register(
            email=email, name=claims.get("name") or email.split("@")[0],
            google_id=claims.get("sub"), photo_url=claims.get("picture"))
        if not res.get("success"):
            raise HTTPException(status_code=401, detail=res.get("error", "Google sign-in failed"))
        return session(email, res.get("name", "Admin"))

    @router.get("/me")
    def admin_me(authorization: Optional[str] = Header(None)):
        return {"email": require_admin(authorization)}

    # ---------- dashboard ----------

    @router.get("/stats")
    def admin_stats(authorization: Optional[str] = Header(None)):
        require_admin(authorization)
        return cloud_db.admin_stats(admin_emails())

    @router.get("/users")
    def admin_users(authorization: Optional[str] = Header(None)):
        require_admin(authorization)
        users = cloud_db.admin_list_users(admin_emails())
        return {"total": len(users), "users": users}

    @router.get("/users/{user_id}")
    def admin_user(user_id: str, authorization: Optional[str] = Header(None)):
        require_admin(authorization)
        detail = cloud_db.admin_user_detail(user_id, admin_emails())
        if not detail:
            raise HTTPException(status_code=404, detail="User not found.")
        return detail

    @router.get("/payments")
    def admin_payments(authorization: Optional[str] = Header(None)):
        require_admin(authorization)
        payments = cloud_db.admin_list_payments()
        return {"total": len(payments), "payments": payments}

    # ---------- actions ----------

    def target_email(user_id: str) -> str:
        u = cloud_db.db.users.find_one({"user_id": user_id}, {"email": 1})
        if not u:
            raise HTTPException(status_code=404, detail="User not found.")
        return (u.get("email") or "").lower()

    @router.post("/users/{user_id}/premium")
    def admin_grant_premium(user_id: str, payload: GrantPremiumRequest,
                            authorization: Optional[str] = Header(None)):
        admin = require_admin(authorization)
        target_email(user_id)
        if not 1 <= payload.days <= 365:
            raise HTTPException(status_code=400, detail="Days must be between 1 and 365.")
        expiry = cloud_db.activate_premium(
            user_id, payment_method="Admin grant", amount_pkr=0,
            transaction_id=f"ADMIN-{int(time.time())}", days=payload.days, granted_by=admin)
        return {"success": True, "plan_expires_at": expiry.isoformat() if expiry else None}

    @router.post("/users/{user_id}/revoke")
    def admin_revoke(user_id: str, authorization: Optional[str] = Header(None)):
        require_admin(authorization)
        target_email(user_id)
        cloud_db.revoke_premium(user_id)
        return {"success": True}

    @router.post("/users/{user_id}/disable")
    def admin_disable(user_id: str, payload: DisableRequest, authorization: Optional[str] = Header(None)):
        admin = require_admin(authorization)
        if target_email(user_id) == admin:
            raise HTTPException(status_code=400, detail="You cannot disable your own admin account.")
        cloud_db.admin_set_disabled(user_id, payload.disabled)
        return {"success": True, "disabled": payload.disabled}

    @router.delete("/users/{user_id}")
    def admin_delete(user_id: str, authorization: Optional[str] = Header(None)):
        admin = require_admin(authorization)
        if target_email(user_id) == admin:
            raise HTTPException(status_code=400, detail="You cannot delete your own admin account.")
        cloud_db.admin_delete_user(user_id)
        return {"success": True}

    return router
