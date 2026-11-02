@echo off
REM One-click runner for _egw_fetch.py (EGW writings fetch)
cd /d %~dp0
set PY=C:\Users\xinwu\.workbuddy\binaries\python\versions\3.13.12\python.exe

echo ============================================================
echo  EGW writings fetch - step 1: paste your API token
echo  (get it free at https://cpanel.egwwritings.org , scope=search)
echo ============================================================
set /p TOKEN=EGW_API_TOKEN: 
if "%TOKEN%"=="" goto end

set EGW_API_TOKEN=%TOKEN%

echo.
echo ============================================================
echo  Step 2: DRY-RUN probe (checks API, writes nothing)
echo ============================================================
"%PY%" _egw_fetch.py --dry-run

echo.
echo If the output above looks fine (no big error blocks),
echo press any key to run the REAL fetch and write the json file...
pause >nul

"%PY%" _egw_fetch.py

echo.
echo DONE. Result file: flutter_app\assets\web\egw_verses.json
echo Send that file back to WorkBuddy to publish.
:end
pause
