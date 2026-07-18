"""
Converts Cholec80-Boxes ROI_Labels.csv (pixel coordinates) into the
folder structure + label format YOLOv8 expects (normalized 0-1 coords).

Train/val split is done BY VIDEO, not by frame, to avoid data leakage -
frames from the same video are highly similar to each other, so a random
frame-level split would let the model train and validate on near-identical
images.
"""

from pathlib import Path
import shutil
import sys
import pandas as pd
from PIL import Image
print("Script started")
# ---------------------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------------------
BOXES_DIR  = Path(r"D:\Projects\oras\ml\datasets\cholec80_boxes")
CSV_PATH   = BOXES_DIR / "ROI_Labels.csv"
IMAGES_DIR = BOXES_DIR / "Images"
OUTPUT_DIR = Path(r"D:\Projects\oras\ml\datasets\cholec80_boxes_yolo")

VAL_VIDEOS = {45}  # video 45 held out for validation, 41-44 for training

CLASS_NAMES = ["Grasper", "Bipolar", "Hook", "Scissors", "Clipper", "Irrigator", "SpecimenBag"]
CLASS_TO_ID = {name: i for i, name in enumerate(CLASS_NAMES)}

# The CSV isn't 100% consistent in tool naming. Map known variants here
# instead of hardcoding them into the main class list.
TOOL_NAME_ALIASES = {
    "Bag": "SpecimenBag",
}


def convert_row_to_yolo_line(row, img_w, img_h):
    class_id = CLASS_TO_ID[row["ToolName"]]
    x_center = (row["BBox_X"] + row["BBox_Width"] / 2) / img_w
    y_center = (row["BBox_Y"] + row["BBox_Height"] / 2) / img_h
    width = row["BBox_Width"] / img_w
    height = row["BBox_Height"] / img_h
    return f"{class_id} {x_center:.6f} {y_center:.6f} {width:.6f} {height:.6f}"


def main():
    print("Before reading CSV")
    df = pd.read_csv(CSV_PATH, sep=";")
    print(f"Loaded {len(df)} bounding boxes across {df['Surgery_num'].nunique()} videos.")

    # Normalize tool names: strip whitespace, apply known aliases.
    df["ToolName"] = df["ToolName"].str.strip()
    df["ToolName"] = df["ToolName"].replace(TOOL_NAME_ALIASES)

    # Validate EVERYTHING up front before writing any files, so a bad
    # name doesn't cause a half-finished output directory again.
    unknown_tools = set(df["ToolName"]) - set(CLASS_NAMES)
    if unknown_tools:
        print(f"\n  ! ERROR: unmapped tool names found: {unknown_tools}")
        print("    Add these to TOOL_NAME_ALIASES at the top of this script, then re-run.")
        sys.exit(1)

    for split in ("train", "val"):
        (OUTPUT_DIR / "images" / split).mkdir(parents=True, exist_ok=True)
        (OUTPUT_DIR / "labels" / split).mkdir(parents=True, exist_ok=True)

    n_images, n_boxes, n_skipped = 0, 0, 0

    for frame_name, group in df.groupby("FrameName"):
        surgery_num = group.iloc[0]["Surgery_num"]
        split = "val" if surgery_num in VAL_VIDEOS else "train"

        video_dir = f"Video_{surgery_num}"
        src_image = IMAGES_DIR / video_dir / frame_name
        if not src_image.exists():
            n_skipped += 1
            continue

        with Image.open(src_image) as im:
            img_w, img_h = im.size

        lines = [convert_row_to_yolo_line(r, img_w, img_h) for _, r in group.iterrows()]

        dst_image = OUTPUT_DIR / "images" / split / frame_name
        dst_label = OUTPUT_DIR / "labels" / split / (Path(frame_name).stem + ".txt")

        shutil.copy(src_image, dst_image)
        dst_label.write_text("\n".join(lines))

        n_images += 1
        n_boxes += len(lines)

    print(f"\nConverted {n_images} images, {n_boxes} boxes. Skipped {n_skipped} (image not found).")

    yaml_lines = [
        f"path: {OUTPUT_DIR.as_posix()}",
        "train: images/train",
        "val: images/val",
        "names:",
    ]
    yaml_lines += [f"  {i}: {name}" for i, name in enumerate(CLASS_NAMES)]
    (OUTPUT_DIR / "data.yaml").write_text("\n".join(yaml_lines))
    print(f"Saved -> {OUTPUT_DIR / 'data.yaml'}")


if __name__ == "__main__":
    main()