#ifndef RUNNER_UTILS_H_
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
