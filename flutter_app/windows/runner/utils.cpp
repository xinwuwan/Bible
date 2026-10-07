#include "utils.h"

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
