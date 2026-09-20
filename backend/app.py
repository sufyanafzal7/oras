import os
import uuid
import threading
from pathlib import Path
from collections import deque

from flask import Flask, jsonify, request, send_file
from flask_cors import CORS

from inference import analyze_video
import json
from video_editor import render_timeline

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 9 * 1024 * 1024 * 1024  # 9 GB
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
_web_video_queue: deque[str] = deque()
_queue_lock = threading.Lock()

_render_jobs: dict[str, dict] = {}
_render_jobs_lock = threading.Lock()

MAX_WEB_VIDEOS = 10


# ── Helpers ───────────────────────────────────────────────────────────────────
def _enforce_video_limit():
    """
    Called after every completed WEB-platform analysis.
    If more than MAX_WEB_VIDEOS web-sourced files exist on disk, delete the
    oldest one that is NOT protected. A job becomes protected once the
    Flutter app has built an editing timeline referencing it — see
    /jobs/<job_id>/protect. The job record (status, result) is always
    kept; only the video file itself is removed.
    """
    with _queue_lock:
        with _jobs_lock:
            live = [
                jid for jid in _web_video_queue
                if _jobs.get(jid, {}).get("video_path")
            ]
        if len(live) <= MAX_WEB_VIDEOS:
            return

        with _jobs_lock:
            for jid in live:
                if len(live) <= MAX_WEB_VIDEOS:
                    break
                if _jobs.get(jid, {}).get("protected"):
                    continue
                video_path = _jobs[jid]["video_path"]
                try:
                    Path(video_path).unlink(missing_ok=True)
                    _jobs[jid]["video_path"] = None
                    live.remove(jid)
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
                "video_path": video_path,
            })

        with _jobs_lock:
            platform = _jobs[job_id].get("platform", "web")

        if platform == "web":
            with _queue_lock:
                _web_video_queue.append(job_id)
            _enforce_video_limit()

    except Exception as e:
        with _jobs_lock:
            _jobs[job_id].update({
                "status": "error",
                "error":  str(e),
            })
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

    f        = request.files["video"]
    platform = request.form.get("platform", "web")  # web | android | windows | macos | linux
    job_id   = str(uuid.uuid4())
    dest     = UPLOAD_DIR / f"{job_id}_{f.filename}"
    f.save(str(dest))

    with _jobs_lock:
        _jobs[job_id] = {
            "status":     "processing",
            "progress":   0.0,
            "result":     None,
            "video_path": str(dest),
            "platform":   platform,
            "protected":  False,
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
    return jsonify({
        "status":          job["status"],
        "progress":        job.get("progress", 0.0),
        "result":          job.get("result"),
        "video_path":      job.get("video_path"),
        "video_available": job.get("video_path") is not None,
    })


@app.get("/video/<job_id>")
def serve_video(job_id: str):
    """
    Streams the stored video file back to the client.
    Returns 404 if the job doesn't exist or the file was deleted.
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
        conditional=True,
    )


@app.post("/jobs/<job_id>/protect")
def protect_job(job_id: str):
    """
    Marks a job's source video as protected from the web-only rolling
    upload limit. Called by the Flutter app the moment an editing
    timeline is created that references this video.
    """
    with _jobs_lock:
        job = _jobs.get(job_id)
        if job is None:
            return jsonify({"error": "Job not found"}), 404
        job["protected"] = True
    return jsonify({"status": "protected"})


@app.post("/jobs/<job_id>/unprotect")
def unprotect_job(job_id: str):
    """
    Clears the protected flag once the last editing timeline referencing
    this video has been deleted. The video is once again eligible for
    the web-only rolling upload limit on the next cleanup pass.
    """
    with _jobs_lock:
        job = _jobs.get(job_id)
        if job is None:
            return jsonify({"error": "Job not found"}), 404
        job["protected"] = False
    return jsonify({"status": "unprotected"})


@app.post("/edit/render")
def edit_render():
    """
    Renders an EditTimeline into a final video file via ffmpeg.
    Multipart form:
      - job_id: primary source video's job id (already on this backend)
      - edit_plan: JSON string {clips: [...], overlays: [...]}
      - imported_<i>: file, for any clip at index i with its own imported source
      - overlay_image_<i>: file, for any image-type overlay at index i
    Returns {render_job_id} immediately (202); poll /edit/status/<id>.
    """
    job_id = request.form.get("job_id")
    edit_plan_raw = request.form.get("edit_plan")
    if not job_id or not edit_plan_raw:
        return jsonify({"error": "job_id and edit_plan are required"}), 400

    with _jobs_lock:
        source_job = _jobs.get(job_id)
    if source_job is None or not source_job.get("video_path"):
        return jsonify({"error": "Source video not found or no longer available"}), 404

    edit_plan = json.loads(edit_plan_raw)

    render_id = str(uuid.uuid4())
    render_dir = UPLOAD_DIR / "renders" / render_id
    render_dir.mkdir(parents=True, exist_ok=True)

    imported_files = {}
    overlay_image_files = {}
    for key, f in request.files.items():
        if key.startswith("imported_"):
            idx = int(key.split("_", 1)[1])
            dest = render_dir / f"imported_{idx}_{f.filename}"
            f.save(str(dest))
            imported_files[idx] = str(dest)
        elif key.startswith("overlay_image_"):
            idx = int(key.split("_", 2)[2])
            dest = render_dir / f"overlay_{idx}_{f.filename}"
            f.save(str(dest))
            overlay_image_files[idx] = str(dest)

    output_path = str(render_dir / "output.mp4")

    with _render_jobs_lock:
        _render_jobs[render_id] = {"status": "processing", "progress": "", "output_path": None}

    def _run():
        try:
            render_timeline(
                primary_video_path=source_job["video_path"],
                edit_plan=edit_plan,
                imported_files=imported_files,
                overlay_image_files=overlay_image_files,
                output_path=output_path,
                progress_cb=lambda line: _render_jobs[render_id].update({"progress": line.strip()}),
            )
            with _render_jobs_lock:
                _render_jobs[render_id].update({"status": "done", "output_path": output_path})
        except Exception as e:
            with _render_jobs_lock:
                _render_jobs[render_id].update({"status": "error", "error": str(e)})

    threading.Thread(target=_run, daemon=True).start()
    return jsonify({"render_job_id": render_id}), 202


@app.get("/edit/status/<render_id>")
def edit_status(render_id: str):
    with _render_jobs_lock:
        job = _render_jobs.get(render_id)
    if job is None:
        return jsonify({"error": "Render job not found"}), 404
    return jsonify({
        "status": job["status"],
        "progress": job.get("progress", ""),
        "error": job.get("error"),
    })


@app.get("/edit/download/<render_id>")
def edit_download(render_id: str):
    with _render_jobs_lock:
        job = _render_jobs.get(render_id)
    if job is None or job.get("status") != "done":
        return jsonify({"error": "Render not ready"}), 404
    return send_file(job["output_path"], mimetype="video/mp4", as_attachment=True,
                      download_name="oras_export.mp4")


if __name__ == "__main__":
    from waitress import serve
    print("[ORAS] Starting backend on http://0.0.0.0:5000 ...")
    port = int(os.environ.get("PORT", 5000))
    serve(app, host="0.0.0.0", port=port,
        threads=4,
        max_request_body_size=9 * 1024 * 1024 * 1024,  # match Flask's 9 GB cap
        channel_timeout=1800,  # 30 min — enough headroom for slow large uploads
    )