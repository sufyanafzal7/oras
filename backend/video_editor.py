"""
Renders an EditTimeline (clips + overlays) into a single output video
using ffmpeg, via one filter_complex invocation:
  1. Trim + reset timestamps for each clip from its source file
     (the primary analyzed video, or a separately imported file).
  2. Concatenate the trimmed clips in order.
  3. Burn in text (drawtext) and image (overlay) overlays, each scoped
     to its own [start, start+duration] window on the FINAL composed
     timeline via an `enable='between(t,...)'` expression.

Requires ffmpeg on PATH. Re-encodes (libx264/aac) rather than using the
concat demuxer, since imported clips are not guaranteed to share the
same codec/resolution as the primary source.
"""

import subprocess
from pathlib import Path

FFMPEG_BIN = "ffmpeg"


def _escape_text(text: str) -> str:
    # drawtext treats these as special characters.
    return (
        text.replace("\\", "\\\\")
        .replace(":", "\\:")
        .replace("'", "\\'")
    )


def render_timeline(
    primary_video_path: str,
    edit_plan: dict,
    imported_files: dict,        # {clip_index: local_temp_path}
    overlay_image_files: dict,   # {overlay_index: local_temp_path}
    output_path: str,
    progress_cb=None,
) -> None:
    clips = edit_plan.get("clips", [])
    overlays = edit_plan.get("overlays", [])
    if not clips:
        raise ValueError("No clips to render")

    # ── Inputs: one -i per source file, clips first then overlay images ──────
    inputs = []
    clip_input_idx = []
    for i, _clip in enumerate(clips):
        inputs.append(imported_files.get(i, primary_video_path))
        clip_input_idx.append(len(inputs) - 1)

    overlay_image_input_idx = {}
    for i, ov in enumerate(overlays):
        if ov.get("type") == "image" and i in overlay_image_files:
            inputs.append(overlay_image_files[i])
            overlay_image_input_idx[i] = len(inputs) - 1

    # ── Trim + concat filter chain ────────────────────────────────────────────
    filter_parts = []
    concat_labels = []
    for i, clip in enumerate(clips):
        idx = clip_input_idx[i]
        start = float(clip["startSeconds"])
        end = float(clip["endSeconds"])
        filter_parts.append(
            f"[{idx}:v]trim=start={start}:end={end},setpts=PTS-STARTPTS[v{i}]"
        )
        filter_parts.append(
            f"[{idx}:a]atrim=start={start}:end={end},asetpts=PTS-STARTPTS[a{i}]"
        )
        concat_labels.append(f"[v{i}][a{i}]")

    n = len(clips)
    filter_parts.append(
        f"{''.join(concat_labels)}concat=n={n}:v=1:a=1[vcat][acat]"
    )

    # ── Overlays, chained on top of [vcat] ────────────────────────────────────
    current_label = "vcat"
    for i, ov in enumerate(overlays):
        start = float(ov["startSeconds"])
        end = start + float(ov["durationSeconds"])
        enable = f"between(t,{start},{end})"
        out_label = f"vov{i}"

        if ov.get("type") == "text" and ov.get("content"):
            text = _escape_text(ov["content"])
            color = (ov.get("colorHex") or "#FFFFFF").lstrip("#")
            size = int(ov.get("fontSize") or 24)
            x = f"(w*{ov['x']})"
            y = f"(h*{ov['y']})"
            filter_parts.append(
                f"[{current_label}]drawtext=text='{text}':fontcolor=0x{color}:"
                f"fontsize={size}:x={x}:y={y}:enable='{enable}'[{out_label}]"
            )
            current_label = out_label
        elif ov.get("type") == "image" and i in overlay_image_input_idx:
            img_idx = overlay_image_input_idx[i]
            x = f"(main_w*{ov['x']})"
            y = f"(main_h*{ov['y']})"
            filter_parts.append(
                f"[{current_label}][{img_idx}:v]overlay=x={x}:y={y}:"
                f"enable='{enable}'[{out_label}]"
            )
            current_label = out_label

    filter_complex = ";".join(filter_parts)

    cmd = [FFMPEG_BIN, "-y"]
    for path in inputs:
        cmd += ["-i", path]
    cmd += [
        "-filter_complex", filter_complex,
        "-map", f"[{current_label}]",
        "-map", "[acat]",
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
        "-c:a", "aac",
        output_path,
    ]

    process = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
    )
    for line in process.stdout:
        if progress_cb:
            progress_cb(line)
    process.wait()

    if process.returncode != 0:
        raise RuntimeError(f"ffmpeg exited with code {process.returncode}")

    if not Path(output_path).exists():
        raise RuntimeError("ffmpeg reported success but produced no output file")