# Rib 9 Overlap Lung Scanner

AI-powered Flutter application for evaluating inhalation level from chest X-ray images by analyzing the overlap between the 9th rib and the lung region using YOLO segmentation.

---

## Project Information

### ชื่อโครงการภาษาไทย

**การพัฒนาระบบประเมินระดับการหายใจเข้าจากภาพถ่ายรังสีทรวงอก**

### Project Title in English

**Development of a System for Inhalation Level Estimation Using Chest X-ray Images**

### ผู้พัฒนาโครงการ

- นางสาวณัฐญา จิระธนาไพบูลย์ — หัวหน้าโครงการ
- นายพลกฤต กระจายศรี — ผู้ร่วมโครงการ
- นายพงศ์พล สมพงษ์ชัยกุล — ผู้ร่วมโครงการ

### อาจารย์ที่ปรึกษา

- ศ. ดร. วรพันธ์ คู่สกุลนิรันดร์

### สถาบัน

- **[กรุณาระบุชื่อสถาบัน]**

---

## Project Structure

```text
rib9-overlap-lung-na-krub-master/
├── api.py                 ← FastAPI backend
├── start_server.bat       ← Easy server startup
├── app.py                 ← Original Streamlit application
├── lung.pt                ← YOLO lung segmentation model
├── best.pt                ← YOLO Rib 9 segmentation model
└── flutter_app/           ← Flutter application
    ├── lib/
    │   ├── main.dart
    │   ├── screens/
    │   │   ├── home_screen.dart
    │   │   └── result_screen.dart
    │   ├── widgets/
    │   │   └── metric_card.dart
    │   └── services/
    │       └── api_service.dart
    └── pubspec.yaml
```

---

## Setup Instructions

### Step 1: Install Flutter SDK

1. Download the Flutter SDK from:
   `https://flutter.dev/docs/get-started/install/windows`
2. Extract the SDK to `C:\src\flutter`
3. Add `C:\src\flutter\bin` to the system `PATH`
4. Run the following command to verify the installation:

```bash
flutter doctor
```

### Step 2: Start the FastAPI Backend

The Flutter application requires the Python backend to be running.

```batch
:: Option A: Use the startup script
start_server.bat

:: Option B: Start the server manually
.venv\Scripts\uvicorn api:app --host 0.0.0.0 --port 8000 --reload
```

The server will start at:

```text
http://localhost:8000
```

### Step 3: Run the Flutter Application

```bash
cd flutter_app
flutter pub get
flutter run
```

---

## How It Works

1. Upload a chest X-ray image from the gallery or camera.
2. Select **Run Analysis** to send the image to the FastAPI backend.
3. The backend processes the image using two YOLO segmentation models:
   - `lung.pt` detects and segments the lung region.
   - `best.pt` detects and segments the 9th rib within the relevant image region.
4. The system calculates the overlap between the lung region and the 9th rib.
5. The application displays:
   - The original and annotated images
   - The overlap score
   - Lung area
   - Rib 9 area
   - Overlap area
   - A color-coded interpretation of the result

---

## Color Legend

| Color | Meaning |
|---|---|
| 🔵 Blue | Lung region |
| 🔴 Red | Rib 9 |
| 🟣 Magenta | Overlap area |

---

## Server URL Configuration

In the Flutter application, select the ⚙️ settings icon to change the server URL.

| Device | URL |
|---|---|
| Android Emulator | `http://10.0.2.2:8000` |
| Physical Device | `http://YOUR_PC_LAN_IP:8000` |
| iOS Simulator / Desktop | `http://localhost:8000` |

---

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Checks the server and model status |
| `POST` | `/analyze` | Analyzes an uploaded chest X-ray image |

---

## ขอบเขตการใช้งาน

ซอฟต์แวร์นี้พัฒนาขึ้นเพื่อช่วยประเมินระดับความเพียงพอของการหายใจเข้าจากภาพถ่ายรังสีทรวงอก โดยวิเคราะห์ตำแหน่งของกระดูกซี่โครงซี่ที่ 9 เทียบกับบริเวณปอด

ระบบรองรับภาพถ่ายรังสีทรวงอกในท่า `AP` และ `PA` และมีวัตถุประสงค์เพื่อใช้เป็นเครื่องมือช่วยประเมินเบื้องต้นเท่านั้น ไม่ควรนำผลลัพธ์จากระบบไปใช้แทนการวินิจฉัยหรือการพิจารณาของแพทย์หรือบุคลากรทางการแพทย์

---

## ข้อตกลงในการใช้ซอฟต์แวร์

ซอฟต์แวร์นี้เป็นผลงานที่พัฒนาขึ้นโดย นางสาวณัฐญา จิระธนาไพบูลย์ นายพลกฤต กระจายศรี และนายพงศ์พล สมพงษ์ชัยกุล จาก **มหาวิทยาลัยมหิดล** ภายใต้การดูแลของ ศ. ดร. วรพันธ์ คู่สกุลนิรันดร์ ภายใต้โครงการ **การพัฒนาระบบประเมินระดับการหายใจเข้าจากภาพถ่ายรังสีทรวงอก** ซึ่งสนับสนุนโดยสำนักงานพัฒนาวิทยาศาสตร์และเทคโนโลยีแห่งชาติ โดยมีวัตถุประสงค์เพื่อส่งเสริมให้นักเรียนและนักศึกษาได้เรียนรู้และฝึกทักษะในการพัฒนาซอฟต์แวร์

ลิขสิทธิ์ของซอฟต์แวร์นี้เป็นของผู้พัฒนา โดยผู้พัฒนาได้อนุญาตให้สำนักงานพัฒนาวิทยาศาสตร์และเทคโนโลยีแห่งชาติเผยแพร่ซอฟต์แวร์นี้ตามต้นฉบับ โดยไม่มีการแก้ไขหรือดัดแปลงใด ๆ ให้แก่บุคคลทั่วไป เพื่อใช้ประโยชน์ส่วนบุคคลหรือประโยชน์ทางการศึกษาที่ไม่มีวัตถุประสงค์ในเชิงพาณิชย์ โดยไม่คิดค่าตอบแทนการใช้ซอฟต์แวร์

สำนักงานพัฒนาวิทยาศาสตร์และเทคโนโลยีแห่งชาติจึงไม่มีหน้าที่ในการดูแล บำรุงรักษา จัดการอบรมการใช้งาน หรือพัฒนาประสิทธิภาพของซอฟต์แวร์ รวมทั้งไม่รับรองความถูกต้องหรือประสิทธิภาพการทำงานของซอฟต์แวร์ และไม่รับประกันความเสียหายใด ๆ ที่เกิดขึ้นจากการใช้ซอฟต์แวร์นี้

---

## Disclaimer

This software is intended for educational, research, and preliminary assessment purposes only. It is not a medical device and must not be used as a substitute for diagnosis, clinical judgment, or professional medical advice.