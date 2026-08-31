@echo off
rem ============================================================
rem  DeepTutor - local launcher (Windows)
rem  Starts the backend API server using the project venv.
rem  Run this from a double-click or from cmd.
rem ============================================================
setlocal enabledelayedexpansion

rem ---- cd to the repository root (directory containing this file) ----
cd /d "%~dp0"

rem ---- UTF-8 codepage so console output renders correctly ----
chcp 65001 >nul

rem ---- locate a suitable Python interpreter ----
set "PY_CMD="
where py >nul 2>nul && set "PY_CMD=py"
if not defined PY_CMD (
  where python >nul 2>nul && set "PY_CMD=python"
)
if not defined PY_CMD (
  echo [ERROR] No Python interpreter found on PATH ^(py or python^).
  echo         Please install Python 3.11+ and add it to PATH.
  pause
  exit /b 1
)

rem ---- create the venv if it does not exist yet ----
if not exist ".venv\Scripts\python.exe" (
  echo [INFO] Creating virtual environment in .venv ...
  "%PY_CMD%" -m venv .venv
  if errorlevel 1 (
    echo [ERROR] Failed to create virtual environment.
    pause
    exit /b 1
  )
)

rem ---- activate the venv ----
call ".venv\Scripts\activate.bat"
if errorlevel 1 (
  echo [ERROR] Failed to activate virtual environment.
  pause
  exit /b 1
)

rem ---- install dependencies only if they are missing (~first run) ----
if not exist ".venv\Lib\site-packages\deeptutor" (
  echo [INFO] Installing dependencies from requirements.txt ...
  python -m pip install --upgrade pip
  python -m pip install -r requirements.txt
  if errorlevel 1 (
    echo [ERROR] Dependency installation failed ^(exit code %errorlevel%^).
    pause
    exit /b 1
  )
)

rem ---- boot the backend API server ----
echo [INFO] Starting DeepTutor backend server ...
echo [INFO] Backend running on http://127.0.0.1:8001
start /B python -m deeptutor.api.run_server >NUL 2>&1
timeout /T 3 >NUL

rem ---- start the frontend development server ----
echo [INFO] Starting DeepTutor frontend development server ...
cd /d "web"
start "" npm run dev >NUL 2>&1
timeout /T 3 >NUL

echo.
echo [INFO] Both DeepTutor backend and frontend are starting...
echo [INFO] - Backend:   http://127.0.0.1:8001
echo [INFO] - Frontend:  http://127.0.0.1:3782
echo.
echo [INFO] Press Ctrl+C in either console to stop that process.
echo [INFO] Close both consoles to fully exit.
echo.

rem Keep the original console alive so the user sees the status
timeout /T 5 >NUL
exit /b 0
