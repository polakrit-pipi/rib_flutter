"""
FastAPI backend for Rib 9 Overlap Lung Scanner
Scoring System:
  - Conf >= 0.95  + IoU > 0.85  → PASS
  - Conf >= 0.95  + IoU <= 0.85 → FAIL
  - Conf <  0.95  (any IoU)     → NEEDS_REVIEW  (draws bounding box + tag on image)
"""

import base64
import traceback

import cv2
import numpy as np
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from ultralytics import YOLO

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
CONF_THRESHOLD  = 0.95   # high-confidence cut-off
IOU_THRESHOLD   = 0.85   # pass/fail IoU cut-off

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Rib 9 Overlap Lung API",
    description="YOLO-based lung & rib-9 segmentation with confidence-aware overlap scoring",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

model_lung: YOLO | None = None
model_rib:  YOLO | None = None
_load_error: str | None = None


@app.on_event("startup")
async def startup_event():
    global model_lung, model_rib, _load_error
    try:
        model_lung = YOLO("lung.pt")
        model_rib  = YOLO("best.pt")
        print("✅ Models loaded successfully.")
    except Exception as exc:
        _load_error = str(exc)
        print(f"❌ Error loading models: {exc}")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def compute_iou(mask_a: np.ndarray, mask_b: np.ndarray) -> float:
    """Compute Intersection-over-Union between two binary masks."""
    intersection = int(np.sum((mask_a == 1) & (mask_b == 1)))
    union        = int(np.sum((mask_a == 1) | (mask_b == 1)))
    return intersection / union if union > 0 else 0.0


def draw_review_box(image: np.ndarray, box_xyxy: np.ndarray,
                    conf: float, iou: float) -> np.ndarray:
    """Draw an orange bounding box + NEEDS REVIEW tag on the image."""
    x1, y1, x2, y2 = box_xyxy.astype(int)
    color = (0, 165, 255)   # orange in BGR

    # Bounding box
    cv2.rectangle(image, (x1, y1), (x2, y2), color, thickness=3)

    # Tag background
    label     = f"NEEDS REVIEW  conf={conf:.2f}  IoU={iou:.2f}"
    font      = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = 0.65
    thickness  = 2
    (tw, th), baseline = cv2.getTextSize(label, font, font_scale, thickness)
    tag_y1 = max(y1 - th - baseline - 8, 0)
    tag_y2 = max(y1 - 2, th + baseline + 8)
    cv2.rectangle(image, (x1, tag_y1), (x1 + tw + 8, tag_y2), color, -1)
    cv2.putText(image, label,
                (x1 + 4, tag_y2 - baseline - 2),
                font, font_scale, (0, 0, 0), thickness, cv2.LINE_AA)
    return image


def draw_verdict_overlay(image: np.ndarray, verdict: str,
                          conf: float, iou: float) -> np.ndarray:
    """Draw a small verdict badge in the top-right corner."""
    if verdict == "PASS":
        color = (0, 200, 100)     # green
    elif verdict == "FAIL":
        color = (0, 0, 220)       # red
    else:
        color = (0, 165, 255)     # orange

    h, w = image.shape[:2]
    label = f"{verdict}  conf={conf:.2f}  IoU={iou:.2f}"
    font  = cv2.FONT_HERSHEY_SIMPLEX
    scale = 0.7
    thick = 2
    (tw, th), bl = cv2.getTextSize(label, font, scale, thick)
    margin = 12
    x1 = w - tw - margin * 2
    y1 = margin
    x2 = w - margin
    y2 = margin + th + bl + 8
    cv2.rectangle(image, (x1, y1), (x2, y2), color, -1)
    cv2.putText(image, label,
                (x1 + margin // 2, y2 - bl - 4),
                font, scale, (255, 255, 255), thick, cv2.LINE_AA)
    return image


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():
    if _load_error:
        raise HTTPException(status_code=503, detail=f"Model load error: {_load_error}")
    if model_lung is None or model_rib is None:
        raise HTTPException(status_code=503, detail="Models not loaded yet.")
    return {"status": "ok", "message": "Models are loaded and ready."}


@app.post("/analyze")
async def analyze(file: UploadFile = File(...)):
    """
    Analyze a chest X-ray image and return:
      - lung_area, rib_area, overlap_area (pixels)
      - iou                  : float  (Intersection over Union)
      - rib_conf             : float  (YOLO detection confidence)
      - verdict              : "PASS" | "FAIL" | "NEEDS_REVIEW"
      - verdict_reason       : human-readable explanation
      - overlap_percent      : % of rib inside lung (legacy)
      - result_image         : base64 JPEG with segmentation + verdict overlay
      - original_image       : base64 JPEG of input
      - rib_detected         : bool
    """
    if model_lung is None or model_rib is None:
        raise HTTPException(status_code=503, detail="Models not ready. Check /health.")

    # ── Read image ───────────────────────────────────────────────────────
    try:
        contents  = await file.read()
        file_bytes = np.frombuffer(contents, dtype=np.uint8)
        img_orig  = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)
        if img_orig is None:
            raise ValueError("Could not decode image.")
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid image file: {exc}")

    h_orig, w_orig = img_orig.shape[:2]

    try:
        # ── Stage 1: Lung segmentation ───────────────────────────────────
        res_lung = model_lung(img_orig)[0]
        if res_lung.masks is None:
            raise HTTPException(
                status_code=422,
                detail="Could not detect a lung in this image. Please upload a valid chest X-ray.",
            )

        lung_mask_raw  = res_lung.masks.data[0].cpu().numpy()
        lung_mask_full = (cv2.resize(lung_mask_raw, (w_orig, h_orig)) > 0.5).astype(np.uint8)

        box_lung       = res_lung.boxes.xyxy[0].cpu().numpy().astype(int)
        x1, y1, x2, y2 = box_lung
        img_crop       = img_orig[y1:y2, x1:x2]

        # ── Stage 2: Rib 9 segmentation ──────────────────────────────────
        res_rib = model_rib(img_crop)[0]
        full_rib_mask = np.zeros((h_orig, w_orig), dtype=np.uint8)

        rib_conf     = 0.0
        rib_detected = False
        rib_box_full = None   # xyxy in original image coords

        if res_rib.masks is not None and len(res_rib.boxes) > 0:
            rib_detected = True
            rib_conf     = float(res_rib.boxes.conf[0].cpu().numpy())

            rib_small    = res_rib.masks.data[0].cpu().numpy()
            rib_resized  = cv2.resize(rib_small, (x2 - x1, y2 - y1))
            full_rib_mask[y1:y2, x1:x2] = (rib_resized > 0.5).astype(np.uint8)

            # Bounding box of rib in original image coordinates
            rb = res_rib.boxes.xyxy[0].cpu().numpy()
            rib_box_full = np.array([rb[0] + x1, rb[1] + y1, rb[2] + x1, rb[3] + y1])

        # ── Metrics ───────────────────────────────────────────────────────
        overlap_mask  = (lung_mask_full == 1) & (full_rib_mask == 1)
        area_lung     = int(np.sum(lung_mask_full))
        area_rib      = int(np.sum(full_rib_mask))
        area_overlap  = int(np.sum(overlap_mask))

        iou = compute_iou(lung_mask_full, full_rib_mask)
        perc_rib_in_lung = float(area_overlap / area_rib * 100) if area_rib > 0 else 0.0

        # ── Verdict logic ─────────────────────────────────────────────────
        if not rib_detected:
            verdict = "FAIL"
            verdict_reason = "Rib 9 was not detected in this image."
        elif rib_conf >= CONF_THRESHOLD:
            if iou > IOU_THRESHOLD:
                verdict = "PASS"
                verdict_reason = (
                    f"High confidence ({rib_conf:.2f} ≥ {CONF_THRESHOLD}) "
                    f"and IoU ({iou:.3f}) > {IOU_THRESHOLD} threshold."
                )
            else:
                verdict = "FAIL"
                verdict_reason = (
                    f"High confidence ({rib_conf:.2f} ≥ {CONF_THRESHOLD}) "
                    f"but IoU ({iou:.3f}) ≤ {IOU_THRESHOLD} threshold."
                )
        else:
            # Low confidence — needs manual review
            if iou > IOU_THRESHOLD:
                verdict = "NEEDS_REVIEW"
                verdict_reason = (
                    f"Low confidence ({rib_conf:.2f} < {CONF_THRESHOLD}). "
                    f"IoU ({iou:.3f}) looks acceptable but requires manual verification."
                )
            else:
                verdict = "NEEDS_REVIEW"
                verdict_reason = (
                    f"Low confidence ({rib_conf:.2f} < {CONF_THRESHOLD}) "
                    f"and IoU ({iou:.3f}) ≤ {IOU_THRESHOLD}. Manual review required."
                )

        # ── Visualization ─────────────────────────────────────────────────
        overlay = img_orig.copy()
        overlay[lung_mask_full == 1] = [255, 0,   0  ]   # Blue  → Lung
        overlay[full_rib_mask  == 1] = [0,   0,   255]   # Red   → Rib 9
        overlay[overlap_mask   == 1] = [255, 0,   255]   # Magenta → Overlap

        output_img = cv2.addWeighted(overlay, 0.4, img_orig, 0.6, 0)

        # Draw bounding box + NEEDS REVIEW tag for low-confidence detections
        if rib_detected and rib_conf < CONF_THRESHOLD and rib_box_full is not None:
            output_img = draw_review_box(output_img, rib_box_full, rib_conf, iou)

        # Draw verdict badge on all results
        output_img = draw_verdict_overlay(output_img, verdict, rib_conf, iou)

        # ── Encode images ─────────────────────────────────────────────────
        _, buf_result = cv2.imencode(".jpg", output_img, [cv2.IMWRITE_JPEG_QUALITY, 90])
        result_b64    = base64.b64encode(buf_result).decode("utf-8")

        _, buf_orig   = cv2.imencode(".jpg", img_orig, [cv2.IMWRITE_JPEG_QUALITY, 90])
        orig_b64      = base64.b64encode(buf_orig).decode("utf-8")

        return JSONResponse(content={
            "lung_area":       area_lung,
            "rib_area":        area_rib,
            "overlap_area":    area_overlap,
            "overlap_percent": round(perc_rib_in_lung, 2),
            "iou":             round(iou, 4),
            "rib_conf":        round(rib_conf, 4),
            "verdict":         verdict,
            "verdict_reason":  verdict_reason,
            "rib_detected":    rib_detected,
            "result_image":    result_b64,
            "original_image":  orig_b64,
            "thresholds": {
                "conf": CONF_THRESHOLD,
                "iou":  IOU_THRESHOLD,
            },
        })

    except HTTPException:
        raise
    except Exception as exc:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Analysis failed: {exc}")
