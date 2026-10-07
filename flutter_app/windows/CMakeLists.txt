cmake_minimum_required(VERSION 3.14)
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
