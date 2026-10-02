from typing import Dict, Any

class StorageAdvisor:
    @staticmethod
    def get_storage_plan(freshness_status: str, ambient_temp_c: float = 25.0) -> Dict[str, Any]:
        if freshness_status == "Fresh":
            return {
                "chilled_guideline": "Maintain at 0°C to 4°C with continuous crushed ice drainage. Check ice twice daily.",
                "ice_ratio": "1 : 1 (1 kg ice per 1 kg of fish)",
                "ambient_warning": f"At current ambient room temperature ({ambient_temp_c}°C), fish must be cooked or iced within 6-12 hours to prevent rapid microbial growth.",
                "cooking_methods": ["Pan Frying", "Whole Steaming", "Barbecue Grilling", "Curry (Machli Ka Salan)"],
                "freezer_preservation": "Safe for deep freezing (-18°C) for up to 90-180 days after scaling and gutting."
            }
        else:
            return {
                "chilled_guideline": "Spoiled / Degraded. Do not attempt to preserve or re-freeze.",
                "ice_ratio": "N/A",
                "ambient_warning": "High bacterial proliferation and histamine accumulation. Immediate disposal required.",
                "cooking_methods": ["NONE - Unsafe for human or pet consumption"],
                "freezer_preservation": "Do not freeze spoiled fish."
            }
