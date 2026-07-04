@echo off
echo =====================================================
echo  Rib 9 Overlap Lung Scanner - Backend Startup
echo =====================================================
echo.

set PYTHON=C:\Users\obey\miniconda3\envs\nsc\python.exe

if not exist "%PYTHON%" (
    echo [ERROR] Python not found at: %PYTHON%
    echo Please check your miniconda installation.
    pause
    exit /b 1
)

echo [INFO] Using Python: %PYTHON%
echo [INFO] Starting FastAPI backend on http://0.0.0.0:8000
echo [INFO] Flutter app should connect to:
echo        - Chrome (web):     http://localhost:8000
echo        - Android emulator: http://10.0.2.2:8000
echo        - Physical device:  http://YOUR_LAN_IP:8000
echo.
echo [INFO] Press Ctrl+C to stop the server.
echo.

%PYTHON% -m uvicorn api:app --host 0.0.0.0 --port 8000 --reload

pause

