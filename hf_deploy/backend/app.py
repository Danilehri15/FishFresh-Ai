import os
import traceback
from pathlib import Path
from fastapi import FastAPI, File, UploadFile, Query, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional

from backend.services.ai_engine import AIEngine, SPECIES_METADATA_MAP
from backend.services.market_price_service import MarketPriceService
from backend.services.chatbot_service import ChatbotService
from backend.services.subscription_service import SubscriptionService
from backend.services.storage_advisor import StorageAdvisor
from backend.services.market_recommendation_service import MarketRecommendationService
from backend.services.cloud_db_service import CloudDBService

app = FastAPI(
    title="Fish Fresh AI Backend",
    description="FYP: Multi-Organ Fish Freshness & Species Detection System API",
    version="1.0.0"
)

# Enable CORS for Flutter Mobile, Web, and Desktop
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Services
ai_engine = AIEngine()
market_service = MarketPriceService()
chatbot_service = ChatbotService()
subscription_service = SubscriptionService()
market_rec_service = MarketRecommendationService()
cloud_db = CloudDBService()

# Request Models

class RegisterRequest(BaseModel):
    email: str
    password: str
    name: str

class LoginRequest(BaseModel):
    email: str
    password: str

class ChatRequest(BaseModel):
    query: str
    current_species: Optional[str] = None

class UpgradeRequest(BaseModel):
    user_id: str = "default_user"
    payment_method: str = "JazzCash"  # JazzCash, SadaPay, GooglePlay, Card
    amount_pkr: int = 999

class FairPriceCheckRequest(BaseModel):
    species_id: str
    asking_price_pkr: float
    city: str = "lahore"

class ScanLocationRequest(BaseModel):
    latitude: float
    longitude: float
    species: str
    freshness_score: float  # 0-1
    is_fresh: bool
    user_id: str = "default_user"

@app.get("/api/health")
def health_check():
    return {
        "status": "HEALTHY",
        "service": "Fish Fresh AI Backend API",
        "modules_active": [
            "Module 1: Fish Species Identification (8 Classes)",
            "Module 2: Multi-Organ Freshness & Shelf-Life Estimation",
            "Module 3: Dynamic Storage & Temperature Guidance",
            "Module 6.3: Smart Market Area Recommendations (GPS Heatmap)",
            "Module 6.4: Live Market Price Synchronization",
            "Module 6.5: AI Fishery & Culinary Chatbot",
            "Module 6.6: Subscription & Premium Access (Freemium)"
        ]
    }

@app.post("/api/predict")
async def predict_fish_image(
    file: UploadFile = File(...),
    user_id: str = Form("default_user")
):
    try:
        # Check subscription quota
        can_scan = subscription_service.record_scan(user_id)
        if not can_scan:
            raise HTTPException(
                status_code=429,
                detail="Daily free scan limit reached (200 scans/day). Please upgrade to Premium Access for unlimited scans."
            )

        image_bytes = await file.read()
        if len(image_bytes) == 0:
            raise HTTPException(status_code=400, detail="Empty image file received.")

        result = ai_engine.predict(image_bytes, filename=file.filename)
        
        # Attach Live Market Price Comparison if fish recognized
        if result.get("is_fish") and result.get("status") == "SUCCESS":
            sp_id = result["species_detection"]["predicted_species"]
            fair_price_data = market_service.evaluate_fair_price(
                species_id=sp_id,
                asking_price_pkr=result["species_detection"]["typical_market_price_pkr"]
            )
            result["market_price_info"] = fair_price_data
            cloud_db.save_scan_history(user_id, result)

        return result
    except HTTPException:
        raise
    except Exception as e:
        tb = traceback.format_exc()
        print(f"[PREDICT ERROR] {tb}")
        raise HTTPException(status_code=500, detail=f"Predict error: {str(e)}")

@app.get("/api/market-prices")
def get_market_prices(city: str = "all"):
    return market_service.get_all_prices(city=city)

@app.post("/api/market-prices/check")
def check_fair_price(payload: FairPriceCheckRequest):
    return market_service.evaluate_fair_price(
        species_id=payload.species_id,
        asking_price_pkr=payload.asking_price_pkr,
        city=payload.city
    )

@app.post("/api/chat")
def fishery_chatbot(payload: ChatRequest):
    return chatbot_service.handle_query(query=payload.query, current_species=payload.current_species)

@app.get("/api/subscription/status")
def get_subscription_status(user_id: str = "default_user"):
    return subscription_service.get_user_status(user_id=user_id)

@app.post("/api/subscription/upgrade")
def upgrade_subscription(payload: UpgradeRequest):
    return subscription_service.upgrade_to_premium(
        user_id=payload.user_id,
        payment_method=payload.payment_method,
        amount_pkr=payload.amount_pkr
    )

@app.get("/api/species")
def get_species_catalog():
    return {
        "status": "SUCCESS",
        "total_species": len(SPECIES_METADATA_MAP),
        "species": [
            {"id": k, **v} for k, v in SPECIES_METADATA_MAP.items()
        ]
    }

@app.get("/api/user/scans")
def get_user_scans(user_id: str = "default_user"):
    scans = cloud_db.get_user_scans(user_id)
    return {
        "status": "SUCCESS",
        "user_id": user_id,
        "scans": [s["scan_data"] for s in scans]
    }

@app.post("/api/scan-location")
def record_scan_location(payload: ScanLocationRequest):
    return market_rec_service.record_scan(
        latitude=payload.latitude,
        longitude=payload.longitude,
        species=payload.species,
        freshness_score=payload.freshness_score,
        is_fresh=payload.is_fresh,
        user_id=payload.user_id
    )

@app.get("/api/heatmap")
def get_heatmap(city: str = "all"):
    markets = market_rec_service.get_heatmap_data(city=city)
    return {
        "status": "SUCCESS",
        "city_filter": city,
        "total_markets": len(markets),
        "markets": markets
    }

@app.get("/api/recommended-markets")
def get_recommended_markets(city: str = "all", top_n: int = 5):
    markets = market_rec_service.get_recommended_markets(city=city, top_n=top_n)
    return {
        "status": "SUCCESS",
        "total": len(markets),
        "recommended_markets": markets
    }

@app.get("/api/avoid-markets")
def get_avoid_markets(city: str = "all"):
    markets = market_rec_service.get_avoid_markets(city=city)
    return {
        "status": "SUCCESS",
        "total": len(markets),
        "avoid_markets": markets
    }

@app.get("/api/market-scans/{market_name}")
def get_market_scans(market_name: str, limit: int = 20):
    scans = market_rec_service.get_scan_history_for_area(market_name=market_name, limit=limit)
    return {
        "status": "SUCCESS",
        "market_name": market_name,
        "total_scans": len(scans),
        "scans": scans
    }




@app.post("/api/auth/register")
def register(payload: RegisterRequest):
    try:
        res = cloud_db.register_user(payload.email, payload.password, payload.name)
        if res.get("success"):
            return res
        raise HTTPException(status_code=400, detail=res.get("error", "Registration failed"))
    except HTTPException:
        raise
    except Exception as e:
        print(f"[Auth] Register exception: {e}")
        raise HTTPException(status_code=500, detail=f"Server error: {e}")

@app.post("/api/auth/login")
def login(payload: LoginRequest):
    try:
        res = cloud_db.login_user(payload.email, payload.password)
        if res.get("success"):
            return res
        raise HTTPException(status_code=401, detail=res.get("error", "Invalid credentials"))
    except HTTPException:
        raise
    except Exception as e:
        print(f"[Auth] Login exception: {e}")
        raise HTTPException(status_code=500, detail=f"Server error: {e}")

