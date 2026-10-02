"""
Fish Freshness & Species Detection - Training & Inference Pipeline
Designed for Air University FYP: Multi-Organ Fish Freshness & Species Detection App

Modules:
1. Species Detection (8 classes: Rohu, Sufaid Rohu, Dayya/Tilapia, Sulemani/Milkfish, Poplet/Pomfret, Salmon, Anchovy, Horsemackerel)
2. Multi-Organ Fish Freshness & Shelf-Life Detection (Binary Fresh/Spoiled + Real-time confidence + Shelf-Life in Hours/Days)
"""

from __future__ import annotations

import argparse
import json
import random
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

try:
    import numpy as np
except ImportError as exc:
    raise SystemExit(
        "\n[ERROR] Virtual environment is not activated!\n"
        "Please activate the virtual environment or run using:\n"
        "    .\\.venv\\Scripts\\Activate.ps1\n"
        "  or:\n"
        "    .\\.venv\\Scripts\\python.exe Train_model.py <args>\n"
    ) from exc

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
PROJECT_DIR = Path(__file__).resolve().parent
DEFAULT_SPECIES_DIR = PROJECT_DIR / "dataset_species"
DEFAULT_FRESHNESS_DIR = PROJECT_DIR / "dataset_freshness"
DEFAULT_OUTPUT_DIR = PROJECT_DIR / "models"
DEFAULT_IMAGE_SIZE = (224, 224)
DEFAULT_SEED = 42

SPECIES_METADATA_MAP = {
    "rohu": {
        "display_name": "Rohu",
        "local_name": "Rahu / Rohu Mach",
        "scientific_name": "Labeo rohita",
        "category": "Freshwater Major Carp",
    },
    "sufaid_rohu": {
        "display_name": "Sufaid Rohu / Silver Carp",
        "local_name": "Sufaid Rahu",
        "scientific_name": "Hypophthalmichthys molitrix",
        "category": "Freshwater Silver Carp",
    },
    "tilapia": {
        "display_name": "Dayya / Nile Tilapia",
        "local_name": "Dayya",
        "scientific_name": "Oreochromis niloticus",
        "category": "Freshwater Cichlid",
    },
    "sulemani": {
        "display_name": "Sulemani / Milkfish",
        "local_name": "Sulemani",
        "scientific_name": "Chanos chanos",
        "category": "Brackish/Marine Fish",
    },
    "pomfret": {
        "display_name": "Poplet / Pomfret",
        "local_name": "Poplet / Paplet",
        "scientific_name": "Pampus argenteus / Parastromateus niger",
        "category": "Marine Table Fish",
    },
    "salmon": {
        "display_name": "Atlantic Salmon",
        "local_name": "Salmon",
        "scientific_name": "Salmo salar",
        "category": "Cold-water Marine Fish",
    },
    "anchovy": {
        "display_name": "Anchovy",
        "local_name": "Hamsi / Small Marine Fish",
        "scientific_name": "Engraulis encrasicolus",
        "category": "Small Marine Forage Fish",
    },
    "horsemackerel": {
        "display_name": "Horse Mackerel",
        "local_name": "Istavrit",
        "scientific_name": "Trachurus trachurus",
        "category": "Pelagic Marine Fish",
    },
}


@dataclass(frozen=True)
class DatasetRecord:
    path: str
    label: str
    organ: str | None = None


def normalize_label(val: str) -> str:
    return val.strip().lower().replace(" ", "_").replace("-", "_")


def is_image_file(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS


def require_tensorflow():
    try:
        import tensorflow as tf
    except ModuleNotFoundError as exc:
        raise SystemExit(
            "TensorFlow is not installed. Run: pip install -r requirements.txt"
        ) from exc
    return tf


def scan_species_dataset(dataset_dir: Path) -> list[DatasetRecord]:
    dataset_dir = dataset_dir.resolve()
    if not dataset_dir.exists():
        raise FileNotFoundError(f"Species dataset folder not found: {dataset_dir}")

    records: list[DatasetRecord] = []
    for sp_dir in sorted(path for path in dataset_dir.iterdir() if path.is_dir()):
        species = normalize_label(sp_dir.name)
        for img_path in sp_dir.rglob("*"):
            if is_image_file(img_path):
                records.append(DatasetRecord(path=str(img_path), label=species))

    if not records:
        raise ValueError(f"No images found in {dataset_dir}")
    return records


def scan_freshness_dataset(dataset_dir: Path) -> list[DatasetRecord]:
    dataset_dir = dataset_dir.resolve()
    if not dataset_dir.exists():
        raise FileNotFoundError(f"Freshness dataset folder not found: {dataset_dir}")

    records: list[DatasetRecord] = []
    for status_dir in sorted(path for path in dataset_dir.iterdir() if path.is_dir()):
        status = normalize_label(status_dir.name)
        if status not in {"fresh", "spoiled"}:
            continue
        for img_path in status_dir.rglob("*"):
            if is_image_file(img_path):
                organ = img_path.parent.name if img_path.parent != status_dir else "general"
                records.append(DatasetRecord(path=str(img_path), label=status, organ=organ))

    if not records:
        raise ValueError(f"No images found in {dataset_dir}")
    return records


def stratified_split(
    records: list[DatasetRecord],
    validation_split: float,
    seed: int,
) -> tuple[list[DatasetRecord], list[DatasetRecord]]:
    grouped: dict[str, list[DatasetRecord]] = defaultdict(list)
    for record in records:
        grouped[record.label].append(record)

    train_records: list[DatasetRecord] = []
    val_records: list[DatasetRecord] = []
    rng = random.Random(seed)

    for label, items in grouped.items():
        shuffled = items[:]
        rng.shuffle(shuffled)
        val_count = max(1, int(round(len(shuffled) * validation_split)))
        val_records.extend(shuffled[:val_count])
        train_records.extend(shuffled[val_count:])

    rng.shuffle(train_records)
    rng.shuffle(val_records)
    return train_records, val_records


def compute_class_weights(labels: list[int]) -> dict[int, float]:
    counts = Counter(labels)
    total = sum(counts.values())
    n_classes = len(counts)
    return {cls_idx: total / (n_classes * count) for cls_idx, count in counts.items()}


def make_tf_dataset(
    records: list[DatasetRecord],
    labels: list[int],
    batch_size: int,
    image_size: tuple[int, int],
    shuffle: bool,
    seed: int,
):
    tf = require_tensorflow()
    paths = [record.path for record in records]
    ds = tf.data.Dataset.from_tensor_slices((paths, labels))

    def _load_image(path, label):
        raw = tf.io.read_file(path)
        img = tf.image.decode_image(raw, channels=3, expand_animations=False)
        img.set_shape([None, None, 3])
        img = tf.image.resize(img, image_size)
        return img, label

    if shuffle:
        ds = ds.shuffle(buffer_size=min(len(paths), 4000), seed=seed, reshuffle_each_iteration=True)

    return (
        ds.map(_load_image, num_parallel_calls=tf.data.AUTOTUNE)
        .batch(batch_size)
        .prefetch(tf.data.AUTOTUNE)
    )


def build_backbone_model(
    num_classes: int,
    image_size: tuple[int, int],
    dropout: float = 0.3,
    learning_rate: float = 1e-3,
):
    tf = require_tensorflow()
    layers = tf.keras.layers

    inputs = tf.keras.Input(shape=(image_size[0], image_size[1], 3), name="input_image")
    
    # Data Augmentation layer
    x = layers.RandomFlip("horizontal")(inputs)
    x = layers.RandomRotation(0.12)(x)
    x = layers.RandomZoom(0.1)(x)
    x = layers.RandomContrast(0.1)(x)
    
    # MobileNetV3 preprocessing expects [0, 255] normalized
    x = tf.keras.applications.mobilenet_v3.preprocess_input(x)

    base_model = tf.keras.applications.MobileNetV3Large(
        input_shape=(image_size[0], image_size[1], 3),
        include_top=False,
        weights="imagenet",
    )
    base_model.trainable = False

    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.BatchNormalization()(x)
    x = layers.Dropout(dropout)(x)
    x = layers.Dense(128, activation="relu")(x)
    x = layers.Dropout(dropout * 0.7)(x)

    if num_classes == 2:
        outputs = layers.Dense(1, activation="sigmoid", name="freshness_output")(x)
        loss = "binary_crossentropy"
        metrics = [
            "accuracy",
            tf.keras.metrics.Precision(name="precision"),
            tf.keras.metrics.Recall(name="recall"),
            tf.keras.metrics.AUC(name="auc"),
        ]
    else:
        outputs = layers.Dense(num_classes, activation="softmax", name="species_output")(x)
        loss = "sparse_categorical_crossentropy"
        metrics = ["accuracy", tf.keras.metrics.SparseTopKCategoricalAccuracy(k=2, name="top_2_accuracy")]

    model = tf.keras.Model(inputs, outputs)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
        loss=loss,
        metrics=metrics,
    )
    return model, base_model


def fine_tune_backbone(model, base_model, num_classes: int, learning_rate: float = 1e-4, unfreeze_layers: int = 40):
    tf = require_tensorflow()
    base_model.trainable = True

    # Freeze earlier layers, unfreeze the top N layers for fine-tuning
    for layer in base_model.layers[:-unfreeze_layers]:
        layer.trainable = False

    if num_classes == 2:
        loss = "binary_crossentropy"
        metrics = ["accuracy", tf.keras.metrics.Precision(name="precision"), tf.keras.metrics.Recall(name="recall")]
    else:
        loss = "sparse_categorical_crossentropy"
        metrics = ["accuracy", tf.keras.metrics.SparseTopKCategoricalAccuracy(k=2, name="top_2_accuracy")]

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
        loss=loss,
        metrics=metrics,
    )
    return model


def export_to_tflite(keras_model_path: Path, tflite_path: Path, quantize: bool = False):
    tf = require_tensorflow()
    print(f"\nConverting {keras_model_path.name} -> {tflite_path.name}...")
    model = tf.keras.models.load_model(keras_model_path)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    if quantize:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
    tflite_model = converter.convert()
    tflite_path.parent.mkdir(parents=True, exist_ok=True)
    tflite_path.write_bytes(tflite_model)
    size_mb = len(tflite_model) / (1024 * 1024)
    print(f"Exported TFLite Model: {tflite_path} ({size_mb:.2f} MB)")


def estimate_shelf_life(freshness_prob: float, species: str) -> dict[str, object]:
    """
    FYP Scope Document Shelf-Life Engine:
    Calculates estimated shelf-life hours & days based on freshness confidence
    under Refrigerated (0-4C) vs. Ambient Room Temp (22-25C) storage.
    """
    if freshness_prob >= 0.85:
        status_category = "Optimal Fresh"
        shelf_refrigerated_hours = int(round(120 + (freshness_prob - 0.85) * (48 / 0.15)))
        shelf_ambient_hours = int(round(12 + (freshness_prob - 0.85) * (6 / 0.15)))
        guidance = "Prime quality. Excellent for cooking immediately or freezing for long-term preservation."
    elif freshness_prob >= 0.50:
        status_category = "Good / Consume Soon"
        shelf_refrigerated_hours = int(round(36 + (freshness_prob - 0.50) * (84 / 0.35)))
        shelf_ambient_hours = int(round(4 + (freshness_prob - 0.50) * (8 / 0.35)))
        guidance = "Safe for consumption. Cook within the day and keep chilled on ice."
    else:
        status_category = "Spoiled / Unsafe"
        shelf_refrigerated_hours = 0
        shelf_ambient_hours = 0
        guidance = "Bacterial degradation detected. Do not consume or purchase."

    return {
        "status_category": status_category,
        "estimated_refrigerated_hours": shelf_refrigerated_hours,
        "estimated_refrigerated_days": round(shelf_refrigerated_hours / 24.0, 1),
        "estimated_ambient_hours": shelf_ambient_hours,
        "storage_guidance": guidance,
    }


def train_model_module(
    records: list[DatasetRecord],
    model_name: str,
    output_dir: Path,
    image_size: tuple[int, int] = DEFAULT_IMAGE_SIZE,
    batch_size: int = 32,
    epochs_warmup: int = 6,
    epochs_finetune: int = 6,
    val_split: float = 0.2,
    seed: int = DEFAULT_SEED,
):
    tf = require_tensorflow()
    output_dir.mkdir(parents=True, exist_ok=True)

    labels = sorted({r.label for r in records})
    label_to_idx = {label: i for i, label in enumerate(labels)}
    num_classes = len(labels)

    train_recs, val_recs = stratified_split(records, val_split, seed)
    train_labels = [label_to_idx[r.label] for r in train_recs]
    val_labels = [label_to_idx[r.label] for r in val_recs]

    train_ds = make_tf_dataset(train_recs, train_labels, batch_size, image_size, shuffle=True, seed=seed)
    val_ds = make_tf_dataset(val_recs, val_labels, batch_size, image_size, shuffle=False, seed=seed)

    print(f"\n{'='*60}")
    print(f"TRAINING MODULE: {model_name.upper()}")
    print(f"Classes ({num_classes}): {labels}")
    print(f"Train samples: {len(train_recs)} | Validation samples: {len(val_recs)}")
    print(f"{'='*60}")

    model, base_model = build_backbone_model(num_classes, image_size)
    class_weights = compute_class_weights(train_labels)

    callbacks = [
        tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=4, restore_best_weights=True),
        tf.keras.callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.4, patience=2, min_lr=1e-6),
        tf.keras.callbacks.ModelCheckpoint(
            filepath=str(output_dir / f"{model_name}_best.keras"),
            monitor="val_loss",
            save_best_only=True,
        ),
    ]

    print("\n[Phase 1]: Feature Extractor Warmup...")
    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=epochs_warmup,
        class_weight=class_weights,
        callbacks=callbacks,
    )

    if epochs_finetune > 0:
        print("\n[Phase 2]: Deep Convolutional Fine-Tuning...")
        fine_tune_backbone(model, base_model, num_classes, learning_rate=1e-4)
        model.fit(
            train_ds,
            validation_data=val_ds,
            epochs=epochs_finetune,
            class_weight=class_weights,
            callbacks=callbacks,
        )

    # Load best checkpoint
    best_ckpt = output_dir / f"{model_name}_best.keras"
    if best_ckpt.exists():
        model = tf.keras.models.load_model(best_ckpt)

    eval_results = model.evaluate(val_ds, verbose=0, return_dict=True)
    print(f"\nFinal Validation Metrics for {model_name}: {eval_results}")

    # Save final model & metadata
    final_model_path = output_dir / f"{model_name}.keras"
    model.save(final_model_path)

    metadata = {
        "model_name": model_name,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "image_size": list(image_size),
        "labels": labels,
        "train_count": len(train_recs),
        "validation_count": len(val_recs),
        "train_distribution": dict(sorted(Counter(r.label for r in train_recs).items())),
        "validation_distribution": dict(sorted(Counter(r.label for r in val_recs).items())),
        "metrics": {k: round(float(v), 4) for k, v in eval_results.items()},
    }
    meta_path = output_dir / f"{model_name}_labels.json"
    meta_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")

    # Export TFLite for Flutter
    tflite_path = output_dir / f"{model_name}.tflite"
    try:
        export_to_tflite(final_model_path, tflite_path, quantize=False)
    except Exception as e:
        print(f"TFLite export notice: {e}")

    print(f"Saved: {final_model_path}")
    print(f"Saved: {meta_path}")
_GATEKEEPER_MODEL = None

def check_for_non_fish_object(batch_img, tf):
    global _GATEKEEPER_MODEL
    try:
        if _GATEKEEPER_MODEL is None:
            _GATEKEEPER_MODEL = tf.keras.applications.MobileNetV3Large(weights="imagenet")
        arr = tf.keras.applications.mobilenet_v3.preprocess_input(batch_img.copy())
        preds = _GATEKEEPER_MODEL.predict(arr, verbose=0)
        top3 = tf.keras.applications.mobilenet_v3.decode_predictions(preds, top=3)[0]

        NON_FISH_KEYWORDS = {
            # Vehicles, Boats & Transport
            "limousine", "minibus", "minivan", "wagon", "beach_wagon", "pickup", "cab", "sedan",
            "coupe", "jeep", "convertible", "racer", "sports_car", "grille", "wheel", "tire",
            "bumper", "airliner", "wing", "locomotive", "tractor", "trailer", "ambulance",
            "fire_engine", "forklift", "golfcart", "moped", "scooter", "motorcycle", "bicycle",
            "bus", "truck", "van", "car", "vehicle", "go-kart", "cart", "boat", "speedboat",
            "canoe", "kayak", "paddle", "yacht", "ship", "container_ship", "liner",
            # Land Animals & Pets
            "cat", "tabby", "tiger_cat", "siamese", "persian", "cougar", "lynx", "leopard",
            "jaguar", "lion", "tiger", "cheetah", "dog", "terrier", "retriever", "hound",
            "shepherd", "poodle", "bulldog", "pug", "chihuahua", "mastiff", "collie", "fox",
            "wolf", "coyote", "hyena", "bear", "panda", "monkey", "ape", "gorilla", "chimpanzee",
            "horse", "zebra", "donkey", "cow", "ox", "bull", "cattle", "bison", "sheep", "ram",
            "goat", "pig", "hog", "boar", "deer", "elk", "moose", "camel", "llama", "elephant",
            "rhino", "hippo", "kangaroo", "rabbit", "hare", "squirrel", "mouse", "rat", "hedgehog",
            "bird", "eagle", "hawk", "owl", "sparrow", "pigeon", "dove", "duck", "goose", "swan",
            "parrot", "peacock", "penguin", "ostrich", "flamingo",
            # Household, Furniture & Tech
            "chair", "sofa", "couch", "table", "desk", "bed", "laptop", "computer", "keyboard",
            "cellular", "phone", "television", "screen", "monitor", "microwave", "oven", "toaster",
            "refrigerator", "shoe", "boot", "sandal", "sneaker", "shirt", "t-shirt", "suit", "coat",
            "jacket", "dress", "skirt", "pants", "jeans", "hat", "cap", "helmet", "bag", "backpack",
            "purse", "wallet", "umbrella", "bottle", "cup", "mug", "plate", "bowl", "book", "pen",
            # Non-Fish Food & Nature
            "pizza", "burger", "hamburger", "sandwich", "hotdog", "burrito", "taco", "bread",
            "cake", "cookie", "donut", "muffin", "ice_cream", "chocolate", "candy", "apple",
            "banana", "orange", "strawberry", "grape", "lemon", "lime", "watermelon", "mango",
            "tomato", "potato", "carrot", "broccoli", "corn", "salad",
            # Buildings
            "building", "house", "palace", "castle", "church", "bridge", "tower", "skyscraper",
            "flower", "rose", "tulip"
        }

        for _, name, conf in top3:
            name_lower = name.lower()
            if conf >= 0.15 and any(kw in name_lower for kw in NON_FISH_KEYWORDS):
                return True, name.replace("_", " ").title(), round(conf * 100, 1)
        return False, None, 0.0
    except Exception:
        return False, None, 0.0


def predict_image(
    image_path: Path,
    output_dir: Path = DEFAULT_OUTPUT_DIR,
    as_json: bool = False,
):
    tf = require_tensorflow()
    image_path = image_path.resolve()
    if not image_path.exists():
        raise FileNotFoundError(f"Image not found: {image_path}")

    # Load & preprocess image using PIL (supports JPEG, PNG, WEBP, BMP, etc.)
    from PIL import Image
    with Image.open(image_path) as pil_img:
        rgb = pil_img.convert("RGB").resize(DEFAULT_IMAGE_SIZE)
        batch = np.expand_dims(np.array(rgb, dtype=np.float32), axis=0)

    # Check for obvious non-fish objects (e.g. cats, dogs, cars, furniture)
    is_non_fish, _, _ = check_for_non_fish_object(batch, tf)
    if is_non_fish:
        rejection_result = {
            "image_file": str(image_path.name),
            "status": "REJECTED",
            "reason": "Non-fish image detected.",
            "recommendation": "Please upload a clear photo of a fish (whole fish, eye, or gills).",
        }
        if as_json:
            print(json.dumps(rejection_result, indent=2))
        else:
            print("\n" + "=" * 76)
            print("           FISH FRESHNESS & SPECIES AI SCANNER REPORT")
            print("=" * 76)
            print(f"  [+] Scanned File     : {image_path.name}")
            print("-" * 76)
            print("  [!] SCANNER REJECTED : Non-Fish Image Detected!")
            print("  * System Notice      : No valid fish detected in this image.")
            print("  * Action Required    : Please upload a clear photo of a fish.")
            print("=" * 76 + "\n")
        return rejection_result

    species_model_path = output_dir / "species_detection.keras"
    freshness_model_path = output_dir / "freshness_detection.keras"
    species_meta_path = output_dir / "species_detection_labels.json"
    freshness_meta_path = output_dir / "freshness_detection_labels.json"

    if not species_model_path.exists() or not freshness_model_path.exists():
        raise FileNotFoundError("Trained models not found. Please train first: python Train_model.py train --module all")

    species_meta = json.loads(species_meta_path.read_text(encoding="utf-8"))
    freshness_meta = json.loads(freshness_meta_path.read_text(encoding="utf-8"))

    species_model = tf.keras.models.load_model(species_model_path)
    freshness_model = tf.keras.models.load_model(freshness_model_path)

    # 1. Species Inference
    species_preds = species_model.predict(batch, verbose=0)[0]
    top_species_idx = int(np.argmax(species_preds))
    species_key = species_meta["labels"][top_species_idx]
    species_conf = float(species_preds[top_species_idx])
    species_info = SPECIES_METADATA_MAP.get(species_key, {})

    # Top 3 Species ranking
    top_indices = np.argsort(species_preds)[::-1][:3]
    top_species_ranking = [
        {
            "species": species_meta["labels"][idx],
            "display_name": SPECIES_METADATA_MAP.get(species_meta["labels"][idx], {}).get("display_name", species_meta["labels"][idx]),
            "confidence": round(float(species_preds[idx]) * 100, 2),
        }
        for idx in top_indices
    ]

    # 2. Freshness Inference
    freshness_raw = float(freshness_model.predict(batch, verbose=0)[0][0])
    freshness_labels = freshness_meta["labels"]
    spoiled_idx = freshness_labels.index("spoiled") if "spoiled" in freshness_labels else 1

    spoiled_prob = freshness_raw if spoiled_idx == 1 else (1.0 - freshness_raw)
    fresh_prob = 1.0 - spoiled_prob
    is_fresh = fresh_prob >= 0.50
    freshness_label = "Fresh" if is_fresh else "Spoiled"
    freshness_confidence = (fresh_prob if is_fresh else spoiled_prob) * 100

    # 3. Estimated Shelf-Life
    shelf_life_data = estimate_shelf_life(fresh_prob, species_key)

    result = {
        "image_file": str(image_path.name),
        "species_detection": {
            "predicted_species": species_key,
            "display_name": species_info.get("display_name", species_key),
            "local_name": species_info.get("local_name", "N/A"),
            "scientific_name": species_info.get("scientific_name", "N/A"),
            "category": species_info.get("category", "N/A"),
            "confidence_percent": round(species_conf * 100, 2),
            "top_predictions": top_species_ranking,
        },
        "freshness_detection": {
            "status": freshness_label,
            "confidence_percent": round(freshness_confidence, 2),
            "freshness_probability": round(fresh_prob, 4),
            "quality_grade": shelf_life_data["status_category"],
        },
        "shelf_life_estimation": {
            "storage_refrigerated_hours": shelf_life_data["estimated_refrigerated_hours"],
            "storage_refrigerated_days": shelf_life_data["estimated_refrigerated_days"],
            "storage_ambient_hours": shelf_life_data["estimated_ambient_hours"],
            "recommendation": shelf_life_data["storage_guidance"],
        },
    }

    if as_json:
        print(json.dumps(result, indent=2))
    else:
        display_prediction_report(result)

    return result


def format_progress_bar(percent: float, length: int = 25) -> str:
    filled = int(round(length * (percent / 100.0)))
    filled = max(0, min(length, filled))
    return "#" * filled + "-" * (length - filled)


def display_prediction_report(res: dict[str, object]):
    sp = res["species_detection"]
    fr = res["freshness_detection"]
    sh = res["shelf_life_estimation"]

    sp_bar = format_progress_bar(sp["confidence_percent"])
    fr_bar = format_progress_bar(fr["confidence_percent"])

    print("\n" + "=" * 76)
    print("           FISH FRESHNESS & SPECIES AI SCANNER REPORT")
    print("=" * 76)
    print(f"  [+] Scanned File     : {res['image_file']}")
    print("-" * 76)
    print("  [1] SPECIES IDENTIFICATION (Module 1)")
    print("-" * 76)
    print(f"  * Identified Species : {sp['display_name']}")
    print(f"  * Local Name (Urdu)  : {sp['local_name']}")
    print(f"  * Scientific Name    : {sp['scientific_name']}")
    print(f"  * Fish Category      : {sp['category']}")
    print(f"  * AI Confidence      : [{sp_bar}] {sp['confidence_percent']:.2f}%\n")
    print("  Top Candidates Considered:")
    for i, top in enumerate(sp["top_predictions"], 1):
        tag = f"  #{i}"
        print(f"   {tag} {top['display_name']:<35} {top['confidence']:>6.2f}%")

    print("-" * 76)
    print("  [2] QUALITY & FRESHNESS ANALYSIS (Module 2)")
    print("-" * 76)
    print(f"  * Overall Status     : {fr['status'].upper()} ({fr['quality_grade']})")
    print(f"  * Freshness Score    : [{fr_bar}] {fr['confidence_percent']:.2f}%\n")

    print("-" * 76)
    print("  [3] ESTIMATED SHELF-LIFE & STORAGE GUIDANCE")
    print("-" * 76)
    if fr["status"] == "Fresh":
        print(f"  * Chilled / On Ice (0C - 4C)      : {sh['storage_refrigerated_hours']} hours (~{sh['storage_refrigerated_days']} days)")
        print(f"  * Room Temperature (20C - 25C)    : {sh['storage_ambient_hours']} hours")
    else:
        print(f"  * Remaining Shelf-Life            : 0 hours (Expired / Spoiled)")
    print(f"  * Storage Recommendation          : {sh['recommendation']}")
    print("=" * 76 + "\n")


def main():
    parser = argparse.ArgumentParser(description="FYP Fish Freshness & Species Detection AI System")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Scan command
    scan_parser = subparsers.add_parser("scan", help="Scan and audit dataset directories.")
    scan_parser.add_argument("--species-dir", type=Path, default=DEFAULT_SPECIES_DIR)
    scan_parser.add_argument("--freshness-dir", type=Path, default=DEFAULT_FRESHNESS_DIR)

    # Train command
    train_parser = subparsers.add_parser("train", help="Train species, freshness, or all modules.")
    train_parser.add_argument("--module", choices=["species", "freshness", "all"], default="all")
    train_parser.add_argument("--species-dir", type=Path, default=DEFAULT_SPECIES_DIR)
    train_parser.add_argument("--freshness-dir", type=Path, default=DEFAULT_FRESHNESS_DIR)
    train_parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    train_parser.add_argument("--batch-size", type=int, default=32)
    train_parser.add_argument("--warmup-epochs", type=int, default=6)
    train_parser.add_argument("--finetune-epochs", type=int, default=6)
    train_parser.add_argument("--val-split", type=float, default=0.2)

    # Predict command
    predict_parser = subparsers.add_parser("predict", help="Run end-to-end inference on a single fish image.")
    predict_parser.add_argument("image", type=Path)
    predict_parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    predict_parser.add_argument("--json", action="store_true", help="Output raw JSON instead of formatted report")

    # Export TFLite command
    tflite_parser = subparsers.add_parser("export-tflite", help="Convert all models to TFLite format.")
    tflite_parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)

    args = parser.parse_args()

    if args.command == "scan":
        sp_records = scan_species_dataset(args.species_dir)
        fr_records = scan_freshness_dataset(args.freshness_dir)
        print("\n=== DATASET SCAN SUMMARY ===")
        print(f"Species dataset images: {len(sp_records)} across {len(set(r.label for r in sp_records))} classes")
        print(f"Freshness dataset images: {len(fr_records)} across {len(set(r.label for r in fr_records))} classes")

    elif args.command == "train":
        if args.module in {"species", "all"}:
            sp_records = scan_species_dataset(args.species_dir)
            train_model_module(
                records=sp_records,
                model_name="species_detection",
                output_dir=args.output_dir,
                batch_size=args.batch_size,
                epochs_warmup=args.warmup_epochs,
                epochs_finetune=args.finetune_epochs,
                val_split=args.val_split,
            )

        if args.module in {"freshness", "all"}:
            fr_records = scan_freshness_dataset(args.freshness_dir)
            train_model_module(
                records=fr_records,
                model_name="freshness_detection",
                output_dir=args.output_dir,
                batch_size=args.batch_size,
                epochs_warmup=args.warmup_epochs,
                epochs_finetune=args.finetune_epochs,
                val_split=args.val_split,
            )

    elif args.command == "predict":
        predict_image(args.image, args.output_dir, as_json=args.json)

    elif args.command == "export-tflite":
        for model_name in ["species_detection", "freshness_detection"]:
            kp = args.output_dir / f"{model_name}.keras"
            tp = args.output_dir / f"{model_name}.tflite"
            if kp.exists():
                export_to_tflite(kp, tp)


if __name__ == "__main__":
    main()
