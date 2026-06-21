#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE hMutex = nullptr;
#ifndef _DEBUG
  // --- Single-instance enforcement via named Mutex ---
  // Keep this disabled in Debug builds. `flutter run` needs the newly launched
  // process to own the debug connection; otherwise a stale/hung previous window
  // can keep the mutex and every new run only tries to focus that old instance.
  hMutex = ::CreateMutexW(nullptr, TRUE, L"Global\\AlphaCRM_SingleInstance");
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Alpha CRM");
    if (existing) {
      DWORD_PTR result = 0;
      const bool is_responsive =
          ::SendMessageTimeoutW(existing, WM_NULL, 0, 0,
                                SMTO_ABORTIFHUNG | SMTO_BLOCK, 1000,
                                &result) != 0;
      if (is_responsive) {
        if (::IsIconic(existing)) {
          ::ShowWindow(existing, SW_RESTORE);
        }
        ::SetForegroundWindow(existing);
        if (hMutex) {
          ::CloseHandle(hMutex);
        }
        return EXIT_SUCCESS;
      }
    }
    if (hMutex) {
      ::CloseHandle(hMutex);
    }
    return EXIT_FAILURE;
  }
#endif

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Alpha CRM", origin, size)) {
    if (hMutex) ::CloseHandle(hMutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // --- Force maximize on startup ---
  ::ShowWindow(window.GetHandle(), SW_SHOWMAXIMIZED);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (hMutex) {
    ::ReleaseMutex(hMutex);
    ::CloseHandle(hMutex);
  }
  return EXIT_SUCCESS;
}
