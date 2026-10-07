#include "flutter_window.h"
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

  if (!window.CreateAndShow(L"真理对照", origin, size)) {
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
