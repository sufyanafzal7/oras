import os
import uuid
import threading
from pathlib import Path

from flask import Flask, jsonify, request
from flask_cors import CORS

from inference import analyze_video

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})   # allows Flutter web builds on localhost to call the API

UPLOAD_DIR = Path(__file__).parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

# ── In-memory job store ───────────────────────────────────────────────────────
# { job_id: { "status": "processing"|"done"|"error", "progress": 0.0-1.0, "result": {...} } }
_jobs: dict[str, dict] = {}
_jobs_lock = threading.Lock()


# ── Helpers ───────────────────────────────────────────────────────────────────
def _run_job(job_id: str, video_path: str):
    def _progress(p: float):
        with _jobs_lock:
            _jobs[job_id]["progress"] = p

    try:
        result = analyze_video(video_path, progress_cb=_progress)
        with _jobs_lock:
            _jobs[job_id].update({"status": "done", "progress": 1.0, "result": result})
    except Exception as e:
        with _jobs_lock:
            _jobs[job_id].update({"status": "error", "error": str(e)})
    finally:
        Path(video_path).unlink(missing_ok=True)   # clean up upload


# ── Routes ────────────────────────────────────────────────────────────────────
@app.get("/health")
def health():
    return jsonify({"status": "ok", "version": "1.0.0"})


# Replace the /analyze route with this:
@app.post("/analyze")
def analyze():
    if "video" not in request.files:
        # Log what was received to help debug
        print(f"[analyze] request.files keys: {list(request.files.keys())}")
        print(f"[analyze] content-type: {request.content_type}")
        return jsonify({"error": "No video file in request", "received_keys": list(request.files.keys())}), 400

    f      = request.files["video"]
    job_id = str(uuid.uuid4())
    dest   = UPLOAD_DIR / f"{job_id}_{f.filename}"
    f.save(str(dest))

    with _jobs_lock:
        _jobs[job_id] = {"status": "processing", "progress": 0.0, "result": None}

    thread = threading.Thread(target=_run_job, args=(job_id, str(dest)), daemon=True)
    thread.start()
    return jsonify({"job_id": job_id}), 202


@app.get("/status/<job_id>")
def status(job_id: str):
    with _jobs_lock:
        job = _jobs.get(job_id)
    if job is None:
        return jsonify({"error": "Job not found"}), 404
    return jsonify(job)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)