#include "win32_window.h"

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
