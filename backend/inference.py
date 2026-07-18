import cv2
import numpy as np
import onnxruntime as ort
from pathlib import Path
from collections import deque

# ── Model paths ───────────────────────────────────────────────────────────────
PROJECT_ROOT     = Path(__file__).parent.parent          # D:\Projects\oras
YOLO_ONNX        = PROJECT_ROOT / "ml" / "models" / "tool_detection.onnx"
TCN_ONNX         = PROJECT_ROOT / "models" / "phase" / "tcn_phase.onnx"

# ── Constants — must exactly match training notebooks ────────────────────────
TOOL_COLS = [
    "grasper", "bipolar", "hook", "scissors",
    "clipper", "irrigator", "specimenbag"
]
# Phase order = alphabetical (how LabelEncoder encoded them in training)
PHASE_NAMES = [
    "CalotTriangleDissection",   # 0
    "CleaningCoagulation",       # 1
    "ClippingCutting",           # 2
    "GallbladderDissection",     # 3
    "GallbladderPackaging",      # 4
    "GallbladderRetraction",     # 5
    "Preparation",               # 6
]
SEQ_LEN    = 32
IMG_SIZE   = 640
CONF_THRES = 0.25
IOU_THRES  = 0.45

# ── Lazy-loaded sessions ─────────────────────────────────────────────────────
_yolo_session  = None
_phase_session = None

def _get_yolo_session():
    global _yolo_session
    if _yolo_session is None:
        _yolo_session = ort.InferenceSession(
            str(YOLO_ONNX),
            providers=["CUDAExecutionProvider", "CPUExecutionProvider"]
        )
    return _yolo_session

def _get_phase_session():
    global _phase_session
    if _phase_session is None:
        _phase_session = ort.InferenceSession(
            str(TCN_ONNX),
            providers=["CUDAExecutionProvider", "CPUExecutionProvider"]
        )
    return _phase_session


# ── YOLO helpers (copied exactly from notebook Cell 3) ───────────────────────
def _preprocess_frame(frame_bgr: np.ndarray) -> np.ndarray:
    img = cv2.resize(frame_bgr, (IMG_SIZE, IMG_SIZE))
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    img = img.astype(np.float32) / 255.0
    img = np.transpose(img, (2, 0, 1))
    return np.expand_dims(img, axis=0)   # (1, 3, 640, 640)


def _nms(boxes, scores, iou_threshold=IOU_THRES):
    x1, y1, x2, y2 = boxes[:, 0], boxes[:, 1], boxes[:, 2], boxes[:, 3]
    areas  = (x2 - x1) * (y2 - y1)
    order  = scores.argsort()[::-1]
    keep   = []
    while order.size > 0:
        i = order[0]
        keep.append(i)
        xx1 = np.maximum(x1[i], x1[order[1:]])
        yy1 = np.maximum(y1[i], y1[order[1:]])
        xx2 = np.minimum(x2[i], x2[order[1:]])
        yy2 = np.minimum(y2[i], y2[order[1:]])
        inter = np.maximum(0, xx2 - xx1) * np.maximum(0, yy2 - yy1)
        iou   = inter / (areas[i] + areas[order[1:]] - inter + 1e-6)
        order = order[1:][iou <= iou_threshold]
    return keep


def _postprocess_yolo(output: np.ndarray, orig_h: int, orig_w: int):
    preds       = output[0].T                       # (num_anchors, 11)
    boxes_xywh  = preds[:, :4]
    class_probs = preds[:, 4:]
    class_ids   = class_probs.argmax(axis=1)
    confidences = class_probs.max(axis=1)

    mask        = confidences >= CONF_THRES
    boxes_xywh  = boxes_xywh[mask]
    confidences = confidences[mask]
    class_ids   = class_ids[mask]

    sx, sy = orig_w / IMG_SIZE, orig_h / IMG_SIZE
    x1 = (boxes_xywh[:, 0] - boxes_xywh[:, 2] / 2) * sx
    y1 = (boxes_xywh[:, 1] - boxes_xywh[:, 3] / 2) * sy
    x2 = (boxes_xywh[:, 0] + boxes_xywh[:, 2] / 2) * sx
    y2 = (boxes_xywh[:, 1] + boxes_xywh[:, 3] / 2) * sy
    boxes_xyxy = np.stack([x1, y1, x2, y2], axis=1)

    keep           = _nms(boxes_xyxy, confidences) if len(boxes_xyxy) > 0 else []
    tool_presence  = np.zeros(len(TOOL_COLS), dtype=np.float32)
    detections     = []

    for idx in keep:
        cid  = class_ids[idx]
        conf = float(confidences[idx])
        tool_presence[cid] = 1.0
        detections.append({"tool": TOOL_COLS[cid], "confidence": round(conf, 3)})

    return tool_presence, detections


# ── Feature vector (copied exactly from notebook Cell 3 + Cell 4) ────────────
def _build_feature_vector(tool_presence: np.ndarray,
                           tool_window: deque,
                           frame_norm: float) -> np.ndarray:
    """
    16-dim: [7 tool binary] + [tool_count] + [frame_norm] + [7 roll5 means]
    Matches FEATURE_COLS from training exactly.
    """
    tool_count = float(tool_presence.sum())
    window_arr = np.array(tool_window)                 # (<=32, 7)
    roll_start = max(0, len(window_arr) - 5)
    roll5      = window_arr[roll_start:].mean(axis=0)  # (7,)
    feat = np.concatenate([
        tool_presence,   # 7
        [tool_count],    # 1
        [frame_norm],    # 1
        roll5            # 7
    ])
    return feat.astype(np.float32)                     # (16,)


# ── Main analysis entry point ─────────────────────────────────────────────────
def analyze_video(video_path: str, progress_cb=None) -> dict:
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise ValueError(f"Cannot open video: {video_path}")

    fps        = cap.get(cv2.CAP_PROP_FPS) or 25.0
    total      = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    duration_s = total / fps

    yolo_sess  = _get_yolo_session()
    phase_sess = _get_phase_session()

    yolo_input_name  = yolo_sess.get_inputs()[0].name
    yolo_output_name = yolo_sess.get_outputs()[0].name
    tcn_input_name   = "tool_sequence"    # set during ONNX export
    tcn_output_name  = "phase_logits"

    # Rolling windows — pre-padded with zeros exactly like the notebook
    tool_window = deque(maxlen=SEQ_LEN)
    feat_window = deque(maxlen=SEQ_LEN)
    for _ in range(SEQ_LEN):
        tool_window.append(np.zeros(len(TOOL_COLS), dtype=np.float32))
        feat_window.append(np.zeros(16, dtype=np.float32))

    phase_timeline : list[dict] = []
    tool_totals    : dict[str, int] = {t: 0 for t in TOOL_COLS}
    current_phase  = None

    frame_idx   = 0
    sample_rate = max(1, int(fps / 2))   # sample at ~2 fps

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        if frame_idx % sample_rate != 0:
            frame_idx += 1
            continue

        orig_h, orig_w = frame.shape[:2]

        # — YOLO —
        inp                        = _preprocess_frame(frame)
        yolo_out                   = yolo_sess.run([yolo_output_name], {yolo_input_name: inp})[0]
        tool_presence, detections  = _postprocess_yolo(yolo_out, orig_h, orig_w)

        for d in detections:
            tool_totals[d["tool"]] += 1

        # — Feature vector —
        sampled_idx = frame_idx // sample_rate
        frame_norm  = sampled_idx / max(total // sample_rate - 1, 1)
        tool_window.append(tool_presence.copy())
        feat_vec = _build_feature_vector(tool_presence, tool_window, frame_norm)
        feat_window.append(feat_vec)

        # — TCN —
        tcn_input   = np.array(feat_window, dtype=np.float32)[np.newaxis]  # (1, 32, 16)
        logits      = phase_sess.run([tcn_output_name], {tcn_input_name: tcn_input})[0][0]
        probs       = np.exp(logits) / np.exp(logits).sum()
        phase_idx   = int(probs.argmax())
        phase       = PHASE_NAMES[phase_idx]

        ts = frame_idx / fps
        if phase != current_phase:
            if phase_timeline:
                phase_timeline[-1]["end_time"] = round(ts, 2)
            phase_timeline.append({
                "phase":      phase,
                "start_time": round(ts, 2),
                "end_time":   round(duration_s, 2),
            })
            current_phase = phase

        if progress_cb and frame_idx % (sample_rate * 20) == 0:
            progress_cb(min(frame_idx / max(total, 1), 0.99))

        frame_idx += 1

    cap.release()

    if phase_timeline:
        phase_timeline[-1]["end_time"] = round(duration_s, 2)

    tools_summary = [
        {"tool": t, "frames_detected": c}
        for t, c in tool_totals.items() if c > 0
    ]

    return {
        "duration":       round(duration_s, 2),
        "fps":            round(fps, 2),
        "phase_timeline": phase_timeline,
        "tools_detected": tools_summary,
    }