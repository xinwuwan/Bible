@echo off
REM update_website.bat - push latest code to GitHub, auto rebuild website
REM v2: checks result, retries up to 3 times, no more fake success message
echo Pushing to GitHub...
set /a tries=0

:retry
set /a tries+=1
echo.
echo === Attempt %tries% of 3 ===
git push origin main
if not errorlevel 1 goto ok

echo.
echo Attempt %tries% failed (network to github.com is unstable).
if %tries% lss 3 (
    echo Waiting 10 seconds, then retrying...
    timeout /t 10 /nobreak >nul
    goto retry
)

echo.
echo ============================================
echo  FAILED after 3 attempts.
echo  The network route to github.com is blocked
echo  right now. Please try one of these:
echo   1. Use phone hotspot on the computer
echo   2. Try again in the morning (8-11 AM)
echo  Then double-click this file again.
echo ============================================
pause
exit /b 1

:ok
echo.
echo ============================================
echo  SUCCESS! Code pushed to GitHub.
echo  Auto build starts now (takes 5-10 min).
echo  Website: https://xinwuwan.github.io/Bible/
echo ============================================
pause
