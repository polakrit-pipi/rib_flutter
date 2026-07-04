import streamlit as st
import cv2
import numpy as np
from ultralytics import YOLO
from PIL import Image

# ตั้งค่าหน้าเว็บ
st.set_page_config(page_title="Lung & Rib 9 Segmentation", layout="wide")
st.title("Lung & Rib 9 Segmentation Analysis")

# Cache โมเดลเพื่อไม่ให้โหลดใหม่ทุกครั้งที่กดปุ่ม
@st.cache_resource
def load_models():
    model_lung = YOLO('lung.pt')
    model_rib = YOLO('best.pt')
    return model_lung, model_rib

try:
    model_lung, model_rib = load_models()
    st.success("Models loaded successfully!")
except Exception as e:
    st.error(f"Error loading models: {e}")

# ส่วนอัปโหลดไฟล์
uploaded_file = st.file_uploader("Upload Chest X-ray Image", type=['jpg', 'jpeg', 'png'])

if uploaded_file is not None:
    # แปลงไฟล์ที่อัปโหลดเป็น OpenCV format
    file_bytes = np.asarray(bytearray(uploaded_file.read()), dtype=np.uint8)
    img_orig = cv2.imdecode(file_bytes, 1)
    img_display = cv2.cvtColor(img_orig, cv2.COLOR_BGR2RGB)
    h_orig, w_orig = img_orig.shape[:2]

    col1, col2 = st.columns(2)
    with col1:
        st.image(img_display, caption="Original Image", use_container_width=True)

    if st.button("Run Analysis"):
        with st.spinner('Processing...'):
            # --- Stage 1: Lung ---
            res_lung = model_lung(img_orig)[0]
            
            if res_lung.masks is not None:
                # สร้าง Mask ปอด
                lung_mask = res_lung.masks.data[0].cpu().numpy()
                lung_mask_full = (cv2.resize(lung_mask, (w_orig, h_orig)) > 0.5).astype(np.uint8)
                
                # หา Bounding Box เพื่อ Crop
                box = res_lung.boxes.xyxy[0].cpu().numpy().astype(int)
                x1, y1, x2, y2 = box
                img_crop = img_orig[y1:y2, x1:x2]

                # --- Stage 2: Rib 9 ---
                res_rib = model_rib(img_crop)[0]
                full_rib_mask = np.zeros((h_orig, w_orig), dtype=np.uint8)
                
                if res_rib.masks is not None:
                    rib_small = res_rib.masks.data[0].cpu().numpy()
                    rib_resized = cv2.resize(rib_small, (x2-x1, y2-y1))
                    full_rib_mask[y1:y2, x1:x2] = (rib_resized > 0.5).astype(np.uint8)

                # --- Calculation Logic ---
                # หาพื้นที่ทับซ้อน (Overlap)
                overlap_mask = (lung_mask_full == 1) & (full_rib_mask == 1)
                
                area_lung = np.sum(lung_mask_full)
                area_rib = np.sum(full_rib_mask)
                area_overlap = np.sum(overlap_mask)
                
                # คำนวณเปอร์เซ็นต์
                # 1. ซี่โครงอยู่ในปอดกี่ % (หาตำแหน่งที่ทับซ้อนเทียบกับขนาดซี่โครงทั้งหมด)
                perc_rib_in_lung = (area_overlap / area_rib * 100) if area_rib > 0 else 0
                
                # --- Visualization ---
                overlay = img_orig.copy()
                overlay[lung_mask_full == 1] = [255, 0, 0]   # Blue Lung
                overlay[full_rib_mask == 1] = [0, 0, 255]    # Red Rib
                overlay[overlap_mask == 1] = [255, 0, 255]   # Magenta Overlap
                
                output_img = cv2.addWeighted(overlay, 0.4, img_orig, 0.6, 0)
                output_img = cv2.cvtColor(output_img, cv2.COLOR_BGR2RGB)

                with col2:
                    st.image(output_img, caption="Analysis Result", use_container_width=True)
                
                # --- Display Metrics ---
                st.subheader("Analysis Metrics")
                m1, m2, m3 = st.columns(3)
                m1.metric("Lung Area", f"{area_lung:,} px")
                m2.metric("Rib 9 Area", f"{area_rib:,} px")
                m3.metric("Overlap Area", f"{area_overlap:,} px")
                
                st.info(f"**Rib 9 Overlap Score:** มีพื้นที่ซี่โครงที่ 9 อยู่ในเขตปอดทั้งหมด **{perc_rib_in_lung:.2f}%**")
                
            else:
                st.error("Could not detect Lung in this image.")

