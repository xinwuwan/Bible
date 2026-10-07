#ifndef RUNNER_WIN32_WINDOW_H_
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
