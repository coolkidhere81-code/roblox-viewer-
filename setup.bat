@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Roblox Viewer - setup

rem This file lives in <project>\setup; the app, .venv and cloudflared.exe
rem belong in <project>. Resolve that folder regardless of where it is.
set "HERE=%~dp0"
for %%I in ("%HERE%..") do set "ROOT=%%~fI"
cd /d "%ROOT%"

set "VENV=%ROOT%\.venv"
set "PY=%VENV%\Scripts\python.exe"

echo.
echo  ============================================
echo    Roblox Viewer - first-time setup
echo  ============================================
echo.
echo  Project folder: %ROOT%
echo  This creates a private Python environment in .venv
echo  and installs the packages the viewer needs.
echo.

rem ---------------------------------------------------------------- 1. Python
set "BASE="

where py >nul 2>&1
if not errorlevel 1 (
  py -3 -c "import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)" >nul 2>&1
  if not errorlevel 1 set "BASE=py -3"
)

if not defined BASE (
  where python >nul 2>&1
  if not errorlevel 1 (
    python -c "import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)" >nul 2>&1
    if not errorlevel 1 set "BASE=python"
  )
)

if not defined BASE goto :nopython

rem ----------------------------------------------------------------- 2. venv
if not exist "%PY%" (
  echo  Creating .venv ...
  %BASE% -m venv "%VENV%"
  if errorlevel 1 goto :venvfail
)

echo  Updating pip ...
"%PY%" -m pip install --disable-pip-version-check --quiet --upgrade pip
if errorlevel 1 echo  (pip update skipped - continuing)

echo.
echo  Installing packages (needs internet, first run only)...
echo.
"%PY%" -m pip install --disable-pip-version-check -r "%HERE%requirements.txt"
if errorlevel 1 (
  echo.
  echo  Some optional packages did not install. Retrying with the essentials...
  echo.
  "%PY%" -m pip install --disable-pip-version-check pillow pywin32 numpy mss
  if errorlevel 1 goto :pipfail
)

rem windows-capture must be new enough to capture a single window
"%PY%" -c "import inspect, windows_capture as w; assert 'window_hwnd' in inspect.signature(w.WindowsCapture.__init__).parameters" >nul 2>&1
if errorlevel 1 (
  echo.
  echo  Updating windows-capture for per-window capture...
  "%PY%" -m pip install --disable-pip-version-check --upgrade windows-capture
  if errorlevel 1 echo  (per-window capture unavailable - the viewer will use screen capture)
)

rem PyAV is optional: it enables the much smaller H.264 video stream
"%PY%" -c "import av" >nul 2>&1
if errorlevel 1 (
  echo.
  echo  Installing the optional H.264 encoder...
  "%PY%" -m pip install --disable-pip-version-check av
  if errorlevel 1 echo  (H.264 unavailable - the viewer will use JPEG instead)
)

rem ------------------------------------------------------------ 3. cloudflared
echo.
if exist "%ROOT%\cloudflared.exe" goto :tunnel_ready
where cloudflared >nul 2>&1
if not errorlevel 1 goto :tunnel_ready

echo  Optional: watch from mobile data (outside your Wi-Fi).
echo  That uses Cloudflare Tunnel, a free tool from Cloudflare that
echo  runs a temporary HTTPS link for you. No account is needed.
echo.
choice /c YN /n /m " Download cloudflared.exe (about 35 MB) now? [Y/N] "
if errorlevel 2 goto :tunnel_skip
if errorlevel 1 goto :tunnel_get

:tunnel_get
echo.
echo  Downloading cloudflared.exe ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile '%ROOT%\cloudflared.exe' } catch { exit 1 }"
if errorlevel 1 (
  echo  Download failed. You can install it later with:
  echo      winget install Cloudflare.cloudflared
  del /q "%ROOT%\cloudflared.exe" >nul 2>&1
) else (
  echo  cloudflared.exe is ready.
)
goto :tunnel_skip

:tunnel_skip
echo.
echo  Optional: a permanent link that never changes.
echo  Install Tailscale from https://tailscale.com/download
echo  then run start-tailscale.bat.

:tunnel_ready
echo.
echo  ============================================
echo    Setup complete. Double-click start.bat
echo    to run the viewer.
echo  ============================================
echo.
exit /b 0

rem ------------------------------------------------------------------ errors
:nopython
echo.
echo  Python 3.10 or newer was not found.
echo.
where winget >nul 2>&1
if errorlevel 1 goto :nopython_manual
choice /c YN /n /m " Install Python 3.12 automatically with winget now? [Y/N] "
if errorlevel 2 goto :nopython_manual
echo.
echo  Installing Python 3.12 with winget...
winget install --id Python.Python.3.12 -e --scope user --accept-package-agreements --accept-source-agreements
if errorlevel 1 goto :nopython_manual
echo.
echo  Python is installed. Close this window, then run setup\setup.bat again.
echo  (A new window is needed so Windows picks up the updated PATH.)
echo.
pause
exit /b 1

:nopython_manual
echo.
echo  Install it in one of these ways:
echo    1. Open PowerShell and run:  winget install Python.Python.3.12
echo    2. Or download it from:      https://www.python.org/downloads/windows/
echo.
echo  During the installer, tick "Add python.exe to PATH".
echo  Then open a NEW window and run setup\setup.bat again.
echo.
pause
exit /b 1

:venvfail
echo.
echo  Could not create the .venv folder.
echo  Check that this folder is writable (not inside Program Files)
echo  and that your antivirus is not blocking Python.
echo.
pause
exit /b 1

:pipfail
echo.
echo  The Python packages could not be installed.
echo  Check your internet connection, then run setup\setup.bat again.
echo  If you use a proxy, set HTTPS_PROXY before running setup.
echo.
pause
exit /b 1
