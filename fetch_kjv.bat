@echo off
REM fetch_kjv.bat - download full KJV + CUV into app_data.json (run on your PC)
python3 fetch_kjv.py
if %ERRORLEVEL% NEQ 0 (
  echo KJV_FETCH_FAILED
  pause
  exit /b 1
)
python3 fetch_cuv.py
if %ERRORLEVEL% NEQ 0 (
  echo CUV_FETCH_FAILED (KJV still OK)
)
echo DONE: app_data.json updated (KJV + CUV)
pause
