"""
Dataset Manifest & Quality Auditor:
Generates comprehensive summary report for dataset_species and dataset_freshness.
"""

import json
from pathlib import Path
from PIL import Image

def audit_dataset(dataset_path: Path):
    dataset_path = dataset_path.resolve()
    if not dataset_path.exists():
        return {"error": f"Folder {dataset_path} does not exist"}
        
    class_stats = {}
    total_images = 0
    dimensions = []
    
    for class_dir in sorted(dataset_path.iterdir()):
        if not class_dir.is_dir():
            continue
        imgs = [p for p in class_dir.rglob('*') if p.is_file() and p.suffix.lower() in {'.jpg', '.jpeg', '.png'}]
        class_stats[class_dir.name] = len(imgs)
        total_images += len(imgs)
        
        for sample in imgs[:10]:
            try:
                with Image.open(sample) as img:
                    dimensions.append(img.size)
            except Exception:
                pass

    return {
        "dataset_name": dataset_path.name,
        "total_images": total_images,
        "classes": class_stats,
        "sample_dimensions": dimensions[:5]
    }

def main():
    species_audit = audit_dataset(Path("dataset_species"))
    freshness_audit = audit_dataset(Path("dataset_freshness"))
    
    report = {
        "species_dataset": species_audit,
        "freshness_dataset": freshness_audit
    }
    
    print(json.dumps(report, indent=2))
    
    with open("dataset_manifest.json", "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print("\nSaved dataset_manifest.json")

if __name__ == '__main__':
    main()
