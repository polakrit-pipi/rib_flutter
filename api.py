"""
FastAPI backend for Rib 9 Overlap Lung Scanner

Scoring:
- Conf >= 0.89 และ OVERLAP > 0.54  → PASS
- Conf >= 0.89 และ OVERLAP <= 0.54 → FAIL
- Conf < 0.89                       → NEEDS_REVIEW
"""

import base64
import traceback
from pathlib import Path

import cv2
import numpy as np
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from ultralytics import YOLO


# =========================================================
# CONSTANTS
# =========================================================

CONF_THRESHOLD = 0.89
OVERLAP_THRESHOLD = 0.85

SAVE_SCORING_DEBUG = True
BOUNDARY_MARGIN_PX = 0


# =========================================================
# APP SETUP
# =========================================================

app = FastAPI(
    title="Rib 9 Overlap Lung API",
    description=(
        "YOLO-based lung & rib-9 segmentation "
        "with confidence-aware overlap scoring"
    ),
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

model_lung: YOLO | None = None
model_rib: YOLO | None = None
_load_error: str | None = None


@app.on_event("startup")
async def startup_event():
    global model_lung, model_rib, _load_error

    try:
        model_lung = YOLO("lung.pt")
        model_rib = YOLO("best.pt")

        print("✅ Models loaded successfully.")

    except Exception as exc:
        _load_error = str(exc)
        print(f"❌ Error loading models: {exc}")


# =========================================================
# SMALL HELPERS
# =========================================================

def compute_overlap_ratio(
    lung_mask: np.ndarray,
    rib_mask: np.ndarray,
) -> float:
    """
    สัดส่วนพื้นที่ rib ที่อยู่ใน lung

    intersection / rib_area
    """

    intersection = int(
        np.sum(
            (lung_mask == 1)
            & (rib_mask == 1)
        )
    )

    rib_area = int(
        np.sum(rib_mask == 1)
    )

    if rib_area == 0:
        return 0.0

    return intersection / rib_area


def build_scoring_mask(
    rib_mask: np.ndarray,
    lung_mask: np.ndarray,
    image_side: str,
    margin_px: int = BOUNDARY_MARGIN_PX,
) -> np.ndarray:
    """
    1. ตัดขอบนอกด้วยขอบนอกสุดของปอด
    2. ตัดขอบในตามขอบปอดแต่ละแถว
    """

    height, width = rib_mask.shape

    scoring_mask = rib_mask.copy()
    side_lung_mask = lung_mask.copy()

    if image_side == "left":
        side_lung_mask[:, width // 2:] = 0

    elif image_side == "right":
        side_lung_mask[:, :width // 2] = 0

    else:
        raise ValueError(
            'image_side must be "left" or "right".'
        )

    all_lung_points = np.argwhere(
        side_lung_mask == 1
    )

    if all_lung_points.size == 0:
        return scoring_mask

    # -----------------------------------------------------
    # ตัดขอบนอก
    # -----------------------------------------------------

    if image_side == "left":
        # x ซ้ายสุดของปอดซ้าย
        outer_x = max(
            int(all_lung_points[:, 1].min()) - margin_px,
            0,
        )

        # ตัด rib ที่เลยขอบนอกไปทางซ้าย
        scoring_mask[:, :outer_x] = 0

    else:
        # x ขวาสุดของปอดขวา
        outer_x = min(
            int(all_lung_points[:, 1].max()) + margin_px,
            width - 1,
        )

        # ตัด rib ที่เลยขอบนอกไปทางขวา
        scoring_mask[:, outer_x + 1:] = 0

    # -----------------------------------------------------
    # ตัดขอบในตามขอบปอดแต่ละแถว
    # -----------------------------------------------------

    # -----------------------------------------------------
    # หาจุดเริ่มส่วนล่างของปอดฝั่งซ้าย
    # -----------------------------------------------------

    left_lower_start_y = height

    if image_side == "left":
        inner_curve = np.full(
            height,
            np.nan,
            dtype=np.float32,
        )

        for y in range(height):
            lung_x_positions = np.flatnonzero(
                side_lung_mask[y] == 1
            )

            if lung_x_positions.size > 0:
                # ขอบในของปอดซ้าย
                inner_curve[y] = float(
                    lung_x_positions[-1]
                )

        valid_y = np.flatnonzero(
            ~np.isnan(inner_curve)
        )

        if valid_y.size > 1:
            first_y = int(valid_y[0])
            last_y = int(valid_y[-1])

            # เติมแถวที่ mask ขาด
            inner_curve[first_y:last_y + 1] = np.interp(
                np.arange(first_y, last_y + 1),
                valid_y,
                inner_curve[valid_y],
            )

            # ทำเส้นขอบปอดให้เรียบ ลดรอยหยักของ mask
            smooth_curve = cv2.GaussianBlur(
                inner_curve.reshape(-1, 1),
                (1, 31),
                0,
            ).reshape(-1)

            # เริ่มค้นหาเฉพาะช่วงล่างของปอด
            search_start_y = first_y + int(
                (last_y - first_y) * 0.55
            )

            slope_window = 15
            inward_drop_px = 8
            required_rows = 8

            curve_change = (
                smooth_curve[slope_window:]
                - smooth_curve[:-slope_window]
            )

            # ค่าเป็นลบ = ขอบปอดเว้าเข้าทางซ้าย
            inward_rows = (
                curve_change <= -inward_drop_px
            )

            inward_rows[:search_start_y] = False

            # ต้องเว้าต่อเนื่องหลายแถว ป้องกัน noise
            sustained_inward = np.convolve(
                inward_rows.astype(np.uint8),
                np.ones(required_rows, dtype=np.uint8),
                mode="same",
            ) >= required_rows

            candidates = np.flatnonzero(
                sustained_inward
            )

            if candidates.size > 0:
                left_lower_start_y = int(
                    candidates[0]
                )


    # -----------------------------------------------------
    # ตัดขอบใน
    # -----------------------------------------------------

    for y in range(height):
        lung_x_positions = np.flatnonzero(
            side_lung_mask[y] == 1
        )

        if lung_x_positions.size == 0:
            continue

        if image_side == "left":
            # พอถึงช่วงล่างที่ปอดเริ่มเว้า ให้หยุดตัด rib
            if y >= left_lower_start_y:
                continue

            inner_x = min(
                int(lung_x_positions[-1]) + margin_px,
                width - 1,
            )

            scoring_mask[y, inner_x + 1:] = 0

        else:
            inner_x = max(
                int(lung_x_positions[0]) - margin_px,
                0,
            )

            scoring_mask[y, :inner_x] = 0

        # -----------------------------------------------------
    # ตัดส่วนล่างของ rib ตามสัดส่วนความสูง
    # -----------------------------------------------------

    rib_points = np.argwhere(
        scoring_mask == 1
    )

    if rib_points.size > 0:
        rib_top_y = int(
            rib_points[:, 0].min()
        )

        rib_bottom_y = int(
            rib_points[:, 0].max()
        )

        rib_height = (
            rib_bottom_y
            - rib_top_y
            + 1
        )

        cut_ratio = 0.80

        y_cut = int(
            rib_top_y
            + rib_height * cut_ratio
        )

        scoring_mask[
            y_cut + 1:,
            :
        ] = 0

    return scoring_mask

def save_scoring_debug_image(
    original_image: np.ndarray,
    lung_mask: np.ndarray,
    scoring_rib_mask: np.ndarray,
    scoring_overlap_mask: np.ndarray,
) -> None:
    """
    น้ำเงิน = lung
    แดง = scoring rib
    ม่วง = overlap ที่ใช้คำนวณ
    """

    if not SAVE_SCORING_DEBUG:
        return

    output_directory = Path("output")
    output_directory.mkdir(
        parents=True,
        exist_ok=True,
    )

    debug_overlay = original_image.copy()

    debug_overlay[
        lung_mask == 1
    ] = [255, 0, 0]

    debug_overlay[
        scoring_rib_mask == 1
    ] = [0, 0, 255]

    debug_overlay[
        scoring_overlap_mask == 1
    ] = [255, 0, 255]

    debug_image = cv2.addWeighted(
        debug_overlay,
        0.4,
        original_image,
        0.6,
        0,
    )

    cv2.imwrite(
        str(
            output_directory
            / "scoring_mask_result.jpg"
        ),
        debug_image,
    )


def draw_review_box(
    image: np.ndarray,
    box_xyxy: np.ndarray,
) -> np.ndarray:
    """
    วาดกรอบ NEEDS REVIEW
    """

    x1, y1, x2, y2 = box_xyxy.astype(int)

    color = (0, 165, 255)
    label = "NEEDS REVIEW"

    cv2.rectangle(
        image,
        (x1, y1),
        (x2, y2),
        color,
        thickness=3,
    )

    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = 0.65
    thickness = 2

    (text_width, text_height), baseline = cv2.getTextSize(
        label,
        font,
        font_scale,
        thickness,
    )

    tag_y1 = max(
        y1 - text_height - baseline - 8,
        0,
    )

    tag_y2 = max(
        y1 - 2,
        text_height + baseline + 8,
    )

    cv2.rectangle(
        image,
        (x1, tag_y1),
        (x1 + text_width + 8, tag_y2),
        color,
        -1,
    )

    cv2.putText(
        image,
        label,
        (x1 + 4, tag_y2 - baseline - 2),
        font,
        font_scale,
        (0, 0, 0),
        thickness,
        cv2.LINE_AA,
    )

    return image


def draw_verdict_overlay(
    image: np.ndarray,
    verdict: str,
    conf: float,
    overlap: float,
) -> np.ndarray:
    """
    วาดผล PASS / FAIL / NEEDS_REVIEW
    """

    if verdict == "PASS":
        color = (0, 200, 100)

    elif verdict == "FAIL":
        color = (0, 0, 220)

    else:
        color = (0, 165, 255)

    _, width = image.shape[:2]

    label = (
        f"{verdict}  "
        f"conf={conf:.2f}  "
        f"OVERLAP={overlap:.2f}"
    )

    font = cv2.FONT_HERSHEY_SIMPLEX
    scale = 0.7
    thickness = 2
    margin = 12

    (text_width, text_height), baseline = cv2.getTextSize(
        label,
        font,
        scale,
        thickness,
    )

    x1 = width - text_width - margin * 2
    y1 = margin
    x2 = width - margin
    y2 = margin + text_height + baseline + 8

    cv2.rectangle(
        image,
        (x1, y1),
        (x2, y2),
        color,
        -1,
    )

    cv2.putText(
        image,
        label,
        (x1 + margin // 2, y2 - baseline - 4),
        font,
        scale,
        (255, 255, 255),
        thickness,
        cv2.LINE_AA,
    )

    return image


def encode_image_base64(
    image: np.ndarray,
) -> str:
    """
    แปลงภาพ OpenCV เป็น JPEG Base64
    """

    success, image_buffer = cv2.imencode(
        ".jpg",
        image,
        [cv2.IMWRITE_JPEG_QUALITY, 90],
    )

    if not success:
        raise RuntimeError(
            "Could not encode image."
        )

    return base64.b64encode(
        image_buffer
    ).decode("utf-8")


# =========================================================
# 1. รับและตรวจรูป
# =========================================================

async def read_uploaded_image(
    file: UploadFile,
) -> np.ndarray:
    """
    อ่าน UploadFile และแปลงเป็นภาพ OpenCV
    """

    try:
        contents = await file.read()

        file_bytes = np.frombuffer(
            contents,
            dtype=np.uint8,
        )

        image = cv2.imdecode(
            file_bytes,
            cv2.IMREAD_COLOR,
        )

        if image is None:
            raise ValueError(
                "Could not decode image."
            )

        return image

    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid image file: {exc}",
        ) from exc


# =========================================================
# 2. วิเคราะห์โมเดล
# =========================================================

def run_model_analysis(
    image: np.ndarray,
) -> dict:
    """
    รัน lung model และ rib model
    แล้วคืน masks, confidence และ bounding boxes
    """

    if model_lung is None or model_rib is None:
        raise RuntimeError(
            "Models are not loaded."
        )

    height, width = image.shape[:2]

    # -----------------------------------------------------
    # Lung segmentation
    # -----------------------------------------------------

    lung_result = model_lung(image)[0]

    if lung_result.masks is None:
        raise HTTPException(
            status_code=422,
            detail=(
                "Could not detect a lung in this image. "
                "Please upload a valid chest X-ray."
            ),
        )

    lung_mask = np.zeros(
        (height, width),
        dtype=np.uint8,
    )

    for mask_data in lung_result.masks.data:
        raw_mask = (
            mask_data
            .cpu()
            .numpy()
        )

        resized_mask = (
            cv2.resize(
                raw_mask,
                (width, height),
            ) > 0.5
        ).astype(np.uint8)

        lung_mask = np.maximum(
            lung_mask,
            resized_mask,
        )

    # -----------------------------------------------------
    # Rib segmentation
    # -----------------------------------------------------

    rib_result = model_rib(image)[0]

    full_rib_mask = np.zeros(
        (height, width),
        dtype=np.uint8,
    )

    rib_mask_class_8 = np.zeros(
        (height, width),
        dtype=np.uint8,
    )

    rib_mask_class_18 = np.zeros(
        (height, width),
        dtype=np.uint8,
    )

    rib_detected = False
    rib_confidences = []
    rib_boxes = []

    target_rib_classes = {8, 18}

    if (
        rib_result.masks is not None
        and len(rib_result.boxes) > 0
    ):
        detection_count = min(
            len(rib_result.boxes),
            len(rib_result.masks.data),
        )

        for index in range(detection_count):
            class_id = int(
                rib_result.boxes.cls[index]
                .cpu()
                .item()
            )

            if class_id not in target_rib_classes:
                continue

            rib_detected = True

            confidence = float(
                rib_result.boxes.conf[index]
                .cpu()
                .item()
            )

            rib_confidences.append(confidence)

            raw_rib_mask = (
                rib_result.masks.data[index]
                .cpu()
                .numpy()
            )

            resized_rib_mask = (
                cv2.resize(
                    raw_rib_mask,
                    (width, height),
                ) > 0.5
            ).astype(np.uint8)

            full_rib_mask = np.maximum(
                full_rib_mask,
                resized_rib_mask,
            )

            if class_id == 8:
                rib_mask_class_8 = np.maximum(
                    rib_mask_class_8,
                    resized_rib_mask,
                )

            elif class_id == 18:
                rib_mask_class_18 = np.maximum(
                    rib_mask_class_18,
                    resized_rib_mask,
                )

            rib_box = (
                rib_result.boxes.xyxy[index]
                .cpu()
                .numpy()
            )

            rib_boxes.append(rib_box)

    rib_confidence = (
        min(rib_confidences)
        if rib_confidences
        else 0.0
    )

    return {
        "lung_mask": lung_mask,
        "full_rib_mask": full_rib_mask,
        "rib_mask_class_8": rib_mask_class_8,
        "rib_mask_class_18": rib_mask_class_18,
        "rib_detected": rib_detected,
        "rib_confidence": rib_confidence,
        "rib_boxes": rib_boxes,
    }


# =========================================================
# 3. คำนวณผล
# =========================================================

def calculate_analysis_result(
    image: np.ndarray,
    model_data: dict,
) -> dict:
    """
    สร้าง scoring mask
    คำนวณ overlap
    และตัดสิน verdict
    """

    lung_mask = model_data["lung_mask"]

    scoring_mask_class_8 = build_scoring_mask(
        rib_mask=model_data["rib_mask_class_8"],
        lung_mask=lung_mask,
        image_side="left",
    )

    scoring_mask_class_18 = build_scoring_mask(
        rib_mask=model_data["rib_mask_class_18"],
        lung_mask=lung_mask,
        image_side="right",
    )

    scoring_rib_mask = np.maximum(
        scoring_mask_class_8,
        scoring_mask_class_18,
    )

    scoring_overlap_mask = (
        (lung_mask == 1)
        & (scoring_rib_mask == 1)
    )

    lung_area = int(
        np.sum(lung_mask == 1)
    )

    rib_area = int(
        np.sum(scoring_rib_mask == 1)
    )

    overlap_area = int(
        np.sum(scoring_overlap_mask)
    )

    overlap_ratio = compute_overlap_ratio(
        lung_mask,
        scoring_rib_mask,
    )

    overlap_percent = overlap_ratio * 100.0

    save_scoring_debug_image(
        original_image=image,
        lung_mask=lung_mask,
        scoring_rib_mask=scoring_rib_mask,
        scoring_overlap_mask=scoring_overlap_mask,
    )

    rib_detected = model_data["rib_detected"]
    rib_confidence = model_data["rib_confidence"]

    # -----------------------------------------------------
    # Verdict
    # -----------------------------------------------------

    if not rib_detected:
        verdict = "FAIL"

        verdict_reason = (
            "Rib 9 was not detected in this image."
        )

    elif rib_confidence >= CONF_THRESHOLD:
        if overlap_ratio > OVERLAP_THRESHOLD:
            verdict = "PASS"

            verdict_reason = (
                f"High confidence "
                f"({rib_confidence:.2f} >= {CONF_THRESHOLD}) "
                f"and OVERLAP "
                f"({overlap_ratio:.3f}) "
                f"> {OVERLAP_THRESHOLD} threshold."
            )

        else:
            verdict = "FAIL"

            verdict_reason = (
                f"High confidence "
                f"({rib_confidence:.2f} >= {CONF_THRESHOLD}) "
                f"but OVERLAP "
                f"({overlap_ratio:.3f}) "
                f"<= {OVERLAP_THRESHOLD} threshold."
            )

    else:
        verdict = "NEEDS_REVIEW"

        if overlap_ratio > OVERLAP_THRESHOLD:
            verdict_reason = (
                f"Low confidence "
                f"({rib_confidence:.2f} < {CONF_THRESHOLD}). "
                f"OVERLAP "
                f"({overlap_ratio:.3f}) "
                f"looks acceptable but requires "
                f"manual verification."
            )

        else:
            verdict_reason = (
                f"Low confidence "
                f"({rib_confidence:.2f} < {CONF_THRESHOLD}) "
                f"and OVERLAP "
                f"({overlap_ratio:.3f}) "
                f"<= {OVERLAP_THRESHOLD}. "
                f"Manual review required."
            )

    return {
        **model_data,
        "scoring_rib_mask": scoring_rib_mask,
        "scoring_overlap_mask": scoring_overlap_mask,
        "lung_area": lung_area,
        "rib_area": rib_area,
        "overlap_area": overlap_area,
        "overlap_ratio": overlap_ratio,
        "overlap_percent": overlap_percent,
        "verdict": verdict,
        "verdict_reason": verdict_reason,
    }


# =========================================================
# 4. สร้าง RESPONSE
# =========================================================

def create_analysis_response(
    original_image: np.ndarray,
    analysis: dict,
) -> JSONResponse:
    """
    วาดภาพผลลัพธ์
    encode Base64
    และสร้าง JSON response
    """

    lung_mask = analysis["lung_mask"]
    full_rib_mask = analysis["full_rib_mask"]

    visual_overlap_mask = (
        (lung_mask == 1)
        & (full_rib_mask == 1)
    )

    overlay = original_image.copy()

    # น้ำเงิน = lung
    overlay[
        lung_mask == 1
    ] = [255, 0, 0]

    # แดง = rib
    overlay[
        full_rib_mask == 1
    ] = [0, 0, 255]

    # ม่วง = overlap
    overlay[
        visual_overlap_mask == 1
    ] = [255, 0, 255]

    result_image = cv2.addWeighted(
        overlay,
        0.4,
        original_image,
        0.6,
        0,
    )

    if (
        analysis["rib_detected"]
        and analysis["rib_confidence"] < CONF_THRESHOLD
    ):
        for box in analysis["rib_boxes"]:
            result_image = draw_review_box(
                result_image,
                box,
            )

    result_image = draw_verdict_overlay(
        result_image,
        analysis["verdict"],
        analysis["rib_confidence"],
        analysis["overlap_ratio"],
    )

    result_image_base64 = encode_image_base64(
        result_image
    )

    original_image_base64 = encode_image_base64(
        original_image
    )

    return JSONResponse(
        content={
            "lung_area": analysis["lung_area"],
            "rib_area": analysis["rib_area"],
            "overlap_area": analysis["overlap_area"],
            "overlap_percent": round(
                analysis["overlap_percent"],
                2,
            ),

            # คงชื่อ iou ไว้ เพื่อไม่ให้ frontend เดิมพัง
            # แต่ค่าจริงคือ intersection / rib_area
            "iou": round(
                analysis["overlap_ratio"],
                4,
            ),

            "rib_conf": round(
                analysis["rib_confidence"],
                4,
            ),
            "verdict": analysis["verdict"],
            "verdict_reason": analysis["verdict_reason"],
            "rib_detected": analysis["rib_detected"],
            "result_image": result_image_base64,
            "original_image": original_image_base64,
            "thresholds": {
                "conf": CONF_THRESHOLD,
                "OVERLAP": OVERLAP_THRESHOLD,
            },
        }
    )


# =========================================================
# ENDPOINTS
# =========================================================

@app.get("/health")
async def health():
    if _load_error:
        raise HTTPException(
            status_code=503,
            detail=f"Model load error: {_load_error}",
        )

    if model_lung is None or model_rib is None:
        raise HTTPException(
            status_code=503,
            detail="Models not loaded yet.",
        )

    return {
        "status": "ok",
        "message": "Models are loaded and ready.",
    }


@app.post("/analyze")
async def analyze(
    file: UploadFile = File(...),
):
    """
    Endpoint ทำหน้าที่แค่ส่งข้อมูลไปตามแต่ละส่วน
    """

    if model_lung is None or model_rib is None:
        raise HTTPException(
            status_code=503,
            detail="Models not ready. Check /health.",
        )

    try:
        image = await read_uploaded_image(file)

        model_data = run_model_analysis(image)

        analysis = calculate_analysis_result(
            image,
            model_data,
        )

        return create_analysis_response(
            image,
            analysis,
        )

    except HTTPException:
        raise

    except Exception as exc:
        traceback.print_exc()

        raise HTTPException(
            status_code=500,
            detail=f"Analysis failed: {exc}",
        ) from exc