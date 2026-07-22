import os
import uuid
import threading
from pathlib import Path
from collections import deque

from flask import Flask, jsonify, request, send_file
from flask_cors import CORS

from inference import analyze_video

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

UPLOAD_DIR = Path(__file__).parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

# ── In-memory job store ───────────────────────────────────────────────────────
# { job_id: { "status": "processing"|"done"|"error", "progress": 0.0-1.0,
#             "result": {...}, "video_path": "..." } }
_jobs: dict[str, dict] = {}
_jobs_lock = threading.Lock()

# ── Web video file queue — keeps only last 10 video files on disk ─────────────
# Stores job_ids in insertion order. When length exceeds 10,
# the oldest job's video file is deleted (data is kept).
_web_video_queue: deque[str] = deque(maxlen=10)
_queue_lock = threading.Lock()

MAX_WEB_VIDEOS = 10


# ── Helpers ───────────────────────────────────────────────────────────────────
def _enforce_video_limit():
    """
    Called after every completed analysis.
    If more than MAX_WEB_VIDEOS files exist, delete the oldest one.
    The job record (status, result) is kept — only the file is removed.
    """
    with _queue_lock:
        if len(_web_video_queue) >= MAX_WEB_VIDEOS:
            oldest_job_id = _web_video_queue[0]
            with _jobs_lock:
                oldest_job = _jobs.get(oldest_job_id, {})
            video_path = oldest_job.get("video_path")
            if video_path:
                try:
                    Path(video_path).unlink(missing_ok=True)
                    with _jobs_lock:
                        if oldest_job_id in _jobs:
                            _jobs[oldest_job_id]["video_path"] = None
                except Exception as e:
                    print(f"[cleanup] Could not delete {video_path}: {e}")


def _run_job(job_id: str, video_path: str):
    def _progress(p: float):
        with _jobs_lock:
            _jobs[job_id]["progress"] = p

    try:
        result = analyze_video(video_path, progress_cb=_progress)
        with _jobs_lock:
            _jobs[job_id].update({
                "status":     "done",
                "progress":   1.0,
                "result":     result,
                "video_path": video_path,   # keep path — file stays on disk
            })

        # Register this job in the web video queue AFTER analysis succeeds
        with _queue_lock:
            _web_video_queue.append(job_id)

        # Enforce 10-video limit (deletes oldest file if needed)
        _enforce_video_limit()

    except Exception as e:
        with _jobs_lock:
            _jobs[job_id].update({
                "status": "error",
                "error":  str(e),
            })
        # On error, clean up the file immediately
        Path(video_path).unlink(missing_ok=True)


# ── Routes ────────────────────────────────────────────────────────────────────
@app.get("/health")
def health():
    return jsonify({"status": "ok", "version": "1.0.0"})


@app.post("/analyze")
def analyze():
    if "video" not in request.files:
        print(f"[analyze] request.files keys: {list(request.files.keys())}")
        print(f"[analyze] content-type: {request.content_type}")
        return jsonify({
            "error":         "No video file in request",
            "received_keys": list(request.files.keys()),
        }), 400

    f      = request.files["video"]
    job_id = str(uuid.uuid4())
    dest   = UPLOAD_DIR / f"{job_id}_{f.filename}"
    f.save(str(dest))

    with _jobs_lock:
        _jobs[job_id] = {
            "status":     "processing",
            "progress":   0.0,
            "result":     None,
            "video_path": str(dest),
        }

    thread = threading.Thread(
        target=_run_job, args=(job_id, str(dest)), daemon=True
    )
    thread.start()
    return jsonify({"job_id": job_id}), 202


@app.get("/status/<job_id>")
def status(job_id: str):
    with _jobs_lock:
        job = _jobs.get(job_id)
    if job is None:
        return jsonify({"error": "Job not found"}), 404
    # Expose whether the video file is still available
    return jsonify({
        "status":        job["status"],
        "progress":      job.get("progress", 0.0),
        "result":        job.get("result"),
        "video_path":    job.get("video_path"),          # None = file deleted
        "video_available": job.get("video_path") is not None,
    })


@app.get("/video/<job_id>")
def serve_video(job_id: str):
    """
    Streams the stored video file back to the client.
    Returns 404 if the job doesn't exist or the file was deleted
    (either by the 10-video limit or manually).
    """
    with _jobs_lock:
        job = _jobs.get(job_id)

    if job is None:
        return jsonify({"error": "Job not found"}), 404

    video_path = job.get("video_path")
    if not video_path or not Path(video_path).exists():
        return jsonify({"error": "Video file no longer available"}), 404

    return send_file(
        video_path,
        mimetype="video/mp4",
        conditional=True,   # supports range requests (seek works in browser)
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)