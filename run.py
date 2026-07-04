import cv2
import numpy as np
from ultralytics import YOLO

# 1. โหลดโมเดล
model_lung = YOLO('./runs/segment/train2/weights/lung.pt')  # โมเดลหาปอด
model_rib = YOLO('best.pt')   # โมเดลหาซี่โครง 9

# 2. โหลดภาพต้นฉบับ
image_path = 'test.jpg'
img_orig = cv2.imread(image_path)
h_orig, w_orig = img_orig.shape[:2]

# --- Stage 1: หาขอบเขตปอด ---
results_lung = model_lung(img_orig)[0]

# ดึง Bounding Box (x1, y1, x2, y2) ของปอด (สมมติว่าเอาอันแรก)
if results_lung.boxes:
    # 0 is the index of the first detected lung
    box = results_lung.boxes.xyxy[0].cpu().numpy().astype(int) 
    x1, y1, x2, y2 = box

    # ตัดภาพ (Crop) เฉพาะบริเวณปอด
    img_crop = img_orig[y1:y2, x1:x2]

    # --- Stage 2: หาซี่โครงในภาพที่ Crop ---
    results_rib = model_rib(img_crop)[0]

    # --- การจัดตำแหน่ง Mask (Mask Alignment) ---
    # สร้าง Mask เปล่า ขนาดเท่าภาพต้นฉบับ
    full_rib_mask = np.zeros((h_orig, w_orig), dtype=np.uint8)

    if results_rib.masks:
        # ดึง Mask ซี่โครงเล็ก (เป็น numpy array)
        rib_mask_small = results_rib.masks.data[0].cpu().numpy()
        
        # ปรับขนาด Mask เล็กให้เท่ากับขนาดพื้นที่ที่ Crop มาเป๊ะๆ
        # (YOLO อาจจะ output mask ขนาดต่างจาก input เล็กน้อย)
        crop_h, crop_w = img_crop.shape[:2]
        rib_mask_small_resised = cv2.resize(rib_mask_small, (crop_w, crop_h))

        # วาง Mask ที่ปรับขนาดแล้ว ลงในพื้นที่ว่าง ณ ตำแหน่ง Offset (x1, y1)
        full_rib_mask[y1:y2, x1:x2] = (rib_mask_small_resised > 0.5).astype(np.uint8) * 255


    # --- การแสดงผล (Overlay Visualization) ---
    # ดึง Lung Mask (ปรับขนาดให้เท่าภาพต้นฉบับ)
    lung_mask = results_lung.masks.data[0].cpu().numpy()
    lung_mask_full = cv2.resize(lung_mask, (w_orig, h_orig))
    full_lung_mask_uint8 = (lung_mask_full > 0.5).astype(np.uint8) * 255

    # สร้างภาพสีสำหรับการซ้อน
    overlay = img_orig.copy()

    # ระบายสีปอด: สีน้ำเงิน (Blue)
    overlay[full_lung_mask_uint8 == 255] = [255, 0, 0] 

    # ระบายสี Rib 9: สีแดง (Red) 
    # (ต้องวางหลังจากปอด เพื่อให้ซ้อนทับข้างบน)
    overlay[full_rib_mask == 255] = [0, 0, 255]

    # ปรับความโปร่งใส (Transparency) 40%
    alpha = 0.4
    output_img = cv2.addWeighted(overlay, alpha, img_orig, 1 - alpha, 0)

    # บันทึกหรือแสดงผล
    cv2.imwrite('output_overlay.jpg', output_img)
    print("เซฟภาพ output_overlay.jpg เรียบร้อยแล้ว")

else:
    print("ไม่พบปอดในภาพ")