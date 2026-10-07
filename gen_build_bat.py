# -*- coding: utf-8 -*-
"""Generate build_app.bat (CRLF, pure ASCII) for a real Flutter machine.

One-click build helper for the faith_compare_app. Auto-detects FLUTTER_ROOT
from PATH, fetches deps, then builds the chosen target:
  build_app.bat            -> interactive menu (windows/apk/web/all)
  build_app.bat windows    -> Windows release exe
  build_app.bat apk        -> Android APK
  build_app.bat web        -> Web
  build_app.bat all        -> windows + apk + web
"""
import os

BAT = r"""@echo off
REM ============================================================
REM build_app.bat  -  One-click build for the faith_compare_app
REM Run on a REAL Windows machine where the Flutter CLI works.
REM (The build sandbox hard-hangs; this is for your local PC.)
REM
REM Usage:
REM   build_app.bat            -> interactive menu
REM   build_app.bat windows    -> Windows release exe
REM   build_app.bat apk        -> Android APK
REM   build_app.bat web        -> Web build
REM   build_app.bat all        -> windows + apk + web
REM
REM Prereqs (once, on your PC):
REM   - Flutter SDK on PATH (or set FLUTTER_ROOT manually below)
REM   - Android SDK installed + `flutter doctor --android-licenses` accepted
REM   - Already ran setup_platforms.bat once to create platform dirs
REM ============================================================
SETLOCAL ENABLEEXTENSIONS

REM --- locate project dir (folder holding this bat -> flutter_app) ---
SET "PROJECT_DIR=%~dp0flutter_app"
IF NOT EXIST "%PROJECT_DIR%\" SET "PROJECT_DIR=%~dp0"

REM --- locate Flutter SDK from PATH ---
SET "FLUTTER_EXE="
FOR /F "delims=" %%F IN ('where flutter 2^>nul') DO (
    SET "FLUTTER_EXE=%%F"
    GOTO :found
)
:found
IF NOT DEFINED FLUTTER_EXE (
    ECHO [ERROR] flutter not found on PATH.
    ECHO         Install Flutter, or set FLUTTER_ROOT manually in this bat.
    PAUSE
    EXIT /B 1
)
REM FLUTTER_EXE looks like C:\...\flutter\bin\flutter
SET "FLUTTER_ROOT=%FLUTTER_EXE:\bin\flutter=%"
ECHO Using FLUTTER_ROOT=%FLUTTER_ROOT%

PUSHD "%PROJECT_DIR%"
IF NOT EXIST "pubspec.yaml" (
    ECHO [ERROR] pubspec.yaml not found in %PROJECT_DIR%
    POPD
    PAUSE
    EXIT /B 1
)

ECHO.
ECHO === Fetching dependencies ===
CALL "%FLUTTER_ROOT%\bin\flutter" pub get
IF %ERRORLEVEL% NEQ 0 (
    ECHO [ERROR] flutter pub get failed.
    POPD
    PAUSE
    EXIT /B 1
)

SET "TARGET=%~1"
IF "%TARGET%"=="" (
    ECHO.
    ECHO Select build target:
    ECHO   1) Windows  (release exe)
    ECHO   2) Android  (APK)
    ECHO   3) Web
    ECHO   4) All (windows + apk + web)
    ECHO   5) Exit
    SET /P CHOICE="Enter 1-5: "
    IF "%CHOICE%"=="1" SET "TARGET=windows"
    IF "%CHOICE%"=="2" SET "TARGET=apk"
    IF "%CHOICE%"=="3" SET "TARGET=web"
    IF "%CHOICE%"=="4" SET "TARGET=all"
    IF "%CHOICE%"=="5" GOTO :done
)

IF "%TARGET%"=="windows" ( CALL :build_windows || GOTO :done )
IF "%TARGET%"=="apk"     ( CALL :build_apk     || GOTO :done )
IF "%TARGET%"=="web"     ( CALL :build_web     || GOTO :done )
IF "%TARGET%"=="all" (
    CALL :build_windows || GOTO :done
    CALL :build_apk     || GOTO :done
    CALL :build_web     || GOTO :done
)
GOTO :done

:build_windows
ECHO.
ECHO === Building Windows release ===
CALL "%FLUTTER_ROOT%\bin\flutter" build windows --release
IF %ERRORLEVEL% NEQ 0 ( ECHO [ERROR] Windows build failed. & EXIT /B 1 )
ECHO Output: %PROJECT_DIR%build\windows\x64\runner\Release\
GOTO :eof

:build_apk
ECHO.
ECHO === Building Android APK ===
CALL "%FLUTTER_ROOT%\bin\flutter" build apk --release
IF %ERRORLEVEL% NEQ 0 ( ECHO [ERROR] APK build failed. & EXIT /B 1 )
ECHO Output: %PROJECT_DIR%build\app\outputs\flutter-apk\app-release.apk
GOTO :eof

:build_web
ECHO.
ECHO === Building Web ===
CALL "%FLUTTER_ROOT%\bin\flutter" build web --release
IF %ERRORLEVEL% NEQ 0 ( ECHO [ERROR] Web build failed. & EXIT /B 1 )
ECHO Output: %PROJECT_DIR%build\web\
GOTO :eof

:done
POPD
ECHO.
ECHO === All done. ===
PAUSE
"""

out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build_app.bat")
with open(out_path, "wb") as f:
    f.write(BAT.replace("\n", "\r\n").encode("ascii"))

with open(out_path, "rb") as f:
    data = f.read()
assert b"\r\n" in data
assert b"\n" not in data.replace(b"\r\n", b"")
data.decode("ascii")
print("wrote", out_path)
print("bytes:", len(data), "crlf_lines:", data.count(b"\r\n"), "lone_lf:", data.count(b"\n") - data.count(b"\r\n"), "ascii_ok: True")
