"""
Dataset Sanitizer:
- Verifies image integrity (detects corrupt, truncated, or unreadable images)
- Normalizes all images to RGB format and saves as standard .jpg
- Computes perceptual difference hash (dhash) and MD5 to eliminate duplicates
"""

import os
import hashlib
from pathlib import Path
from PIL import Image, ImageFile

ImageFile.LOAD_TRUNCATED_IMAGES = False

def calculate_dhash(image, hash_size=8):
    image = image.convert('L').resize((hash_size + 1, hash_size), Image.Resampling.LANCZOS)
    pixels = list(image.getdata())
    difference = []
    for row in range(hash_size):
        for col in range(hash_size):
            pixel_left = pixels[row * (hash_size + 1) + col]
            pixel_right = pixels[row * (hash_size + 1) + col + 1]
            difference.append(pixel_left > pixel_right)
    decimal_value = 0
    hex_string = []
    for index, value in enumerate(difference):
        if value:
            decimal_value += 2**(index % 8)
        if (index % 8) == 7:
            hex_string.append(hex(decimal_value)[2:].rjust(2, '0'))
            decimal_value = 0
    return ''.join(hex_string)

def sanitize_folder(folder_path: Path, min_dim: int = 64, remove_duplicates: bool = True):
    folder_path = folder_path.resolve()
    if not folder_path.exists():
        print(f"Directory does not exist: {folder_path}")
        return {"total": 0, "valid": 0, "corrupt": 0, "duplicates": 0}

    print(f"\n[Sanitizing] Scanning: {folder_path}")
    seen_hashes = set()
    seen_md5s = set()
    total_scanned = 0
    valid_count = 0
    corrupt_count = 0
    duplicate_count = 0

    all_images = [p for p in folder_path.rglob('*') if p.is_file() and p.suffix.lower() in {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.heic', '.heif'}]
    print(f"Found {len(all_images)} image files.")

    for img_path in all_images:
        total_scanned += 1
        try:
            if img_path.stat().st_size < 100:
                print(f"Removing empty/tiny file: {img_path.name}")
                img_path.unlink()
                corrupt_count += 1
                continue

            with Image.open(img_path) as img:
                img.verify()

            with Image.open(img_path) as img:
                w, h = img.size
                if w < min_dim or h < min_dim:
                    print(f"Removing too small image ({w}x{h}): {img_path.name}")
                    img_path.unlink()
                    corrupt_count += 1
                    continue

                with open(img_path, 'rb') as f:
                    file_md5 = hashlib.md5(f.read()).hexdigest()
                if file_md5 in seen_md5s:
                    if remove_duplicates:
                        print(f"Removing exact duplicate: {img_path.name}")
                        img_path.unlink()
                        duplicate_count += 1
                        continue
                seen_md5s.add(file_md5)

                if remove_duplicates:
                    img_dhash = calculate_dhash(img)
                    if img_dhash in seen_hashes:
                        print(f"Removing visual duplicate: {img_path.name}")
                        img_path.unlink()
                        duplicate_count += 1
                        continue
                    seen_hashes.add(img_dhash)

                needs_conversion = (img.mode != 'RGB') or (img_path.suffix.lower() not in {'.jpg', '.jpeg'})
                if needs_conversion:
                    rgb_img = img.convert('RGB')
                    target_path = img_path.with_suffix('.jpg')
                    rgb_img.save(target_path, 'JPEG', quality=95)
                    if target_path != img_path:
                        img_path.unlink()

            valid_count += 1
        except Exception as e:
            print(f"Error reading {img_path.name}: {e} -> Deleting")
            try:
                img_path.unlink()
            except Exception:
                pass
            corrupt_count += 1

    print(f"Done {folder_path.name}: Total={total_scanned}, Valid={valid_count}, Corrupt/Removed={corrupt_count}, Duplicates Removed={duplicate_count}")
    return {"total": total_scanned, "valid": valid_count, "corrupt": corrupt_count, "duplicates": duplicate_count}

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--target', type=str, required=True, help='Path to dataset directory')
    parser.add_argument('--min-dim', type=int, default=64)
    args = parser.parse_args()
    sanitize_folder(Path(args.target), min_dim=args.min_dim)
