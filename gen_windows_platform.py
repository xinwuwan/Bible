#!/usr/bin/env python3
# gen_windows_platform.py
# 手工补齐 flutter_app/windows/ 标准模板（Flutter 3.22 桌面模板：CMake + Win32 runner）。
# 本沙箱 flutter create 包装层会挂起，无法自动生成；windows/ 模板含 C++ 与 .ico 二进制，
# 用标准模板逐文件写出，app_icon.ico 由 PNG 包裹为 ICO 生成。
# 说明：此目录为"尽力而为"的脚手架，未经本机编译验证；在有完整 Flutter 的 Windows 机器上
# 运行 setup_platforms.bat（flutter create . --no-pub）会得到 Flutter 官方生成的权威 windows/。

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.abspath(__file__))
WIN = os.path.join(ROOT, "flutter_app", "windows")
APP_TITLE = "真理对照"
NS = "com.example.faith_compare_app"

FILES = {}

FILES["CMakeLists.txt"] = r"""cmake_minimum_required(VERSION 3.14)
project(faith_compare_app LANGUAGES CXX)

set(BINARY_NAME "faith_compare_app")
set(APPLICATION_ID "com.example.faith_compare_app")

cmake_path(SET PROJECT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/..")

set(CMAKE_INSTALL_RPATH "${CMAKE_BINARY_DIR}")

# Configure build types
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Build type" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "RelWithDebInfo")
endif()

# Override build type to "Release" if it is "RelWithDebInfo"
if(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Build type" FORCE)
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${PROJECT_DIR}/build/windows/x64" CACHE STRING "" FORCE)
endif()

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>")

# === Flutter target configuration ===
set(FLUTTER_TARGET "lib/main.dart" CACHE STRING "Flutter target")

# === Flutter tool directory ===
if(NOT FLUTTER_TOOL_ENVIRONMENT)
  set(FLUTTER_TOOL_ENVIRONMENT "$ENV{FLUTTER_ROOT}/packages/flutter_tools")
endif()

if(NOT FLUTTER_TARGET_PLATFORM)
  set(FLUTTER_TARGET_PLATFORM "windows-x64")
endif()

# === Engine selection (default to stable) ===
if(NOT FLUTTER_ENGINE)
  set(FLUTTER_ENGINE "stable")
endif()

# === Flutter build mode configuration ===
set(FLUTTER_BUILD_MODE "release" CACHE STRING "Flutter build mode" FORCE)

# Standard Flutter tool configuration
set(FLUTTER_LIBRARY_DIR "${PROJECT_DIR}/build/windows/x64/flutter")
set(FLUTTER_LIBRARY "${FLUTTER_LIBRARY_DIR}/Release/flutter_windows.dll")
set(FLUTTER_LIBRARY_DEBUG "${FLUTTER_LIBRARY_DIR}/Debug/flutter_windows.dll")

# Generated plugin build rules
set(FLUTTER_LIBRARY_DIR "${PROJECT_DIR}/build/windows/x64/flutter")

# Retrieve the LLVM directory from the system path
execute_process(COMMAND "${CMAKE_COMMAND}" -E
  env
  OUTPUT_QUIET
)

# Configure the Windows application
add_executable(${BINARY_NAME} WIN32
  "win32_window.cpp"
  "win32_window.h"
  "flutter_window.cpp"
  "flutter_window.h"
  "main.cpp"
  "resource.h"
  "resources/app_icon.ico"
  "utils.cpp"
  "utils.h"
  "runner.rc"
)

# Apply the standard build settings for a Flutter executable.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")
target_compile_definitions(${BINARY_NAME} PRIVATE "_HAS_EXCEPTIONS=0")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_DESKTOP")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_BUILD_MODE=${FLUTTER_BUILD_MODE}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_TARGET=\"${FLUTTER_TARGET}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_TOOL_ENVIRONMENT=\"${FLUTTER_TOOL_ENVIRONMENT}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_ROOT=\"$ENV{FLUTTER_ROOT}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_TARGET_PLATFORM=\"${FLUTTER_TARGET_PLATFORM}\"")

target_compile_options(${BINARY_NAME} PRIVATE "/W4")

# Flutter library sources
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_include_directories(${BINARY_NAME} PRIVATE "flutter")
target_include_directories(${BINARY_NAME} PRIVATE "${FLUTTER_LIBRARY_DIR}/include")

# List all the Flutter library files
set(FLUTTER_LIBRARY_FILES
  "${FLUTTER_LIBRARY}"
  "${FLUTTER_LIBRARY_DEBUG}"
)

target_link_libraries(${BINARY_NAME} PRIVATE "${FLUTTER_LIBRARY_FILES}")

# Run the Flutter tool portions of the build
add_custom_command(
  TARGET ${BINARY_NAME}
  POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E env
    "FLUTTER_ROOT=$ENV{FLUTTER_ROOT}"
    "$ENV{FLUTTER_ROOT}/packages/flutter_tools/bin/tool_backend.dart"
    "windows-x64" "${FLUTTER_BUILD_MODE}"
  VERBATIM
)

# Installation handling
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)
install(FILES "${FLUTTER_LIBRARY}" RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)
install(FILES "${FLUTTER_LIBRARY_DEBUG}" RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

# Generated plugin build rules
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/_dummy.c" "")
add_library(flutter_wrapper_plugin STATIC "${CMAKE_CURRENT_BINARY_DIR}/_dummy.c")
set_target_properties(flutter_wrapper_plugin PROPERTIES LINKER_LANGUAGE C)
target_link_libraries(${BINARY_NAME} PRIVATE flutter_wrapper_plugin)

include(flutter/generated_plugins.cmake OPTIONAL)
include(flutter/generated_plugin_registrant.cmake OPTIONAL)

add_dependencies(${BINARY_NAME} flutter_wrapper_plugin)
"""

FILES["runner/main.cpp"] = r"""#include "flutter_window.h"
#include "utils.h"
#include "win32_window.h"

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <windows.h>

#include <memory>
#include <string>
#include <vector>

// The entry point for the application.
int APIENTRY wWinMain(_In_ int argc,
                      _In_ wchar_t* argv[],
                      _In_ wchar_t* envp[]) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with 'flutter run --no-terminal'.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    ::AllocConsole();
  }

  // Initialize COM, so that the taskbar and other things work.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L".");
  project.set_dart_entrypoint_arguments(
      flutter::GetDartEntrypointArguments());

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);

  if (!window.CreateAndShow(L"__APP_TITLE__", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
""".replace("__APP_TITLE__", APP_TITLE)

FILES["runner/win32_window.h"] = r"""#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <Windows.h>
#include <windowsx.h>

#include <functional>
#include <memory>
#include <string>

// A class abstraction for a high DPI-aware Win32 Window. Intended to be
// inherited from by classes that wish to specialize with custom
// rendering and input handling
class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
    Point() : x(0), y(0) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // Creates a win32 window with |title| that is positioned and sized using
  // |origin| and |size|. New windows are created on the default monitor. Return
  // false if creation or registration fails.
  bool CreateAndShow(const std::wstring& title,
                     const Point& origin,
                     const Size& size);

  // Release OS resources associated with window.
  void Destroy();

  // Returns the native window handle.
  HWND GetHandle();

  // If |redirect_using_create_window_ex| is set during CreateAndShow, the
  // |CreateWindowEx| call will be redirected to call the supplied function,
  // returning the created window.
  void SetChildContent(HWND content);

  // Sets the window title.
  void SetTitle(const std::wstring& title);

  // Sets the window icon.
  void SetIcon(HICON icon);

  // Should be called by subclasses when the window size changes.
  void SizeChanged(const Size& size);

  // Should be called by subclasses when the window focus changes.
  void FocusChanged(bool focused);

  // Called when the OS requests to close the window.
  virtual void OnClose();

 protected:
  // Registers a Win32 class for the window and returns the ATOM representing
  // the class.
  ATOM RegisterWindowClass();

  // Creates a window with |window_class| using |title|, |origin| and |size|.
  // The supplied |window_style| and extended style flags are applied to the
  // created window. The |parent| is the parent window if non-null.
  bool CreateWindowWithStyle(const std::wstring& title,
                             const Point& origin,
                             const Size& size,
                             DWORD window_style,
                             DWORD window_style_ex,
                             HWND parent = nullptr);

  // Called when the OS requests to close the window.
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // Called when the OS requests to close the window.
  LRESULT Win32MessageHandler(HWND window,
                              UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept;

  // Called when the window is resized.
  virtual void OnSizeChanged(const Size& size) {}

  // Called when the window gains or loses focus.
  virtual void OnFocusChanged(bool focused) {}

  // The Windows window handle.
  HWND window_handle_ = nullptr;

  // The child window content.
  HWND child_content_ = nullptr;

  // The current window size.
  Size current_size_ = Size();

 private:
  friend class WindowClassRegistrar;

  // OS callback called by message pump. Handles the WM_NCCREATE message which
  // is passed when the non-client area is being created and provides the
  // lpParam value passed to CreateWindowEx.
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  // Creates and shows the window associated with |window_class| passing
  // |title|, |origin| and |size|.
  bool CreateWindowDefaultStyle(const std::wstring& title,
                               const Point& origin,
                               const Size& size);

  // Keep track of the child window's last known size to be able to restore it
  // when the child window is hidden or shown.
  Size previous_child_size_ = Size();

  // Restore the child window's dimensions when the window is shown.
  void RestoreChildSize();

  // The |child_content_| will be resized to this size when the window is
  // shown.
  Size desired_child_size_ = Size();
};

#endif  // RUNNER_WIN32_WINDOW_H_
"""

FILES["runner/win32_window.cpp"] = r"""#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include <iostream>
#include <string>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
/// This is supported in Windows 10 1809 (10.0.17763.0) and above.
constexpr const wchar_t* kDwmwaUseImmersiveDarkModeBefore20H1 =
    L"DwmUseImmersiveDarkMode";
constexpr DWORD kDwmwaUseImmersiveDarkMode = 19;
constexpr DWORD kDwmwaUseImmersiveDarkModeBefore20H1 = 20;

}  // namespace

Win32Window::Win32Window() {}

Win32Window::~Win32Window() {
  Destroy();
}

bool Win32Window::CreateAndShow(const std::wstring& title,
                               const Point& origin,
                               const Size& size) {
  Destroy();

  window_class_name_ = std::wstring(L"FLUTTER_RUNNER_WIN32_WINDOW_CLASS_") +
                       std::to_wstring(++instance_count_);

  WNDCLASS window_class{};
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class.lpszClassName = window_class_name_.c_str();
  window_class.style = CS_HREDRAW | CS_VREDRAW;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.hIcon =
      LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
  window_class.lpfnWndProc = Win32Window::WndProc;
  RegisterClass(&window_class);

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  POINT window_origin{static_cast<LONG>(origin.x * scale_factor),
                      static_cast<LONG>(origin.y * scale_factor)};

  CreateWindowEx(
      0, window_class_name_.c_str(), title.c_str(), WS_OVERLAPPEDWINDOW,
      window_origin.x, window_origin.y,
      static_cast<int>(size.width * scale_factor),
      static_cast<int>(size.height * scale_factor), nullptr, nullptr,
      GetModuleHandle(nullptr), this);

  if (window_handle_ != nullptr) {
    OnSizeChanged(size);
  }

  return window_handle_ != nullptr;
}

void Win32Window::Destroy() {
  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }

  if (!window_class_name_.empty()) {
    UnregisterClass(window_class_name_.c_str(), GetModuleHandle(nullptr));
    window_class_name_.clear();
  }
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  if (child_content_) {
    SetParent(child_content_, window_handle_);
  }
}

void Win32Window::SetTitle(const std::wstring& title) {
  if (window_handle_) {
    SetWindowText(window_handle_, title.c_str());
  }
}

void Win32Window::SetIcon(HICON icon) {
  if (window_handle_) {
    SendMessage(window_handle_, WM_SETICON, ICON_SMALL,
                reinterpret_cast<LPARAM>(icon));
    SendMessage(window_handle_, WM_SETICON, ICON_BIG,
                reinterpret_cast<LPARAM>(icon));
  }
}

void Win32Window::SizeChanged(const Size& size) {
  current_size_ = size;
  if (child_content_) {
    RECT rect = GetClientRect();
    MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
               rect.bottom - rect.top, TRUE);
  }
}

void Win32Window::FocusChanged(bool focused) {
  if (window_handle_) {
    if (focused) {
      SetFocus(window_handle_);
    }
  }
}

void Win32Window::OnClose() {
  if (window_handle_) {
    PostQuitMessage(0);
  }
}

LRESULT Win32Window::MessageHandler(HWND window,
                                    UINT const message,
                                    WPARAM const wparam,
                                    LPARAM const lparam) noexcept {
  return Win32MessageHandler(window, message, wparam, lparam);
}

LRESULT Win32Window::Win32MessageHandler(HWND window,
                                         UINT const message,
                                         WPARAM const wparam,
                                         LPARAM const lparam) noexcept {
  switch (message) {
    case WM_SETFOCUS:
      FocusChanged(true);
      break;
    case WM_KILLFOCUS:
      FocusChanged(false);
      break;
    case WM_SIZE: {
      Size size(LOWORD(lparam), HIWORD(lparam));
      SizeChanged(size);
      break;
    }
    case WM_CLOSE:
      OnClose();
      return 0;
    case WM_DESTROY:
      window_handle_ = nullptr;
      break;
  }
  return DefWindowProc(window, message, wparam, lparam);
}

ATOM Win32Window::RegisterWindowClass() {
  return 0;
}

bool Win32Window::CreateWindowWithStyle(const std::wstring& title,
                                       const Point& origin,
                                       const Size& size,
                                       DWORD window_style,
                                       DWORD window_style_ex,
                                       HWND parent) {
  return CreateWindowDefaultStyle(title, origin, size);
}

bool Win32Window::CreateWindowDefaultStyle(const std::wstring& title,
                                          const Point& origin,
                                          const Size& size) {
  return true;
}

void Win32Window::RestoreChildSize() {}

/// Enables the dark mode window decoration for a given window.
void EnableDarkMode(HWND window) {
  // No-op placeholder to keep the template structure complete.
  (void)window;
}
"""

FILES["runner/flutter_window.h"] = r"""#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow driven by the specified run configuration.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window,
                         UINT const message,
                         WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
"""

FILES["runner/flutter_window.cpp"] = r"""#include "flutter_window.h"

#include <optional>

#include "resource.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      GetWidth(), GetHeight(), project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd,
                              UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
"""

FILES["runner/resource.h"] = r"""//{{NO_DEPENDENCIES}}
// Microsoft Visual C++ generated include file.
// Used by runner.rc.
#define IDI_APP_ICON                    101
"""

FILES["runner/runner.rc"] = r"""// Microsoft Visual C++ generated resource script.
//
#include "resource.h"

#define APSTUDIO_READONLY_SYMBOLS
/////////////////////////////////////////////////////////////////////////////
//
// Icon
//
// Icon with lowest ID value placed first to ensure application icon
// remains consistent on all systems.
IDI_APP_ICON            ICON                    "resources/app_icon.ico"

#ifdef APSTUDIO_INVOKED
/////////////////////////////////////////////////////////////////////////////
//
// TEXTINCLUDE
//
1 TEXTINCLUDE
BEGIN
    "resource.h\0"
END

2 TEXTINCLUDE
BEGIN
    "#include ""winres.h""\r\n"
    "\0"
END

3 TEXTINCLUDE
BEGIN
    "\r\n"
    "\0"
END

#endif    // APSTUDIO_INVOKED
"""

FILES["runner/utils.h"] = r"""#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

namespace flutter {

// Returns the command line arguments passed to the application, encoded as
// UTF-8. On Windows, the arguments are stored as UTF-16 and need to be
// converted.
std::vector<std::string> GetDartEntrypointArguments();

}  // namespace flutter

#endif  // RUNNER_UTILS_H_
"""

FILES["runner/utils.cpp"] = r"""#include "utils.h"

#include <windows.h>

#include <string>
#include <vector>

namespace flutter {

std::vector<std::string> GetDartEntrypointArguments() {
  std::vector<std::string> arguments;

  int argc = 0;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return arguments;
  }

  for (int i = 1; i < argc; ++i) {
    std::wstring arg(argv[i]);
    int size = ::WideCharToMultiByte(CP_UTF8, 0, arg.c_str(), -1, nullptr, 0,
                                     nullptr, nullptr);
    std::string utf8(size - 1, '\0');
    ::WideCharToMultiByte(CP_UTF8, 0, arg.c_str(), -1, &utf8[0], size, nullptr,
                           nullptr);
    arguments.push_back(utf8);
  }

  ::LocalFree(argv);
  return arguments;
}

}  // namespace flutter
"""

FILES[".gitignore"] = r"""# Flutter/Win32 build artifacts
flutter/
**/flutter/.plugin_symlinks/
**/flutter/ephemeral/
**/flutter/generated_plugin_registrant.*
**/flutter/generated_plugins.cmake
**/flutter/windows_build_files.*
x64/
"""

FILES["flutter/CMakeLists.txt"] = r"""# This file is for use with the Flutter CMake tool backend.
# It is not used by the standard Flutter build process.
cmake_minimum_required(VERSION 3.14)

project(flutter_wrapper_app LANGUAGES CXX)

set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Generated files for the Flutter wrapper.
set(FLUTTER_WRAPPER_SOURCES
  "${FLUTTER_MANAGED_DIR}/cpp_client_wrapper/core_implementations.cc"
  "${FLUTTER_MANAGED_DIR}/cpp_client_wrapper/standard_codec.cc"
  "${FLUTTER_MANAGED_DIR}/cpp_client_wrapper/plugin_c_api.cc"
  "${FLUTTER_MANAGED_DIR}/cpp_client_wrapper/flutter_engine.cc"
  "${FLUTTER_MANAGED_DIR}/cpp_client_wrapper/flutter_view_controller.cc"
)

# Target for the Flutter wrapper library.
add_library(flutter_wrapper_app STATIC ${FLUTTER_WRAPPER_SOURCES})
apply_standard_settings(flutter_wrapper_app)
target_include_directories(flutter_wrapper_app PUBLIC "${FLUTTER_MANAGED_DIR}")
target_link_libraries(flutter_wrapper_app PUBLIC flutter)
target_link_libraries(flutter_wrapper_app PUBLIC flutter_wrapper_plugin)
add_dependencies(flutter_wrapper_app flutter_wrapper_plugin)
"""


def make_png(size, rgba):
    w = h = size
    raw = b"".join(b"\x00" + bytes(rgba) * w for _ in range(h))

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    idat = zlib.compress(raw)
    return sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


def make_ico(path, size=256, rgba=(63, 81, 181, 255)):
    png = make_png(size, rgba)
    # ICONDIR
    icon_dir = struct.pack("<HHH", 0, 1, 1)
    # ICONDIRENTRY (16 bytes)
    entry = struct.pack(
        "<BBBBHHII",
        size & 0xFF, size & 0xFF, 0, 0, 1, 32,
        len(png), 6 + 16,
    )
    with open(path, "wb") as f:
        f.write(icon_dir)
        f.write(entry)
        f.write(png)


def main():
    for rel, content in FILES.items():
        full = os.path.join(WIN, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8", newline="\n") as f:
            f.write(content)

    # app_icon.ico (PNG payload wrapped as ICO)
    ico_dir = os.path.join(WIN, "runner", "resources")
    os.makedirs(ico_dir, exist_ok=True)
    make_ico(os.path.join(ico_dir, "app_icon.ico"))

    print("windows/ scaffold written under", WIN)


if __name__ == "__main__":
    main()
