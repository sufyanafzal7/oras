"""
Extracts 1 frame/sec from every Cholec80 video, matching the rate the
tool annotations are already given at. Filenames line up exactly with
the frame_idx column in cholec80_master.csv.

Pure CPU + disk I/O - no GPU involved. Decoding is the bottleneck, so
this will take a while across 80 videos. Run it in the background.
Safe to stop and re-run - already-extracted videos are skipped.
"""

from pathlib import Path
import cv2

# ---------------------------------------------------------------------------
# CONFIG - adjust for your machine
# ---------------------------------------------------------------------------
VIDEOS_DIR   = Path(r"D:\Download\Dataset\videos")  # swap E: for your actual HDD drive letter
FRAMES_DIR   = Path(r"D:\Projects\oras\ml\datasets\cholec80_frames")  # SSD
FRAME_STEP   = 25   # 1fps at 25fps source
JPEG_QUALITY = 90


def extract_video(video_path: Path, out_dir: Path) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        print(f"  ! Could not open {video_path}")
        return 0

    frame_idx, saved = 0, 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        if frame_idx % FRAME_STEP == 0:
            out_path = out_dir / f"{frame_idx:06d}.jpg"
            cv2.imwrite(str(out_path), frame, [cv2.IMWRITE_JPEG_QUALITY, JPEG_QUALITY])
            saved += 1
        frame_idx += 1

    cap.release()
    return saved


def main():
    video_files = sorted(VIDEOS_DIR.glob("video*.mp4"))
    print(f"Found {len(video_files)} videos in {VIDEOS_DIR}")

    for video_path in video_files:
        video_id = video_path.stem
        out_dir = FRAMES_DIR / video_id
        if out_dir.exists() and any(out_dir.iterdir()):
            print(f"  - {video_id}: already extracted, skipping")
            continue
        print(f"  > {video_id}: extracting...")
        saved = extract_video(video_path, out_dir)
        print(f"    saved {saved} frames -> {out_dir}")


if __name__ == "__main__":
    main()