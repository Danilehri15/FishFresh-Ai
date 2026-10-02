import json
import io
from pathlib import Path
from typing import Dict, Any, Tuple, Optional
import numpy as np
from PIL import Image
import tensorflow as tf

PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
MODELS_DIR = PROJECT_DIR / "models"
DEFAULT_IMAGE_SIZE = (224, 224)

SPECIES_METADATA_MAP = {
    "rohu": {
        "display_name": "Rohu",
        "local_name": "Rahu / Rohu Mach",
        "scientific_name": "Labeo rohita",
        "category": "Freshwater Major Carp",
        "typical_market_price_pkr": 750,
        "description": "The most popular freshwater carp in Pakistan. Known for its firm, flavorful white flesh, high protein, and cultural importance in Pakistani cuisine."
    },
    "sufaid_rohu": {
        "display_name": "Sufaid Rohu / Silver Carp",
        "local_name": "Sufaid Rahu",
        "scientific_name": "Hypophthalmichthys molitrix",
        "category": "Freshwater Silver Carp",
        "typical_market_price_pkr": 600,
        "description": "A silvery freshwater carp cultivated widely across Punjab and Sindh aquaculture farms. Lean texture with delicate, tender meat."
    },
    "tilapia": {
        "display_name": "Dayya / Nile Tilapia",
        "local_name": "Dayya",
        "scientific_name": "Oreochromis niloticus",
        "category": "Freshwater Cichlid",
        "typical_market_price_pkr": 550,
        "description": "Fast-growing, mild-flavored freshwater fish known locally as Dayya. Very popular for pan-frying, whole grilling, and daily household cooking."
    },
    "sulemani": {
        "display_name": "Sulemani / Milkfish",
        "local_name": "Sulemani",
        "scientific_name": "Chanos chanos",
        "category": "Coastal Marine / Brackish",
        "typical_market_price_pkr": 850,
        "description": "Prized coastal and brackish water fish with bright silver scales. Tender, sweet, and rich in healthy omega-3 fatty acids."
    },
    "pomfret": {
        "display_name": "Poplet / Silver Pomfret",
        "local_name": "Poplet / White Pomfret",
        "scientific_name": "Pampus argenteus",
        "category": "Premium Marine Fish",
        "typical_market_price_pkr": 1600,
        "description": "Pakistan's premium coastal marine fish. Diamond-shaped with soft, butter-textured flesh, single bone structure, and exceptional taste."
    },
    "salmon": {
        "display_name": "Atlantic Salmon",
        "local_name": "Salmon",
        "scientific_name": "Salmo salar",
        "category": "Cold-water Marine Fish",
        "typical_market_price_pkr": 2800,
        "description": "High-end commercial marine fish renowned for its vibrant pink flesh, rich healthy oils, and delicate buttery texture."
    },
    "anchovy": {
        "display_name": "European Anchovy",
        "local_name": "Hamsi / Small Marine Fish",
        "scientific_name": "Engraulis encrasicolus",
        "category": "Small Marine Forage Fish",
        "typical_market_price_pkr": 450,
        "description": "Small, slender silvery forage fish. Highly rich in calcium, iron, and savory umami flavor, commonly fried crispy."
    },
    "horsemackerel": {
        "display_name": "Horse Mackerel",
        "local_name": "Istavrit",
        "scientific_name": "Trachurus trachurus",
        "category": "Pelagic Marine Fish",
        "typical_market_price_pkr": 650,
        "description": "Fast-swimming pelagic marine fish with firm dark meat and distinct lateral scutes. Excellent for traditional grilling and smoking."
    }
}

class AIEngine:
    def __init__(self):
        self.species_model = None
        self.freshness_model = None
        self.gatekeeper_model = None
        self.species_labels = []
        self.freshness_labels = []
        self._load_models()

    def _load_models(self):
        sp_path = MODELS_DIR / "species_detection.keras"
        fr_path = MODELS_DIR / "freshness_detection.keras"
        sp_meta_path = MODELS_DIR / "species_detection_labels.json"
        fr_meta_path = MODELS_DIR / "freshness_detection_labels.json"

        if sp_path.exists() and sp_meta_path.exists():
            self.species_model = tf.keras.models.load_model(sp_path)
            self.species_labels = json.loads(sp_meta_path.read_text(encoding="utf-8"))["labels"]
            print(f"[AI Engine] Loaded Species Model ({len(self.species_labels)} classes)")

        if fr_path.exists() and fr_meta_path.exists():
            self.freshness_model = tf.keras.models.load_model(fr_path)
            self.freshness_labels = json.loads(fr_meta_path.read_text(encoding="utf-8"))["labels"]
            print(f"[AI Engine] Loaded Freshness Model")

        try:
            self.gatekeeper_model = tf.keras.applications.MobileNetV3Large(weights="imagenet")
            print("[AI Engine] Loaded General Vision Gatekeeper Model")
        except Exception as e:
            print(f"[AI Engine] Notice on Gatekeeper: {e}")

        # Warmup all models so first user scan is instantaneous (0.3s)
        try:
            dummy = np.zeros((1, 224, 224, 3), dtype=np.float32)
            if self.species_model is not None:
                self.species_model.predict(dummy, verbose=0)
            if self.freshness_model is not None:
                self.freshness_model.predict(dummy, verbose=0)
            if self.gatekeeper_model is not None:
                self.gatekeeper_model.predict(dummy, verbose=0)
            print("[AI Engine] Models warmed up and ready for instant inference!")
        except Exception as e:
            print(f"[AI Engine] Notice on warmup: {e}")

    def check_gatekeeper(self, batch_img: np.ndarray) -> Tuple[bool, Optional[str], float]:
        if self.gatekeeper_model is None:
            return False, None, 0.0
        try:
            arr = tf.keras.applications.mobilenet_v3.preprocess_input(batch_img.copy())
            preds = self.gatekeeper_model.predict(arr, verbose=0)
            top3 = tf.keras.applications.mobilenet_v3.decode_predictions(preds, top=3)[0]

            NON_FISH_KEYWORDS = {
                "limousine", "minibus", "minivan", "wagon", "pickup", "cab", "sedan", "coupe",
                "jeep", "convertible", "racer", "sports_car", "wheel", "tire", "bus", "truck",
                "car", "vehicle", "motorcycle", "bicycle",
                  "cat", "tabby", "siamese", "persian",
                "dog", "terrier", "retriever", "hound", "shepherd", "poodle", "horse", "cow",
                "sheep", "goat", "pig", "elephant", "bear", "monkey", "bird", "chair", "sofa",
                "table", "desk", "bed", "laptop", "computer", "phone", "television", "pizza",
                "burger", "sandwich", "apple", "banana", "flower", "building", "house", "face",
                "finger", "hand", "nail", "person", "man", "woman", "child", "boy", "girl", "leg",
                "arm", "foot", "shoe", "boot", "sneaker", "shirt", "suit", "tie", "jean", "pants",
                "jacket", "coat", "hat", "cap", "glasses", "sunglasses", "mask", "glove", "watch",
                "ring", "necklace", "bracelet", "earring", "backpack", "bag", "wallet", "purse",
                "bottle", "cup", "mug", "plate", "bowl", "fork", "knife", "spoon", "paper", "book",
                "pen", "pencil", "keyboard", "mouse", "monitor", "screen", "camera", "lens",
                "wall", "floor", "ceiling", "window", "door", "tree", "grass", "dirt", "rock",
                "stone", "sand", "water", "sky", "cloud", "sun", "moon", "star", "band_aid", 
                "stethoscope", "syringe", "medicine", "pill", "bandage", "plaster", "cast",
                "cellular", "telephone", "web_site", "comic_book", "seat_belt", "lipstick",
                "hair_spray", "perfume", "microphone", "ipod", "abaya", "cloak", "sweatshirt",
                "jersey", "t-shirt", "cardigan", "pajama", "bath_towel", "diaper", "apron",
                "bikini", "bathing_cap", "cowboy_hat", "sombrero", "velvet", "wig", "cellular_telephone",
                "lens_cap", "loudspeaker", "cd_player", "iPod", "remote_control", "tripod",
                "joystick", "sunglass", "loupe", "projector", "modem", "hard_disc", "mouse", "keyboard",
                "dough", "potpie", "french_loaf", "bagel", "pretzel", "burrito", "hotdog", "pizza",
                "meat_loaf", "guacamole", "ice_cream", "pomegranate", "fig", "lemon", "strawberry",
                "orange", "banana", "apple", "pineapple", "jackfruit", "head_cabbage", "broccoli", 
                "cauliflower", "zucchini", "spaghetti_squash", "acorn_squash", "butternut_squash", 
                "human" , "person", "man", "woman", "child", "boy", "girl", "baby", "teenager", 
                "adult", "elderly", "teen", "toddler", "infant", "adolescent", "youth", "senior", "grandparent",
                "grandchild", "parent", "sibling", "cousin", "bread", "cake", "cookie", "brownie", "muffin",
                  "croissant", "danish", "baguette", "roll", "roti", "naan", "tortilla", "pita", "flatbread", 
                  "focaccia", "ciabatta", "brioche", "scone", "pretzel", "biscuit", "cracker", 
                  "waffle", "pancake", "crepe", "blini", "dumpling",
                  "samosa", "spring_roll", "egg_roll", "empanada","fingers", "finger_food", 
                  "appetizer", "snack", "hors_d'oeuvre", "canape", "tapas", "antipasto", "mezze", 
                  "dim_sum", "bruschetta", "Fruit", "vegetable", "pork", "beef", "chicken", "lamb", 
                  "tv", "television", "monitor", "screen", "display", "projector", "laptop",
                    "computer", "tablet", "smartphone", "cellphone", "mobile_phone", "camera",
                      "camcorder", "video_camera", "drone" "dinasaur", "fossil", "skeleton", "bone", 
                      "skull", "tooth", "claw", "horn", "antler","marble", "granite", "limestone", "sandstone", "slate", "basalt", "quartz", "crystal",
                      "crocodile", "alligator", "lizard", "snake", "turtle", "tortoise", "frog", "toad", "salamander",
            }

            print(f"[Gatekeeper] Checking image... Top 3 predictions:")
            for _, name, conf in top3:
                name_lower = name.lower()
                print(f"  - {name}: {conf:.3f}")
                if conf >= 0.05 and any(kw in name_lower for kw in NON_FISH_KEYWORDS):
                    print(f"  -> REJECTED! Found forbidden keyword in: {name}")
                    return True, name.replace("_", " ").title(), round(conf * 100, 1)
            


            print("  -> PASSED Gatekeeper!")
            return False, None, 0.0
        except Exception:
            return False, None, 0.0

    def estimate_shelf_life(self, fresh_probability: float, species_key: str) -> Dict[str, Any]:
        p = max(0.0, min(1.0, float(fresh_probability)))

        if p >= 0.85:
            refrig_hours = int(round(120 + (p - 0.85) / 0.15 * 48))  # 120 - 168 hours (~5 to 7 days)
            ambient_hours = int(round(12 + (p - 0.85) / 0.15 * 6))   # 12 - 18 hours
            status_category = "Optimal Fresh"
            guidance = "Prime premium quality. High freshness score. Excellent for cooking immediately or freezing for long-term storage."
        elif p >= 0.65:
            refrig_hours = int(round(72 + (p - 0.65) / 0.20 * 48))   # 72 - 120 hours (~3 to 5 days)
            ambient_hours = int(round(6 + (p - 0.65) / 0.20 * 6))    # 6 - 12 hours
            status_category = "Good / Consume Soon"
            guidance = "Safe for consumption with good quality. Recommended to cook within 24-48 hours. Keep chilled on ice (0-4°C)."
        elif p >= 0.50:
            refrig_hours = int(round(24 + (p - 0.50) / 0.15 * 48))   # 24 - 72 hours (~1 to 3 days)
            ambient_hours = int(round(2 + (p - 0.50) / 0.15 * 4))    # 2 - 6 hours
            status_category = "Fair / Expiring"
            guidance = "Early signs of degradation. Consume immediately today. Thoroughly wash with cold water and cook with high heat."
        else:
            refrig_hours = 0
            ambient_hours = 0
            status_category = "Spoiled / Unsafe"
            guidance = "Bacterial degradation detected. Fish is spoiled and unsafe for consumption. Discard immediately to prevent foodborne illness."

        return {
            "estimated_refrigerated_hours": refrig_hours,
            "estimated_refrigerated_days": round(refrig_hours / 24.0, 1),
            "estimated_ambient_hours": ambient_hours,
            "status_category": status_category,
            "storage_guidance": guidance,
        }

    def predict(self, image_bytes: bytes, filename: str = "upload.jpg") -> Dict[str, Any]:
        if self.species_model is None or self.freshness_model is None:
            raise RuntimeError("Models not loaded properly.")

        with Image.open(io.BytesIO(image_bytes)) as pil_img:
            rgb = pil_img.convert("RGB").resize(DEFAULT_IMAGE_SIZE)
            batch = np.expand_dims(np.array(rgb, dtype=np.float32), axis=0)

        # 1. Gatekeeper Check
        is_non_fish, detected_name, obj_conf = self.check_gatekeeper(batch)
        if is_non_fish:
            return {
                "image_file": filename,
                "status": "REJECTED",
                "is_fish": False,
                "reason": "Non-fish image detected.",
                "message": "No valid fish detected in this image. Please upload a clear photo of a whole fish, eye, or gills.",
                "recommendation": "Please upload a clear photo of a fish (whole fish, eye, or gills)."
            }

        # 2. Species Inference
        species_preds = self.species_model.predict(batch, verbose=0)[0]
        top_idx = int(np.argmax(species_preds))
        species_key = self.species_labels[top_idx]
        species_conf = float(species_preds[top_idx])
        species_info = SPECIES_METADATA_MAP.get(species_key, {})

        top_indices = np.argsort(species_preds)[::-1][:3]
        top_species_ranking = [
            {
                "species": self.species_labels[idx],
                "display_name": SPECIES_METADATA_MAP.get(self.species_labels[idx], {}).get("display_name", self.species_labels[idx]),
                "confidence": round(float(species_preds[idx]) * 100, 2),
            }
            for idx in top_indices
        ]

        # 3. Freshness Inference
        freshness_raw = float(self.freshness_model.predict(batch, verbose=0)[0][0])
        spoiled_idx = self.freshness_labels.index("spoiled") if "spoiled" in self.freshness_labels else 1
        spoiled_prob = freshness_raw if spoiled_idx == 1 else (1.0 - freshness_raw)
        fresh_prob = 1.0 - spoiled_prob
        is_fresh = fresh_prob >= 0.50
        freshness_label = "Fresh" if is_fresh else "Spoiled"
        freshness_confidence = (fresh_prob if is_fresh else spoiled_prob) * 100

        # 4. Shelf-Life Engine
        shelf_life = self.estimate_shelf_life(fresh_prob, species_key)

        return {
            "image_file": filename,
            "status": "SUCCESS",
            "is_fish": True,
            "species_detection": {
                "predicted_species": species_key,
                "display_name": species_info.get("display_name", species_key),
                "local_name": species_info.get("local_name", "N/A"),
                "scientific_name": species_info.get("scientific_name", "N/A"),
                "category": species_info.get("category", "N/A"),
                "typical_market_price_pkr": species_info.get("typical_market_price_pkr", 700),
                "description": species_info.get("description", ""),
                "confidence_percent": round(species_conf * 100, 2),
                "is_uncertain": bool(species_conf * 100 < 65.0),
                "top_predictions": top_species_ranking,
            },
            "freshness_detection": {
                "status": freshness_label,
                "is_fresh": is_fresh,
                "confidence_percent": round(freshness_confidence, 2),
                "freshness_probability": round(fresh_prob, 4),
                "quality_grade": shelf_life["status_category"],
            },
            "shelf_life_estimation": {
                "storage_refrigerated_hours": shelf_life["estimated_refrigerated_hours"],
                "storage_refrigerated_days": shelf_life["estimated_refrigerated_days"],
                "storage_ambient_hours": shelf_life["estimated_ambient_hours"],
                "recommendation": shelf_life["storage_guidance"],
            }
        }

