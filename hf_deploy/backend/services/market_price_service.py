from datetime import datetime, timezone
from typing import List, Dict, Any

MARKET_DATA = [
    {
        "species_id": "rohu",
        "display_name": "Rohu (Rahu)",
        "scientific_name": "Labeo rohita",
        "category": "Freshwater Major Carp",
        "karachi_harbour_pkr": 680,
        "lahore_market_pkr": 750,
        "islamabad_market_pkr": 800,
        "retail_avg_pkr": 740,
        "wholesale_avg_pkr": 620,
        "fair_price_min": 650,
        "fair_price_max": 850,
        "trend": "+2.5% (Stable)",
        "supply_status": "High (Freshwater Harvest)"
    },
    {
        "species_id": "sufaid_rohu",
        "display_name": "Sufaid Rohu (Silver Carp)",
        "scientific_name": "Hypophthalmichthys molitrix",
        "category": "Freshwater Silver Carp",
        "karachi_harbour_pkr": 520,
        "lahore_market_pkr": 600,
        "islamabad_market_pkr": 650,
        "retail_avg_pkr": 590,
        "wholesale_avg_pkr": 480,
        "fair_price_min": 500,
        "fair_price_max": 700,
        "trend": "0.0% (Stable)",
        "supply_status": "Abundant (Aquaculture)"
    },
    {
        "species_id": "tilapia",
        "display_name": "Dayya / Nile Tilapia",
        "scientific_name": "Oreochromis niloticus",
        "category": "Freshwater Cichlid",
        "karachi_harbour_pkr": 480,
        "lahore_market_pkr": 550,
        "islamabad_market_pkr": 600,
        "retail_avg_pkr": 540,
        "wholesale_avg_pkr": 440,
        "fair_price_min": 450,
        "fair_price_max": 650,
        "trend": "-1.8% (Surplus)",
        "supply_status": "High Supply"
    },
    {
        "species_id": "sulemani",
        "display_name": "Sulemani (Milkfish)",
        "scientific_name": "Chanos chanos",
        "category": "Coastal Marine / Brackish",
        "karachi_harbour_pkr": 750,
        "lahore_market_pkr": 850,
        "islamabad_market_pkr": 920,
        "retail_avg_pkr": 840,
        "wholesale_avg_pkr": 700,
        "fair_price_min": 750,
        "fair_price_max": 950,
        "trend": "+3.2% (Moderate Demand)",
        "supply_status": "Moderate"
    },
    {
        "species_id": "pomfret",
        "display_name": "Poplet (Silver Pomfret)",
        "scientific_name": "Pampus argenteus",
        "category": "Premium Coastal Marine",
        "karachi_harbour_pkr": 1400,
        "lahore_market_pkr": 1650,
        "islamabad_market_pkr": 1800,
        "retail_avg_pkr": 1620,
        "wholesale_avg_pkr": 1350,
        "fair_price_min": 1400,
        "fair_price_max": 1900,
        "trend": "+5.0% (High Export Demand)",
        "supply_status": "Limited Catch"
    },
    {
        "species_id": "salmon",
        "display_name": "Atlantic Salmon",
        "scientific_name": "Salmo salar",
        "category": "Imported / Cold-water Marine",
        "karachi_harbour_pkr": 2600,
        "lahore_market_pkr": 2850,
        "islamabad_market_pkr": 3100,
        "retail_avg_pkr": 2850,
        "wholesale_avg_pkr": 2400,
        "fair_price_min": 2500,
        "fair_price_max": 3300,
        "trend": "+1.1% (Import Rate Dependent)",
        "supply_status": "Imported Cold-Chain"
    },
    {
        "species_id": "anchovy",
        "display_name": "European Anchovy (Hamsi)",
        "scientific_name": "Engraulis encrasicolus",
        "category": "Small Marine Forage Fish",
        "karachi_harbour_pkr": 380,
        "lahore_market_pkr": 450,
        "islamabad_market_pkr": 500,
        "retail_avg_pkr": 440,
        "wholesale_avg_pkr": 320,
        "fair_price_min": 350,
        "fair_price_max": 550,
        "trend": "-3.0% (High Catch)",
        "supply_status": "High Catch"
    },
    {
        "species_id": "horsemackerel",
        "display_name": "Horse Mackerel (Istavrit)",
        "scientific_name": "Trachurus trachurus",
        "category": "Pelagic Marine Fish",
        "karachi_harbour_pkr": 580,
        "lahore_market_pkr": 650,
        "islamabad_market_pkr": 720,
        "retail_avg_pkr": 650,
        "wholesale_avg_pkr": 520,
        "fair_price_min": 550,
        "fair_price_max": 750,
        "trend": "+0.5% (Stable)",
        "supply_status": "Moderate"
    }
]

class MarketPriceService:
    def get_all_prices(self, city: str = "all") -> Dict[str, Any]:
        return {
            "status": "SUCCESS",
            "last_updated": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
            "currency": "PKR / kg",
            "market_sources": ["Karachi Fish Harbour (KFH)", "Lahore Wholesale Fish Market", "Islamabad G-9 Wholesale Terminal"],
            "data": MARKET_DATA
        }

    def evaluate_fair_price(self, species_id: str, asking_price_pkr: float, city: str = "lahore") -> Dict[str, Any]:
        matched = next((item for item in MARKET_DATA if item["species_id"] == species_id), None)
        if not matched:
            return {
                "status": "UNKNOWN_SPECIES",
                "message": "Species market rate data not found."
            }

        city_price = matched.get(f"{city.lower()}_market_pkr", matched["retail_avg_pkr"])
        fair_min = matched["fair_price_min"]
        fair_max = matched["fair_price_max"]

        if asking_price_pkr > fair_max * 1.15:
            verdict = "OVERPRICED"
            advice = f"Warning: The vendor's asking rate (Rs. {asking_price_pkr}/kg) is significantly higher than standard daily market rate (Rs. {fair_min} - {fair_max}/kg). Bargain down towards Rs. {city_price}/kg."
        elif asking_price_pkr < fair_min * 0.80:
            verdict = "SUSPICIOUSLY_LOW"
            advice = f"Caution: The asking rate (Rs. {asking_price_pkr}/kg) is far below normal market rate. Please inspect fish freshness, eyes, and gills carefully for spoilage."
        else:
            verdict = "FAIR_PRICE"
            advice = f"Fair deal: Asking rate of Rs. {asking_price_pkr}/kg matches standard retail rate in {city.title()} (Fair range: Rs. {fair_min} - {fair_max}/kg)."

        return {
            "status": "SUCCESS",
            "species_id": species_id,
            "display_name": matched["display_name"],
            "asking_price_pkr": asking_price_pkr,
            "standard_market_rate_pkr": city_price,
            "fair_price_range_pkr": f"Rs. {fair_min} - {fair_max} / kg",
            "verdict": verdict,
            "advice": advice
        }
