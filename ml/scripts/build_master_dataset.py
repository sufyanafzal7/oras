"""
Merges every video's phase_annotations + tool_annotations into ONE
master CSV, sampled at 1fps (the rate tool labels are already given at).

Why 1fps and not full 25fps: tool labels only exist at 1Hz in the raw
dataset, so training per-frame at 25fps would just duplicate each tool
label 25x with zero extra information. TeCNO/EndoNet/Trans-SVNet all
train at ~1fps for this exact reason.

Output columns: video_id, frame_idx, time_sec, phase,
                 grasper, bipolar, hook, scissors, clipper, irrigator, specimenbag
"""

from pathlib import Path
import pandas as pd

# ---------------------------------------------------------------------------
# CONFIG - adjust these two paths for your machine
# ---------------------------------------------------------------------------
DATASET_ROOT = Path(r"D:\Projects\oras\ml\datasets\cholec80_raw")  # has phase_annotations/ and tool_annotations/
OUTPUT_CSV   = Path(r"D:\Projects\oras\ml\datasets\cholec80_master.csv")

PHASE_DIR = DATASET_ROOT / "phase_annotations"
TOOL_DIR  = DATASET_ROOT / "tool_annotations"
FPS = 25  # Cholec80 videos are recorded at 25fps

TOOL_RENAME = {
    "Grasper": "grasper", "Bipolar": "bipolar", "Hook": "hook",
    "Scissors": "scissors", "Clipper": "clipper",
    "Irrigator": "irrigator", "SpecimenBag": "specimenbag",
}
COLUMN_ORDER = ["video_id", "frame_idx", "time_sec", "phase"] + list(TOOL_RENAME.values())


def load_phase_file(path: Path) -> pd.Series:
    """Series indexed by frame number -> phase label string."""
    df = pd.read_csv(path, sep="\t")
    return df.set_index("Frame")["Phase"]


def load_tool_file(path: Path) -> pd.DataFrame:
    """Tool-presence table indexed by frame number."""
    df = pd.read_csv(path, sep="\t")
    return df.set_index("Frame")


def build_video_table(video_id: str) -> pd.DataFrame:
    phase_series = load_phase_file(PHASE_DIR / f"{video_id}-phase.txt")
    tool_df = load_tool_file(TOOL_DIR / f"{video_id}-tool.txt").copy()

    # Tool file already gives the 1fps frame grid (0, 25, 50, ...).
    # Look each of those frame indices up in the full-rate phase series.
    tool_df["phase"] = phase_series.reindex(tool_df.index)

    tool_df.insert(0, "video_id", video_id)
    tool_df.insert(1, "frame_idx", tool_df.index)
    tool_df.insert(2, "time_sec", tool_df.index / FPS)
    tool_df = tool_df.reset_index(drop=True).rename(columns=TOOL_RENAME)
    return tool_df[COLUMN_ORDER]


def main():
    video_ids = sorted(p.stem.replace("-phase", "")
                        for p in PHASE_DIR.glob("video*-phase.txt"))
    print(f"Found {len(video_ids)} videos with phase annotations.")

    tables = []
    for vid in video_ids:
        if not (TOOL_DIR / f"{vid}-tool.txt").exists():
            print(f"  ! Skipping {vid}: no matching tool annotation file.")
            continue
        table = build_video_table(vid)
        tables.append(table)
        print(f"  + {vid}: {len(table)} rows")

    master = pd.concat(tables, ignore_index=True)
    missing = master["phase"].isna().sum()
    if missing:
        print(f"  ! Warning: {missing} rows have no matching phase label.")

    OUTPUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    master.to_csv(OUTPUT_CSV, index=False)

    print(f"\nSaved -> {OUTPUT_CSV}")
    print(f"Total rows: {len(master)}  |  Videos: {master['video_id'].nunique()}")
    print("\nPhase distribution:")
    print(master["phase"].value_counts())
    print("\nTool presence rate (% of frames):")
    tool_cols = list(TOOL_RENAME.values())
    print((master[tool_cols].mean() * 100).round(1))


if __name__ == "__main__":
    main()