"""
Build Dedicated Freshness Dataset:
Organizes multi-organ images (eyes, gills, skin, whole body) into:
dataset_freshness/
  fresh/
    eye/
    gill/
    body/
  spoiled/
    eye/
    gill/
    body/
"""

import os
import shutil
from pathlib import Path
from PIL import Image

SOURCE_DIR = Path("dataset")
TARGET_DIR = Path("dataset_freshness")

def classify_organ(filename: str, parent_folder: str) -> str:
    name_lower = filename.lower()
    parent_lower = parent_folder.lower()
    
    if "eye" in name_lower or "eye" in parent_lower:
        return "eye"
    elif "gill" in name_lower or "gill" in parent_lower:
        return "gill"
    elif any(k in name_lower for k in ["skin", "scale", "flesh", "slice", "texture"]):
        return "skin"
    else:
        return "body"

def build_freshness_dataset():
    SOURCE_DIR_RES = SOURCE_DIR.resolve()
    TARGET_DIR_RES = TARGET_DIR.resolve()
    
    if not SOURCE_DIR_RES.exists():
        print(f"Source folder not found: {SOURCE_DIR_RES}")
        return

    TARGET_DIR_RES.mkdir(parents=True, exist_ok=True)
    
    counts = {"fresh": {"eye": 0, "gill": 0, "body": 0, "skin": 0},
              "spoiled": {"eye": 0, "gill": 0, "body": 0, "skin": 0}}

    for species_dir in sorted(SOURCE_DIR_RES.iterdir()):
        if not species_dir.is_dir():
            continue
        species_name = species_dir.name
        
        for root, dirs, files in os.walk(species_dir):
            rel_path = os.path.relpath(root, species_dir)
            parts = [p.lower() for p in rel_path.split(os.sep)]
            
            if "fresh" in parts:
                status = "fresh"
            elif "spoiled" in parts:
                status = "spoiled"
            else:
                continue

            for f in files:
                if not f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp', '.bmp')):
                    continue
                
                src_file = Path(root) / f
                organ = classify_organ(f, rel_path)
                
                dest_dir = TARGET_DIR_RES / status / organ
                dest_dir.mkdir(parents=True, exist_ok=True)
                
                # Standardize destination filename
                dest_filename = f"{species_name}_{src_file.stem}.jpg"
                dest_path = dest_dir / dest_filename
                
                try:
                    with Image.open(src_file) as img:
                        rgb_img = img.convert("RGB")
                        rgb_img.save(dest_path, "JPEG", quality=95)
                    counts[status][organ] += 1
                except Exception as e:
                    print(f"Skipping corrupt image {src_file.name}: {e}")

    print("\n=== FRESHNESS DATASET SUMMARY ===")
    total_fresh = sum(counts["fresh"].values())
    total_spoiled = sum(counts["spoiled"].values())
    print(f"Total Fresh Images: {total_fresh}")
    for organ, cnt in counts["fresh"].items():
        print(f"  - fresh/{organ}: {cnt}")
    print(f"Total Spoiled Images: {total_spoiled}")
    for organ, cnt in counts["spoiled"].items():
        print(f"  - spoiled/{organ}: {cnt}")
    print(f"Grand Total: {total_fresh + total_spoiled}")

if __name__ == '__main__':
    build_freshness_dataset()
