# -*- coding: utf-8 -*-
"""Generate setup_platforms.bat (CRLF, pure ASCII) for a real Flutter machine.

This bat is NOT for the sandbox (flutter CLI hard-hangs there). It is for the
user's own Windows machine where `flutter` works normally. It auto-detects the
Flutter SDK from PATH, then regenerates authoritative platform directories
(ios/linux/macos) and refreshes android/windows/web via `flutter create .`.
"""
import os

BAT = r"""@echo off
REM ============================================================
REM setup_platforms.bat
REM Run on a real Windows machine where the Flutter CLI works
REM (NOT the build sandbox, where flutter CLI hard-hangs).
REM
REM What it does:
REM   1. Auto-detect FLUTTER_ROOT from the `flutter` on PATH.
REM   2. cd into the flutter_app project folder.
REM   3. Run `flutter create . --no-pub` to (re)generate authoritative
REM      platform dirs: ios/ linux/ macos/ (and refresh android/ windows/ web/).
REM   4. Fetch Dart/Flutter deps with `flutter pub get`.
REM
REM NOTE: `flutter create .` preserves your lib/, pubspec.yaml, and
REM assets. It only adds/updates platform folders and config files.
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
    ECHO         Install Flutter, or edit this bat to set FLUTTER_ROOT manually.
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
ECHO === Regenerating platform directories (ios/linux/macos + refresh others) ===
CALL "%FLUTTER_ROOT%\bin\flutter" create . --no-pub
IF %ERRORLEVEL% NEQ 0 (
    ECHO [ERROR] flutter create failed.
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

ECHO.
ECHO === Done. You can now build, e.g.: ===
ECHO   "%FLUTTER_ROOT%\bin\flutter" build windows
ECHO   "%FLUTTER_ROOT%\bin\flutter" build apk
ECHO   "%FLUTTER_ROOT%\bin\flutter" run
POPD
PAUSE
"""

out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "setup_platforms.bat")
with open(out_path, "wb") as f:
    f.write(BAT.replace("\n", "\r\n").encode("ascii"))

# sanity checks
with open(out_path, "rb") as f:
    data = f.read()
assert b"\r\n" in data, "CRLF missing"
assert b"\n" not in data.replace(b"\r\n", b""), "stray LF found"
try:
    data.decode("ascii")
    ascii_ok = True
except UnicodeDecodeError:
    ascii_ok = False
print("wrote", out_path)
print("bytes:", len(data), "ascii-only:", ascii_ok)
