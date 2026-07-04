# Rib 9 Overlap Lung Scanner

AI-powered Flutter app for analyzing Rib 9 overlap with the lung region in chest X-ray images using YOLO segmentation.

---

## Project Structure

```
rib9-overlap-lung-na-krub-master/
├── api.py                 ← FastAPI backend (NEW)
├── start_server.bat       ← Easy server startup (NEW)
├── app.py                 ← Original Streamlit app (unchanged)
├── lung.pt                ← YOLO lung segmentation model
├── best.pt                ← YOLO rib 9 segmentation model
└── flutter_app/           ← Flutter mobile app (NEW)
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

1. Download Flutter SDK from https://flutter.dev/docs/get-started/install/windows
2. Extract to `C:\src\flutter`
3. Add `C:\src\flutter\bin` to your system PATH
4. Run `flutter doctor` to verify installation

### Step 2: Start the FastAPI Backend

The Flutter app requires the Python backend to be running.

```batch
# Option A: Use the startup script (recommended)
start_server.bat

# Option B: Manual
.venv\Scripts\uvicorn api:app --host 0.0.0.0 --port 8000 --reload
```

The server will start at `http://localhost:8000`

### Step 3: Run the Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

---

## How It Works

1. **Upload** a chest X-ray image from gallery or camera
2. **Run Analysis** — the app sends the image to the FastAPI backend
3. The backend runs **two YOLO models**:
   - `lung.pt` → detects and segments the lung
   - `best.pt` → detects Rib 9 within the cropped lung area
4. **Overlap** between lung and Rib 9 is calculated
5. Results are displayed with:
   - Side-by-side original vs. annotated image
   - Circular overlap score indicator
   - Metric cards (Lung Area, Rib 9 Area, Overlap Area)
   - Color-coded interpretation

## Color Legend

| Color | Meaning |
|-------|---------|
| 🔵 Blue | Lung Region |
| 🔴 Red | Rib 9 |
| 🟣 Magenta | Overlap Area |

---

## Server URL Configuration

In the Flutter app, tap the ⚙️ settings icon to change the server URL:

| Device | URL |
|--------|-----|
| Android Emulator | `http://10.0.2.2:8000` |
| Physical Device | `http://YOUR_PC_LAN_IP:8000` |
| iOS Simulator / Desktop | `http://localhost:8000` |

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Check server + model status |
| POST | `/analyze` | Analyze uploaded X-ray image |
