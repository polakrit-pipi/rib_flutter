from pathlib import Path

import cv2
import numpy as np
from ultralytics import YOLO


# =========================================================
# CONFIG
# =========================================================

LUNG_MODEL_PATH = r"C:\Users\User\Desktop\Projects\Worapun_Rips_Project\py try case\ModelLung\best_lung.pt"
RIB_MODEL_PATH = r"C:\Users\User\Desktop\Projects\Worapun_Rips_Project\yolo_secment_allribs\runs\segment\train6\weights\best.pt"

FULL_FOLDER = Path(
    r"C:\Users\User\Desktop\Projects\Worapun_Rips_Project\Datasets\full-20260211T141350Z-1-001\full"
)

NOT_FULL_FOLDER = Path(
    r"C:\Users\User\Desktop\Projects\Worapun_Rips_Project\Datasets\not full-20260211T141350Z-1-001\not full"
)

RESULT_TXT_PATH = Path(
    r"evaluation_result.txt"
)

OVERLAP_THRESHOLD = 0.85
BOUNDARY_MARGIN_PX = 0

IMAGE_EXTENSIONS = {
    ".jpg",
    ".jpeg",
    ".png",
    ".bmp",
    ".tif",
    ".tiff",
}


# =========================================================
# OVERLAP
# =========================================================

def compute_overlap_ratio(
    lung_mask: np.ndarray,
    rib_mask: np.ndarray,
) -> float:
    """
    overlap = rib ที่อยู่ในปอด / พื้นที่ rib ทั้งหมด
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


# =========================================================
# SCORING MASK
# =========================================================

def build_scoring_mask(
    rib_mask: np.ndarray,
    lung_mask: np.ndarray,
    image_side: str,
    margin_px: int = BOUNDARY_MARGIN_PX,
) -> np.ndarray:
    """
    1. ตัดขอบนอกด้วยขอบนอกสุดของปอด
    2. ตัดขอบในตามขอบปอดแต่ละแถว
    3. ฝั่งซ้ายหยุดตัดเมื่อขอบปอดช่วงล่างเริ่มเว้า
    4. ตัดส่วนล่าง 20% ของ rib mask
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
        outer_x = max(
            int(all_lung_points[:, 1].min())
            - margin_px,
            0,
        )

        scoring_mask[:, :outer_x] = 0

    else:
        outer_x = min(
            int(all_lung_points[:, 1].max())
            + margin_px,
            width - 1,
        )

        scoring_mask[:, outer_x + 1:] = 0

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
                inner_curve[y] = float(
                    lung_x_positions[-1]
                )

        valid_y = np.flatnonzero(
            ~np.isnan(inner_curve)
        )

        if valid_y.size > 1:
            first_y = int(valid_y[0])
            last_y = int(valid_y[-1])

            inner_curve[
                first_y:last_y + 1
            ] = np.interp(
                np.arange(
                    first_y,
                    last_y + 1,
                ),
                valid_y,
                inner_curve[valid_y],
            )

            smooth_curve = cv2.GaussianBlur(
                inner_curve.reshape(-1, 1),
                (1, 31),
                0,
            ).reshape(-1)

            search_start_y = (
                first_y
                + int(
                    (last_y - first_y)
                    * 0.55
                )
            )

            slope_window = 15
            inward_drop_px = 8
            required_rows = 8

            curve_change = (
                smooth_curve[slope_window:]
                - smooth_curve[:-slope_window]
            )

            inward_rows = (
                curve_change
                <= -inward_drop_px
            )

            inward_rows[
                :search_start_y
            ] = False

            sustained_inward = (
                np.convolve(
                    inward_rows.astype(
                        np.uint8
                    ),
                    np.ones(
                        required_rows,
                        dtype=np.uint8,
                    ),
                    mode="same",
                )
                >= required_rows
            )

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
            if y >= left_lower_start_y:
                continue

            inner_x = min(
                int(lung_x_positions[-1])
                + margin_px,
                width - 1,
            )

            scoring_mask[
                y,
                inner_x + 1:
            ] = 0

        else:
            inner_x = max(
                int(lung_x_positions[0])
                - margin_px,
                0,
            )

            scoring_mask[
                y,
                :inner_x
            ] = 0

    # -----------------------------------------------------
    # ตัดส่วนล่างของ rib 20%
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


# =========================================================
# MODEL PREDICTION
# =========================================================

def predict_image(
    image_path: Path,
    lung_model: YOLO,
    rib_model: YOLO,
) -> dict:
    image = cv2.imread(
        str(image_path)
    )

    if image is None:
        raise ValueError(
            f"Could not read image: {image_path}"
        )

    height, width = image.shape[:2]

    # -----------------------------------------------------
    # Lung model
    # -----------------------------------------------------

    lung_result = lung_model(image)[0]

    if lung_result.masks is None:
        return {
            "verdict": "FAIL",
            "overlap_ratio": 0.0,
            "reason": "Lung not detected",
        }

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
    # Rib model
    # -----------------------------------------------------

    rib_result = rib_model(image)[0]

    rib_mask_class_8 = np.zeros(
        (height, width),
        dtype=np.uint8,
    )

    rib_mask_class_18 = np.zeros(
        (height, width),
        dtype=np.uint8,
    )

    rib_detected = False
    target_rib_classes = {8, 18}

    if (
        rib_result.masks is not None
        and len(rib_result.boxes) > 0
    ):
        detection_count = min(
            len(rib_result.boxes),
            len(rib_result.masks.data),
        )

        for index in range(
            detection_count
        ):
            class_id = int(
                rib_result.boxes.cls[index]
                .cpu()
                .item()
            )

            if class_id not in target_rib_classes:
                continue

            rib_detected = True

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

    if not rib_detected:
        return {
            "verdict": "FAIL",
            "overlap_ratio": 0.0,
            "reason": "Rib 9 not detected",
        }

    # -----------------------------------------------------
    # Scoring masks
    # -----------------------------------------------------

    scoring_mask_class_8 = build_scoring_mask(
        rib_mask=rib_mask_class_8,
        lung_mask=lung_mask,
        image_side="left",
    )

    scoring_mask_class_18 = build_scoring_mask(
        rib_mask=rib_mask_class_18,
        lung_mask=lung_mask,
        image_side="right",
    )

    scoring_rib_mask = np.maximum(
        scoring_mask_class_8,
        scoring_mask_class_18,
    )

    overlap_ratio = compute_overlap_ratio(
        lung_mask,
        scoring_rib_mask,
    )

    verdict = (
        "PASS"
        if overlap_ratio > OVERLAP_THRESHOLD
        else "FAIL"
    )

    return {
        "verdict": verdict,
        "overlap_ratio": overlap_ratio,
        "reason": (
            f"Overlap {overlap_ratio:.4f}"
        ),
    }


# =========================================================
# FOLDER EVALUATION
# =========================================================

def get_image_paths(
    folder_path: Path,
) -> list[Path]:
    if not folder_path.exists():
        raise FileNotFoundError(
            f"Folder not found: {folder_path}"
        )

    return sorted(
        path
        for path in folder_path.iterdir()
        if (
            path.is_file()
            and path.suffix.lower()
            in IMAGE_EXTENSIONS
        )
    )


def evaluate_folder(
    folder_path: Path,
    expected_verdict: str,
    lung_model: YOLO,
    rib_model: YOLO,
) -> dict:
    image_paths = get_image_paths(
        folder_path
    )

    correct_count = 0
    results = []

    for index, image_path in enumerate(
        image_paths,
        start=1,
    ):
        try:
            prediction = predict_image(
                image_path=image_path,
                lung_model=lung_model,
                rib_model=rib_model,
            )

            verdict = prediction["verdict"]
            overlap = prediction[
                "overlap_ratio"
            ]

            is_correct = (
                verdict == expected_verdict
            )

            if is_correct:
                correct_count += 1

            results.append(
                {
                    "filename": image_path.name,
                    "verdict": verdict,
                    "overlap": overlap,
                    "correct": is_correct,
                    "error": None,
                }
            )

            print(
                f"[{index}/{len(image_paths)}] "
                f"{image_path.name}: "
                f"{verdict} "
                f"(overlap={overlap:.4f})"
            )

        except Exception as exc:
            results.append(
                {
                    "filename": image_path.name,
                    "verdict": "ERROR",
                    "overlap": 0.0,
                    "correct": False,
                    "error": str(exc),
                }
            )

            print(
                f"[{index}/{len(image_paths)}] "
                f"{image_path.name}: "
                f"ERROR - {exc}"
            )

    total_count = len(image_paths)

    accuracy = (
        correct_count / total_count * 100.0
        if total_count > 0
        else 0.0
    )

    return {
        "folder": folder_path,
        "expected_verdict": expected_verdict,
        "correct_count": correct_count,
        "total_count": total_count,
        "accuracy": accuracy,
        "results": results,
    }


# =========================================================
# SAVE TXT
# =========================================================

def save_results_txt(
    full_result: dict,
    not_full_result: dict,
) -> None:
    total_correct = (
        full_result["correct_count"]
        + not_full_result["correct_count"]
    )

    total_images = (
        full_result["total_count"]
        + not_full_result["total_count"]
    )

    overall_accuracy = (
        total_correct
        / total_images
        * 100.0
        if total_images > 0
        else 0.0
    )

    lines = [
        "RIB 9 EVALUATION RESULT",
        "=" * 60,
        "",
        (
            "FULL folder: "
            f"PASS {full_result['correct_count']} "
            f"from {full_result['total_count']}"
        ),
        (
            "FULL accuracy: "
            f"{full_result['accuracy']:.2f}%"
        ),
        "",
        (
            "NOT FULL folder: "
            f"FAIL {not_full_result['correct_count']} "
            f"from {not_full_result['total_count']}"
        ),
        (
            "NOT FULL accuracy: "
            f"{not_full_result['accuracy']:.2f}%"
        ),
        "",
        (
            "OVERALL SUCCESS: "
            f"{total_correct} from {total_images}"
        ),
        (
            "OVERALL ACCURACY: "
            f"{overall_accuracy:.2f}%"
        ),
        "",
        "=" * 60,
        "FULL DETAILS",
        "=" * 60,
    ]

    for result in full_result["results"]:
        line = (
            f"{result['filename']} | "
            f"{result['verdict']} | "
            f"overlap={result['overlap']:.4f} | "
            f"{'CORRECT' if result['correct'] else 'WRONG'}"
        )

        if result["error"]:
            line += (
                f" | error={result['error']}"
            )

        lines.append(line)

    lines.extend(
        [
            "",
            "=" * 60,
            "NOT FULL DETAILS",
            "=" * 60,
        ]
    )

    for result in not_full_result["results"]:
        line = (
            f"{result['filename']} | "
            f"{result['verdict']} | "
            f"overlap={result['overlap']:.4f} | "
            f"{'CORRECT' if result['correct'] else 'WRONG'}"
        )

        if result["error"]:
            line += (
                f" | error={result['error']}"
            )

        lines.append(line)

    RESULT_TXT_PATH.write_text(
        "\n".join(lines),
        encoding="utf-8",
    )


# =========================================================
# MAIN
# =========================================================

def main() -> None:
    print("Loading models...")

    lung_model = YOLO(
        LUNG_MODEL_PATH
    )

    rib_model = YOLO(
        RIB_MODEL_PATH
    )

    print("Models loaded.")
    print()

    print("Evaluating FULL folder...")

    full_result = evaluate_folder(
        folder_path=FULL_FOLDER,
        expected_verdict="PASS",
        lung_model=lung_model,
        rib_model=rib_model,
    )

    print()
    print("Evaluating NOT FULL folder...")

    not_full_result = evaluate_folder(
        folder_path=NOT_FULL_FOLDER,
        expected_verdict="FAIL",
        lung_model=lung_model,
        rib_model=rib_model,
    )

    save_results_txt(
        full_result=full_result,
        not_full_result=not_full_result,
    )

    total_correct = (
        full_result["correct_count"]
        + not_full_result["correct_count"]
    )

    total_images = (
        full_result["total_count"]
        + not_full_result["total_count"]
    )

    overall_accuracy = (
        total_correct
        / total_images
        * 100.0
        if total_images > 0
        else 0.0
    )

    print()
    print("=" * 60)

    print(
        "FULL: "
        f"PASS {full_result['correct_count']} "
        f"from {full_result['total_count']} "
        f"({full_result['accuracy']:.2f}%)"
    )

    print(
        "NOT FULL: "
        f"FAIL {not_full_result['correct_count']} "
        f"from {not_full_result['total_count']} "
        f"({not_full_result['accuracy']:.2f}%)"
    )

    print(
        "OVERALL: "
        f"{total_correct} from {total_images} "
        f"({overall_accuracy:.2f}%)"
    )

    print(
        f"Saved result to: "
        f"{RESULT_TXT_PATH.resolve()}"
    )


if __name__ == "__main__":
    main()