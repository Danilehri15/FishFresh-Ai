import uuid
import datetime
import random
import math

class MarketRecommendationService:
    def __init__(self):
        self.known_markets = [
            {"name": "Karachi Harbour Fish Market", "lat": 24.8480, "lon": 67.0030, "city": "Karachi"},
            {"name": "Empress Market area", "lat": 24.8615, "lon": 67.0285, "city": "Karachi"},
            {"name": "Lee Market", "lat": 24.8580, "lon": 67.0250, "city": "Karachi"},
            {"name": "Seaview Beach Fish Stalls", "lat": 24.8320, "lon": 67.0360, "city": "Karachi"},
            {"name": "West Wharf Fish Harbour", "lat": 24.8445, "lon": 67.0045, "city": "Karachi"},
            {"name": "Lahore Fish Market Ichra", "lat": 31.5300, "lon": 74.3200, "city": "Lahore"},
            {"name": "Mughalpura Fish Market", "lat": 31.5700, "lon": 74.3650, "city": "Lahore"},
            {"name": "Anarkali Bazaar", "lat": 31.5600, "lon": 74.3100, "city": "Lahore"},
            {"name": "Aabpara Market", "lat": 33.7100, "lon": 73.0600, "city": "Islamabad"},
            {"name": "Raja Bazaar Rawalpindi", "lat": 33.6000, "lon": 73.0500, "city": "Rawalpindi"},
            {"name": "F-7 Markaz", "lat": 33.7200, "lon": 73.0550, "city": "Islamabad"},
        ]
        self.scans = []
        self._seed_data()

    def _seed_data(self):
        species_list = ["Rohu", "Malla", "Trout", "Tilapia", "Mackerel"]
        now = datetime.datetime.now(datetime.timezone.utc)
        for _ in range(500):
            # Pick a market and slightly randomize location
            market = random.choice(self.known_markets)
            lat = market["lat"] + random.uniform(-0.005, 0.005)
            lon = market["lon"] + random.uniform(-0.005, 0.005)
            
            # Simulate different qualities for different markets
            if market["name"] in ["Karachi Harbour Fish Market", "Aabpara Market"]:
                # Mostly fresh
                score = random.uniform(0.7, 1.0)
            elif market["name"] in ["Anarkali Bazaar", "Lee Market"]:
                # Mostly spoiled
                score = random.uniform(0.1, 0.5)
            else:
                # Mix
                score = random.uniform(0.2, 0.9)
                
            is_fresh = score >= 0.5
            timestamp = (now - datetime.timedelta(days=random.randint(0, 10), hours=random.randint(0, 24))).isoformat()
            
            self.scans.append({
                "scan_id": str(uuid.uuid4()),
                "latitude": lat,
                "longitude": lon,
                "species": random.choice(species_list),
                "freshness_score": score,
                "is_fresh": is_fresh,
                "market_area": market["name"],
                "timestamp": timestamp,
                "user_id": f"user_{random.randint(1, 20)}"
            })

    def _haversine(self, lat1, lon1, lat2, lon2):
        R = 6371.0 # Earth radius in km
        dLat = math.radians(lat2 - lat1)
        dLon = math.radians(lon2 - lon1)
        a = math.sin(dLat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dLon / 2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        distance = R * c
        return distance

    def _get_nearest_market(self, lat, lon):
        nearest = None
        min_dist = float('inf')
        for market in self.known_markets:
            dist = self._haversine(lat, lon, market["lat"], market["lon"])
            if dist < min_dist:
                min_dist = dist
                nearest = market
        if nearest is None or min_dist > 3.0:`n            new_market_name = f"Live Scan Area ({round(lat, 3)}, {round(lon, 3)})"`n            self.known_markets.append({`n                "name": new_market_name,`n                "lat": lat,`n                "lon": lon,`n                "city": "All"`n            })`n            return new_market_name`n`n        return nearest["name"]

    def record_scan(self, latitude, longitude, species, freshness_score, is_fresh, user_id):
        market_area = self._get_nearest_market(latitude, longitude)
        scan = {
            "scan_id": str(uuid.uuid4()),
            "latitude": latitude,
            "longitude": longitude,
            "species": species,
            "freshness_score": freshness_score,
            "is_fresh": is_fresh,
            "market_area": market_area,
            "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "user_id": user_id
        }
        self.scans.append(scan)
        return scan

    def get_heatmap_data(self, city=None):
        market_stats = {}
        for market in self.known_markets:
            if city and city.lower() != "all" and market["city"].lower() != city.lower():
                continue
            market_stats[market["name"]] = {
                "market_name": market["name"],
                "latitude": market["lat"],
                "longitude": market["lon"],
                "city": market["city"],
                "total_scans": 0,
                "fresh_count": 0,
                "spoiled_count": 0,
                "score_sum": 0.0
            }

        for scan in self.scans:
            m_name = scan["market_area"]
            if m_name in market_stats:
                market_stats[m_name]["total_scans"] += 1
                if scan["is_fresh"]:
                    market_stats[m_name]["fresh_count"] += 1
                else:
                    market_stats[m_name]["spoiled_count"] += 1
                market_stats[m_name]["score_sum"] += scan["freshness_score"]

        results = []
        for name, stats in market_stats.items():
            if stats["total_scans"] > 0:
                avg_score = stats["score_sum"] / stats["total_scans"]
            else:
                avg_score = 0.0
                
            stats["avg_freshness_score"] = avg_score
            del stats["score_sum"]

            if stats["total_scans"] == 0:
                stats["quality_rating"] = "UNKNOWN"
                stats["color_hex"] = "#9E9E9E"
                stats["recommendation"] = "Not enough data"
            elif avg_score >= 0.8:
                stats["quality_rating"] = "EXCELLENT"
                stats["color_hex"] = "#2E7D32"
                stats["recommendation"] = "Highly recommended for fresh fish."
            elif avg_score >= 0.6:
                stats["quality_rating"] = "GOOD"
                stats["color_hex"] = "#66BB6A"
                stats["recommendation"] = "Good quality generally available."
            elif avg_score >= 0.4:
                stats["quality_rating"] = "CAUTION"
                stats["color_hex"] = "#FF9800"
                stats["recommendation"] = "Mixed quality. Inspect carefully before buying."
            else:
                stats["quality_rating"] = "AVOID"
                stats["color_hex"] = "#C62828"
                stats["recommendation"] = "High rates of spoiled fish detected. Avoid."

            results.append(stats)
            
        return results

    def get_recommended_markets(self, city=None, top_n=5):
        heatmap = self.get_heatmap_data(city)
        # Filter out unknown and avoid
        valid = [m for m in heatmap if m["quality_rating"] in ["EXCELLENT", "GOOD", "CAUTION"]]
        valid.sort(key=lambda x: x["avg_freshness_score"], reverse=True)
        return valid[:top_n]

    def get_avoid_markets(self, city=None):
        heatmap = self.get_heatmap_data(city)
        avoid = [m for m in heatmap if m["quality_rating"] in ["AVOID", "CAUTION"]]
        avoid.sort(key=lambda x: x["avg_freshness_score"])
        return avoid

    def get_scan_history_for_area(self, market_name, limit=20):
        market_scans = [s for s in self.scans if s["market_area"].lower() == market_name.lower()]
        market_scans.sort(key=lambda x: x["timestamp"], reverse=True)
        return market_scans[:limit]

