"""
Build Dedicated Species Dataset:
- Imports clean whole-body images from existing dataset/ and external_test/
- Queries iNaturalist scientific observation database (verified research photos)
- Queries Wikimedia Commons repository
- Standardizes all images to high quality RGB JPEGs in dataset_species/<species>/
"""

import os
import json
import time
import urllib.request
import urllib.parse
from pathlib import Path
from PIL import Image, ImageFile

ImageFile.LOAD_TRUNCATED_IMAGES = True

TARGET_DIR = Path("dataset_species")
EXISTING_DATASET = Path("dataset")
EXTERNAL_TEST = Path("external_test")

SPECIES_METADATA = {
    "rohu": {
        "scientific_name": "Labeo rohita",
        "synonyms": ["Labeo rohita", "Labeo dussumieri"],
        "wiki_queries": ["Labeo rohita", "Rohu fish", "Rui mach"],
    },
    "sufaid_rohu": {
        "scientific_name": "Hypophthalmichthys molitrix",
        "synonyms": ["Hypophthalmichthys molitrix", "Silver carp"],
        "wiki_queries": ["Hypophthalmichthys molitrix", "Silver carp fish", "Silver carp"],
    },
    "tilapia": {
        "scientific_name": "Oreochromis niloticus",
        "synonyms": ["Oreochromis niloticus", "Oreochromis mossambicus", "Tilapia zillii"],
        "wiki_queries": ["Oreochromis niloticus", "Nile tilapia", "Tilapia fish"],
    },
    "sulemani": {
        "scientific_name": "Chanos chanos",
        "synonyms": ["Chanos chanos"],
        "wiki_queries": ["Chanos chanos", "Milkfish", "Bangus"],
    },
    "pomfret": {
        "scientific_name": "Pampus argenteus",
        "synonyms": ["Pampus argenteus", "Pampus chinensis", "Parastromateus niger"],
        "wiki_queries": ["Pampus argenteus", "Silver pomfret", "Black pomfret", "Parastromateus niger"],
    },
    "salmon": {
        "scientific_name": "Salmo salar",
        "synonyms": ["Salmo salar", "Oncorhynchus mykiss", "Oncorhynchus tshawytscha"],
        "wiki_queries": ["Salmo salar", "Atlantic salmon", "Salmon fish"],
    },
    "anchovy": {
        "scientific_name": "Engraulis encrasicolus",
        "synonyms": ["Engraulis encrasicolus", "Engraulis mordax", "Anchoa hepsetus"],
        "wiki_queries": ["Engraulis encrasicolus", "European anchovy", "Anchovy fish"],
    },
    "horsemackerel": {
        "scientific_name": "Trachurus trachurus",
        "synonyms": ["Trachurus trachurus", "Trachurus japonicus", "Trachurus symmetricus"],
        "wiki_queries": ["Trachurus trachurus", "Atlantic horse mackerel", "Horse mackerel fish"],
    },
}

def is_whole_fish_candidate(filename: str, parent_path: str, species: str) -> bool:
    name_lower = filename.lower()
    parent_lower = parent_path.lower()
    
    # Exclude macro eye/gill shots
    if any(k in name_lower for k in ["_eye_", "_gill_", "eye_", "gill_", "cornea"]):
        return False
    if "eye" in parent_lower or "gill" in parent_lower:
        return False
    
    # In whole-fish datasets
    if species in ["anchovy", "horsemackerel", "pomfret", "sufaid_rohu"]:
        return True
    
    if "species_only" in parent_lower or "external" in name_lower or "whole" in name_lower:
        return True
        
    return False

def import_existing_clean_species():
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    imported = {sp: 0 for sp in SPECIES_METADATA}
    
    # 1. From dataset/
    if EXISTING_DATASET.exists():
        for sp_dir in EXISTING_DATASET.iterdir():
            if not sp_dir.is_dir():
                continue
            sp_name = sp_dir.name
            if sp_name not in SPECIES_METADATA:
                continue
            
            dest_sp_dir = TARGET_DIR / sp_name
            dest_sp_dir.mkdir(parents=True, exist_ok=True)
            
            for root, _, files in os.walk(sp_dir):
                rel = os.path.relpath(root, sp_dir)
                for f in files:
                    if not f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp', '.bmp')):
                        continue
                    if is_whole_fish_candidate(f, rel, sp_name):
                        src_path = Path(root) / f
                        dest_path = dest_sp_dir / f"existing_{src_path.stem}.jpg"
                        try:
                            with Image.open(src_path) as img:
                                rgb = img.convert("RGB")
                                rgb.save(dest_path, "JPEG", quality=95)
                                imported[sp_name] += 1
                        except Exception:
                            pass
                            
    # 2. From external_test/
    if EXTERNAL_TEST.exists():
        for sp_dir in EXTERNAL_TEST.iterdir():
            if not sp_dir.is_dir():
                continue
            sp_name = sp_dir.name
            if sp_name not in SPECIES_METADATA:
                continue
            dest_sp_dir = TARGET_DIR / sp_name
            dest_sp_dir.mkdir(parents=True, exist_ok=True)
            
            for f in sp_dir.iterdir():
                if f.is_file() and f.suffix.lower() in ('.jpg', '.jpeg', '.png', '.webp', '.bmp'):
                    if is_whole_fish_candidate(f.name, "", sp_name):
                        dest_path = dest_sp_dir / f"ext_{f.stem}.jpg"
                        try:
                            with Image.open(f) as img:
                                rgb = img.convert("RGB")
                                rgb.save(dest_path, "JPEG", quality=95)
                                imported[sp_name] += 1
                        except Exception:
                            pass

    print("\n[Import Summary from Existing Folders]:")
    for sp, cnt in imported.items():
        print(f"  {sp}: {cnt} whole-fish images imported")
    return imported

def fetch_inaturalist_species_images(target_per_class: int = 350):
    headers = {"User-Agent": "FishFreshnessApp/1.0 (Research FYP Project)"}
    
    for species, meta in SPECIES_METADATA.items():
        dest_dir = TARGET_DIR / species
        dest_dir.mkdir(parents=True, exist_ok=True)
        current_count = len(list(dest_dir.glob("*.jpg")))
        
        if current_count >= target_per_class:
            print(f"Species '{species}' has {current_count} images. Skipping download.")
            continue
            
        needed = target_per_class - current_count
        print(f"\nFetching iNaturalist photos for '{species}' (Need {needed} more images)...")
        downloaded = 0
        
        for synonym in meta["synonyms"]:
            if downloaded >= needed:
                break
            for page in range(1, 4):
                if downloaded >= needed:
                    break
                url = f"https://api.inaturalist.org/v1/observations?taxon_name={urllib.parse.quote(synonym)}&photos=true&per_page=50&page={page}&order_by=votes"
                try:
                    req = urllib.request.Request(url, headers=headers)
                    with urllib.request.urlopen(req, timeout=12) as resp:
                        data = json.loads(resp.read().decode("utf-8"))
                        results = data.get("results", [])
                        if not results:
                            break
                        for obs in results:
                            if downloaded >= needed:
                                break
                            photos = obs.get("photos", [])
                            for p in photos:
                                u = p.get("url")
                                if not u:
                                    continue
                                # Get high quality medium/large image
                                high_res_url = u.replace("square", "medium")
                                file_dest = dest_dir / f"inat_{int(time.time()*1000)}_{downloaded}.jpg"
                                try:
                                    img_req = urllib.request.Request(high_res_url, headers=headers)
                                    with urllib.request.urlopen(img_req, timeout=10) as img_resp:
                                        with open(file_dest, "wb") as out_f:
                                            out_f.write(img_resp.read())
                                    with Image.open(file_dest) as im:
                                        w, h = im.size
                                        if w >= 64 and h >= 64:
                                            rgb = im.convert("RGB")
                                            rgb.save(file_dest, "JPEG", quality=95)
                                            downloaded += 1
                                        else:
                                            file_dest.unlink()
                                except Exception:
                                    if file_dest.exists():
                                        file_dest.unlink()
                    time.sleep(0.5)
                except Exception as e:
                    print(f"  Error fetching page {page} for '{synonym}': {e}")
                    break

        print(f"iNaturalist fetched: {downloaded} new images for '{species}'. Total now: {len(list(dest_dir.glob('*.jpg')))}")

def fetch_wikimedia_species_images(target_per_class: int = 350):
    headers = {"User-Agent": "FishFreshnessApp/1.0 (Research FYP Project)"}
    
    for species, meta in SPECIES_METADATA.items():
        dest_dir = TARGET_DIR / species
        dest_dir.mkdir(parents=True, exist_ok=True)
        current_count = len(list(dest_dir.glob("*.jpg")))
        
        if current_count >= target_per_class:
            continue
            
        needed = target_per_class - current_count
        print(f"\nFetching Wikimedia Commons photos for '{species}' (Need {needed} more images)...")
        downloaded = 0
        
        for query in meta["wiki_queries"]:
            if downloaded >= needed:
                break
            wiki_url = f"https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch={urllib.parse.quote(query)}&gsrlimit=40&prop=imageinfo&iiprop=url&format=json"
            try:
                req = urllib.request.Request(wiki_url, headers=headers)
                with urllib.request.urlopen(req, timeout=12) as resp:
                    data = json.loads(resp.read().decode("utf-8"))
                    pages = data.get("query", {}).get("pages", {})
                    for page_id, page_info in pages.items():
                        if downloaded >= needed:
                            break
                        img_info = page_info.get("imageinfo", [{}])[0]
                        img_url = img_info.get("url")
                        if not img_url or not img_url.lower().endswith(('.jpg', '.jpeg', '.png')):
                            continue
                        
                        file_dest = dest_dir / f"wiki_{int(time.time()*1000)}_{downloaded}.jpg"
                        try:
                            img_req = urllib.request.Request(img_url, headers=headers)
                            with urllib.request.urlopen(img_req, timeout=10) as img_resp:
                                with open(file_dest, "wb") as out_f:
                                    out_f.write(img_resp.read())
                            with Image.open(file_dest) as im:
                                w, h = im.size
                                if w >= 64 and h >= 64:
                                    rgb = im.convert("RGB")
                                    rgb.save(file_dest, "JPEG", quality=95)
                                    downloaded += 1
                                else:
                                    file_dest.unlink()
                        except Exception:
                            if file_dest.exists():
                                file_dest.unlink()
                time.sleep(0.5)
            except Exception as e:
                print(f"  Wiki error for '{query}': {e}")
                
        print(f"Wikimedia fetched: {downloaded} new images for '{species}'. Total now: {len(list(dest_dir.glob('*.jpg')))}")

def main():
    print("=== STEP 1: IMPORTING EXISTING CLEAN WHOLE-FISH IMAGES ===")
    import_existing_clean_species()
    
    print("\n=== STEP 2: FETCHING HIGH-QUALITY OBSERVATIONS FROM INATURALIST ===")
    fetch_inaturalist_species_images(target_per_class=350)
    
    print("\n=== STEP 3: FETCHING SUPPLEMENTARY IMAGES FROM WIKIMEDIA COMMONS ===")
    fetch_wikimedia_species_images(target_per_class=350)

if __name__ == '__main__':
    main()
