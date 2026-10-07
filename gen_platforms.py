#!/usr/bin/env python3
# gen_platforms.py
# 手动补齐 Flutter 平台目录（本沙箱 flutter create 包装层会挂起，无法自动生成）。
# 生成 android/ 标准模板（Flutter 3.22：Kotlin / Gradle 8.6 / AGP 8.1.0 / compileSdk 34），
# 从 Flutter SDK 缓存复制 gradle-wrapper.jar，并生成占位启动图标（PNG）。
# web/ 由 main 流程单独生成；windows/ios/linux/macos 需在对应平台用 flutter create 生成。

import os
import struct
import zlib
import shutil

ROOT = os.path.dirname(os.path.abspath(__file__))
ANDROID = os.path.join(ROOT, "flutter_app", "android")
FLUTTER_ROOT = os.environ.get(
    "FLUTTER_ROOT", r"C:/Users/xinwu/.workbuddy/binaries/flutter/flutter"
)
GRADLE_JAR = os.path.join(
    FLUTTER_ROOT, "bin", "cache", "artifacts", "gradle_wrapper",
    "gradle", "wrapper", "gradle-wrapper.jar"
)

NS = "com.example.faith_compare_app"  # 由 pubspec name (faith_compare_app) 派生
APP_LABEL = "真理对照"

# ---------------------------------------------------------------------------
# 占位 PNG 生成（仅标准库，避免二进制资源依赖）
# ---------------------------------------------------------------------------
def make_png(path, size, rgba):
    w = h = size
    raw = b"".join(b"\x00" + bytes(rgba) * w for _ in range(h))

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    idat = zlib.compress(raw)
    with open(path, "wb") as f:
        f.write(sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b""))


# ---------------------------------------------------------------------------
# 文件内容表
# ---------------------------------------------------------------------------
FILES = {}

FILES["settings.gradle"] = r"""pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        file("local.properties").withInputStream { properties.load(it) }
        def flutterSdkPath = properties.getProperty("flutter.sdk")
        if (flutterSdkPath == null) {
            throw new GradleException("flutter.sdk not set in local.properties")
        }
        return flutterSdkPath
    }
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.1.0" apply false
    id "org.jetbrains.kotlin.android" version "1.9.22" apply false
}

include ":app"
"""

FILES["build.gradle"] = r"""allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = "../build"
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
"""

FILES["gradle/wrapper/gradle-wrapper.properties"] = r"""distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.6-all.zip
"""

FILES["app/build.gradle"] = (
    r"""plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

android {
    namespace = "%NS%"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId = "%NS%"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInteger()
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.debug
        }
    }
}

flutter {
    source = "../.."
}

dependencies {}
"""
    .replace("%NS%", NS)
)

FILES["app/src/main/AndroidManifest.xml"] = (
    r"""<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="%LABEL%"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <uses-permission android:name="android.permission.INTERNET"/>
</manifest>
"""
    .replace("%LABEL%", APP_LABEL)
)

FILES["app/src/main/res/values/styles.xml"] = r"""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
"""

FILES["app/src/main/res/values/strings.xml"] = r"""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="applicationName">android.app.Application</string>
</resources>
"""

FILES["app/src/main/res/drawable/launch_background.xml"] = r"""<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />
</layer-list>
"""

FILES["app/src/main/kotlin/com/example/faith_compare_app/MainActivity.kt"] = r"""package com.example.faith_compare_app

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
"""

FILES[".gitignore"] = r"""gradle-wrapper.jar
/.gradle
/captures
/gradlew
/gradlew.bat
/local.properties
GeneratedPluginRegistrant.java
"""

GRADLEW = r"""#!/bin/sh

#
# Copyright © 2015-2021 the original authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

APP_HOME=$( cd "${APP_HOME:-./}" && pwd -P ) || exit
CLASSPATH=$APP_HOME/gradle/wrapper/gradle-wrapper.jar
DEFAULT_JVM_OPTS='"-Xmx64m" "-Xms64m"'

warn () { echo "$*" >&2; }
die () { echo; echo "$*"; echo; exit 1; } >&2

if [ -n "$JAVA_HOME" ]; then
    JAVACMD=$JAVA_HOME/bin/java
    [ -x "$JAVACMD" ] || die "ERROR: JAVA_HOME is set to an invalid directory: $JAVA_HOME"
else
    JAVACMD=java
    command -v java >/dev/null 2>&1 || die "ERROR: JAVA_HOME is not set and no 'java' command found in PATH."
fi

set -- "-Dorg.gradle.appname=${0##*/}" -classpath "$CLASSPATH" org.gradle.wrapper.GradleWrapperMain "$@"
exec "$JAVACMD" "$@"
"""
FILES["gradlew"] = GRADLEW

GRADLEW_BAT = r"""@rem
@rem Copyright 2015 the original author or authors.
@rem Licensed under the Apache License, Version 2.0 (the "License");
@rem you may not use this file except in compliance with the License.
@rem You may obtain a copy of the License at
@rem
@rem      https://www.apache.org/licenses/LICENSE-2.0
@rem
@rem Unless required by applicable law or agreed to in writing, software
@rem distributed under the License is distributed on an "AS IS" BASIS,
@rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
@rem See the License for the specific language governing permissions and
@rem limitations under the License.

@if "%DEBUG%"=="" @echo off
@rem ##########################################################################
@rem
@rem  Gradle startup script for Windows
@rem
@rem ##########################################################################

@if "%OS%"=="Windows_NT" setlocal

set DIRNAME=%~dp0
if "%DIRNAME%"=="" set DIRNAME=.
set APP_BASE_NAME=%~n0
set APP_HOME=%DIRNAME%

for %%i in ("%APP_HOME%") do set APP_HOME=%%~fi

set DEFAULT_JVM_OPTS="-Xmx64m" "-Xms64m"

if defined JAVA_HOME goto findJavaFromJavaHome

set JAVA_EXE=java.exe
%JAVA_EXE% -version >NUL 2>&1
if %ERRORLEVEL% equ 0 goto execute

echo ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.
goto fail

:findJavaFromJavaHome
set JAVA_HOME=%JAVA_HOME:"=%
set JAVA_EXE=%JAVA_HOME%/bin/java.exe
if exist "%JAVA_EXE%" goto execute

echo ERROR: JAVA_HOME is set to an invalid directory: %JAVA_HOME%
goto fail

:execute
set CLASSPATH=%APP_HOME%\gradle\wrapper\gradle-wrapper.jar
"%JAVA_EXE%" %DEFAULT_JVM_OPTS% %JAVA_OPTS% %GRADLE_OPTS% "-Dorg.gradle.appname=%APP_BASE_NAME%" -classpath "%CLASSPATH%" org.gradle.wrapper.GradleWrapperMain %*

:end
if %ERRORLEVEL% equ 0 goto mainEnd

:fail
set EXIT_CODE=%ERRORLEVEL%
if %EXIT_CODE% equ 0 set EXIT_CODE=1
if not ""=="%GRADLE_EXIT_CONSOLE%" exit %EXIT_CODE%
exit /b %EXIT_CODE%

:mainEnd
if "%OS%"=="Windows_NT" endlocal
"""
FILES["gradlew.bat"] = GRADLEW_BAT


# ---------------------------------------------------------------------------
# 写入文件
# ---------------------------------------------------------------------------
def main():
    for rel, content in FILES.items():
        full = os.path.join(ANDROID, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8") as f:
            f.write(content)
        if rel in ("gradlew",):
            os.chmod(full, 0o755)

    # gradle-wrapper.jar（从 SDK 缓存复制；这是二进制，无法用纯文本生成）
    if os.path.exists(GRADLE_JAR):
        dst = os.path.join(ANDROID, "gradle", "wrapper", "gradle-wrapper.jar")
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(GRADLE_JAR, dst)
        print("copied gradle-wrapper.jar")
    else:
        print("WARN: gradle-wrapper.jar not found at", GRADLE_JAR)

    # 占位启动图标（各密度）
    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for d, size in densities.items():
        ddir = os.path.join(ANDROID, "app", "src", "main", "res", "mipmap-" + d)
        os.makedirs(ddir, exist_ok=True)
        make_png(os.path.join(ddir, "ic_launcher.png"), size, (63, 81, 181, 255))
    print("android launcher icons written:", list(densities))

    print("android/ scaffold done at", ANDROID)


if __name__ == "__main__":
    main()
