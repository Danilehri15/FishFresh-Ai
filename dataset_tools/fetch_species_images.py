import os
import json
import time
import urllib.request
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from PIL import Image, ImageFile

ImageFile.LOAD_TRUNCATED_IMAGES = True

TARGET_DIR = Path("dataset_species")

SPECIES_METADATA = {
    "rohu": {
        "scientific_name": "Labeo rohita",
        "synonyms": ["Labeo rohita", "Labeo dussumieri", "Labeo calbasu"],
        "queries": ["Labeo rohita", "Rohu fish", "Rui mach", "Fresh rohu fish", "Rohu carp"],
    },
    "sufaid_rohu": {
        "scientific_name": "Hypophthalmichthys molitrix",
        "synonyms": ["Hypophthalmichthys molitrix", "Hypophthalmichthys nobilis"],
        "queries": ["Hypophthalmichthys molitrix", "Silver carp fish", "Sufaid rohu"],
    },
    "tilapia": {
        "scientific_name": "Oreochromis niloticus",
        "synonyms": ["Oreochromis niloticus", "Oreochromis mossambicus", "Tilapia zillii", "Oreochromis aureus"],
        "queries": ["Oreochromis niloticus", "Nile tilapia whole fish", "Tilapia fish market", "Dayya fish"],
    },
    "sulemani": {
        "scientific_name": "Chanos chanos",
        "synonyms": ["Chanos chanos"],
        "queries": ["Chanos chanos", "Milkfish whole", "Bangus fish whole", "Sulemani fish"],
    },
    "pomfret": {
        "scientific_name": "Pampus argenteus",
        "synonyms": ["Pampus argenteus", "Pampus chinensis", "Parastromateus niger"],
        "queries": ["Pampus argenteus", "Silver pomfret whole fish", "Black pomfret whole fish", "Poplet fish"],
    },
    "salmon": {
        "scientific_name": "Salmo salar",
        "synonyms": ["Salmo salar", "Oncorhynchus mykiss", "Oncorhynchus tshawytscha"],
        "queries": ["Salmo salar whole fish", "Atlantic salmon whole fish", "Whole raw salmon on ice"],
    },
    "anchovy": {
        "scientific_name": "Engraulis encrasicolus",
        "synonyms": ["Engraulis encrasicolus", "Engraulis mordax", "Anchoa hepsetus"],
        "queries": ["Engraulis encrasicolus", "European anchovy fish", "Hamsi fish"],
    },
    "horsemackerel": {
        "scientific_name": "Trachurus trachurus",
        "synonyms": ["Trachurus trachurus", "Trachurus japonicus", "Trachurus symmetricus"],
        "queries": ["Trachurus trachurus", "Atlantic horse mackerel fish", "Istavrit fish"],
    },
}

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
}

def get_url_content(url, timeout=12):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()

def download_and_save_image(url, dest_path, min_dim=80):
    try:
        data = get_url_content(url, timeout=10)
        temp_dest = dest_path.with_suffix(".tmp")
        with open(temp_dest, "wb") as f:
            f.write(data)
        
        with Image.open(temp_dest) as img:
            w, h = img.size
            if w < min_dim or h < min_dim:
                temp_dest.unlink(missing_ok=True)
                return False
            rgb_img = img.convert("RGB")
            rgb_img.save(dest_path, "JPEG", quality=92)
            
        temp_dest.unlink(missing_ok=True)
        return True
    except Exception:
        if 'temp_dest' in locals() and temp_dest.exists():
            temp_dest.unlink(missing_ok=True)
        return False

def collect_urls_for_species(species_name, meta):
    urls = []
    
    # 1. GBIF API
    for syn in meta["synonyms"]:
        try:
            gbif_url = f"https://api.gbif.org/v1/occurrence/search?scientificName={urllib.parse.quote(syn)}&mediaType=StillImage&limit=100"
            data = json.loads(get_url_content(gbif_url).decode("utf-8", errors="ignore"))
            for item in data.get("results", []):
                for m in item.get("media", []):
                    u = m.get("identifier")
                    if u and any(ext in u.lower() for ext in [".jpg", ".jpeg", ".png"]):
                        urls.append(u)
        except Exception as e:
            print(f"  GBIF error for {syn}: {e}")

    # 2. iNaturalist API
    for syn in meta["synonyms"]:
        for page in range(1, 4):
            try:
                inat_url = f"https://api.inaturalist.org/v1/observations?taxon_name={urllib.parse.quote(syn)}&photos=true&per_page=60&page={page}&order_by=votes"
                data = json.loads(get_url_content(inat_url).decode("utf-8", errors="ignore"))
                results = data.get("results", [])
                if not results:
                    break
                for obs in results:
                    for p in obs.get("photos", []):
                        u = p.get("url")
                        if u:
                            urls.append(u.replace("square", "medium"))
            except Exception as e:
                print(f"  iNat error for {syn} p{page}: {e}")
                break

    # 3. Wikimedia Commons API
    for q in meta["queries"]:
        try:
            wiki_url = f"https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch={urllib.parse.quote(q)}&gsrlimit=30&prop=imageinfo&iiprop=url&format=json"
            data = json.loads(get_url_content(wiki_url).decode("utf-8", errors="ignore"))
            pages = data.get("query", {}).get("pages", {})
            for pid, pinfo in pages.items():
                img_info = pinfo.get("imageinfo", [{}])[0]
                u = img_info.get("url")
                if u and any(ext in u.lower() for ext in [".jpg", ".jpeg", ".png"]):
                    urls.append(u)
        except Exception as e:
            print(f"  Wiki error for {q}: {e}")

    # Remove duplicates while preserving order
    seen = set()
    unique_urls = [u for u in urls if not (u in seen or seen.add(u))]
    return unique_urls

def build_all_species(target_per_species=300):
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    print("=== BUILDING DEDICATED SPECIES DATASET ===")
    
    for species, meta in SPECIES_METADATA.items():
        sp_dir = TARGET_DIR / species
        sp_dir.mkdir(parents=True, exist_ok=True)
        existing_imgs = list(sp_dir.glob("*.jpg"))
        print(f"\\nSpecies: '{species}' (Current count: {len(existing_imgs)})")
        
        if len(existing_imgs) >= target_per_species:
            print(f"  Sufficient images ({len(existing_imgs)} >= {target_per_species}). Skipping.")
            continue
            
        needed = target_per_species - len(existing_imgs)
        print(f"  Collecting URLs for '{species}'...")
        urls = collect_urls_for_species(species, meta)
        print(f"  Found {len(urls)} distinct candidate URLs.")
        
        downloaded = 0
        with ThreadPoolExecutor(max_workers=8) as executor:
            futures = []
            for idx, url in enumerate(urls):
                dest_file = sp_dir / f"web_{int(time.time())}_{idx}.jpg"
                futures.append(executor.submit(download_and_save_image, url, dest_file))
                
            for fut in as_completed(futures):
                if fut.result():
                    downloaded += 1
                if len(list(sp_dir.glob("*.jpg"))) >= target_per_species:
                    break
                    
        total_now = len(list(sp_dir.glob("*.jpg")))
        print(f"  Downloaded {downloaded} new images. Total now: {total_now}")

if __name__ == "__main__":
    build_all_species(target_per_species=300)
