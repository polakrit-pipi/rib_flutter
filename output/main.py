from ultralytics import YOLO

if __name__ == "__main__":
    model = YOLO("yolo11m-seg.pt")

    model.train(
        data="dataset/dataset.yaml",
        epochs=120,
        imgsz=640,
        device=0,
        workers=4,
        batch=8,

        # =========================
        # Augmentation (X-ray ribs)
        # =========================
        mosaic=0.05,         # ต่ำมาก (กัน anatomy เพี้ยน)
        mixup=0.0,           # ปิด
        fliplr=0.0,          # ห้าม flip ซ้ายขวา
        flipud=0.0,

        degrees=5.0,         # หมุนเล็กน้อย
        translate=0.05,      # ขยับนิดเดียว
        scale=0.1,           # scale เบา ๆ
        shear=0.0,
        perspective=0.0,

        hsv_h=0.0,           # grayscale → ปิด
        hsv_s=0.0,
        hsv_v=0.2,           # ปรับความสว่างเล็กน้อย (เหมือน exposure)

        # =========================
        # Regularization
        # =========================
        erasing=0.1,         # random erasing เบามาก (noise detector)
        close_mosaic=10,     # ปิด mosaic ช่วงท้าย

        # =========================
        # Optimizer & LR
        # =========================
        optimizer="AdamW",
        lr0=1e-3,
        lrf=1e-2,
        weight_decay=5e-4,
        momentum=0.9,

        # =========================
        # Segmentation tuning
        # =========================
        box=7.5,
        cls=0.5,
        dfl=1.5,
        overlap_mask=True,
        mask_ratio=4,

        # =========================
        # Patient-level stability
        # =========================
        patience=30,         # early stop กัน overfit
        cache=True,
        pretrained=True,
        verbose=False, 
        amp=True
    )
