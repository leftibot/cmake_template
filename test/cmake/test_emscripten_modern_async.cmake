#[[
Regression test for #155: WASM builds were broken because
cmake/Emscripten.cmake combined two flags that newer Emscripten releases
reject in the same translation unit:

  * -fwasm-exceptions  (set via add_compile_options / add_link_options)
  * -sASYNCIFY=1       (set via target_link_options on each WASM target)

The link step ended in `wasm-opt` with
`Fatal: Module::getFunction: __asyncify_get_call_index does not exist`
because the legacy Asyncify transformation is incompatible with native
WebAssembly exception handling.

Per the issue ("Prefer the modern replacement features") the project
should use JSPI (JavaScript Promise Integration) instead, which is the
upstream-recommended replacement for legacy Asyncify and works alongside
-fwasm-exceptions.

This test simulates an EMSCRIPTEN configuration, stubs the CMake commands
that touch real targets, includes Emscripten.cmake, and asserts that:

  1. The legacy `-sASYNCIFY=1` flag is NOT emitted (regression guard).
  2. The legacy `-sASYNCIFY_STACK_SIZE` flag is NOT emitted (irrelevant
     for JSPI).
  3. The modern `-sJSPI=1` flag IS emitted on the WASM target.
  4. `-fwasm-exceptions` is still active on the global compile/link
     options so native EH continues to be used.
]]

cmake_minimum_required(VERSION 3.21)

set(EMSCRIPTEN TRUE)

# Use the real source tree so EXISTS checks against the shell template pass
# and Emscripten.cmake's input templates resolve correctly.
set(CMAKE_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../..")

# Caller (CTest) supplies an out-of-tree scratch dir via -DTEST_TMP_DIR=...;
# fall back to the platform temp dir when the script is invoked manually.
if(NOT DEFINED TEST_TMP_DIR OR TEST_TMP_DIR STREQUAL "")
  set(TEST_TMP_DIR "$ENV{TMPDIR}")
  if(TEST_TMP_DIR STREQUAL "")
    set(TEST_TMP_DIR "/tmp")
  endif()
  set(TEST_TMP_DIR "${TEST_TMP_DIR}/cmake_template_test_emscripten_modern_async")
endif()
set(CMAKE_BINARY_DIR "${TEST_TMP_DIR}")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}")

set(CAPTURE_FILE "${CMAKE_BINARY_DIR}/captured_options.txt")
file(WRITE "${CAPTURE_FILE}" "")

# Capture global compile / link options emitted at module-include time.
function(add_compile_options)
  file(APPEND "${CAPTURE_FILE}" "ADD_COMPILE_OPTIONS:${ARGN}\n")
endfunction()

function(add_link_options)
  file(APPEND "${CAPTURE_FILE}" "ADD_LINK_OPTIONS:${ARGN}\n")
endfunction()

# Capture per-target link options.  Drop the leading <target> <scope> args
# so the captured payload is easy to grep.
function(target_link_options)
  set(_args "${ARGN}")
  list(REMOVE_AT _args 0 1)
  file(APPEND "${CAPTURE_FILE}" "TARGET_LINK_OPTIONS:${_args}\n")
endfunction()

# Stub out the rest of the target-affecting commands so script mode
# doesn't try to look up a real CMake target.
function(target_compile_definitions)
endfunction()

function(get_target_property var target prop)
  set(${var} "${target}" PARENT_SCOPE)
endfunction()

function(set_target_properties)
endfunction()

function(add_custom_command)
endfunction()

function(configure_file)
endfunction()

function(set_property)
endfunction()

include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/Emscripten.cmake")

myproject_configure_wasm_target(
  fake_wasm_target
  TITLE "Fake"
  DESCRIPTION "Fake WASM target for regression test #155")

file(READ "${CAPTURE_FILE}" captures)
message(STATUS "Captured Emscripten options:\n${captures}")

if(captures MATCHES "ASYNCIFY=1")
  message(
    FATAL_ERROR
    "Legacy -sASYNCIFY=1 must not be emitted: it is incompatible with "
    "-fwasm-exceptions and breaks WASM linking (#155). Captured:\n${captures}")
endif()

if(captures MATCHES "ASYNCIFY_STACK_SIZE")
  message(
    FATAL_ERROR
    "-sASYNCIFY_STACK_SIZE is only meaningful for legacy Asyncify and "
    "should be removed alongside -sASYNCIFY=1 (#155). Captured:\n${captures}")
endif()

if(NOT captures MATCHES "-sJSPI=1")
  message(
    FATAL_ERROR
    "Expected modern -sJSPI=1 flag (replacement for legacy Asyncify) on "
    "the WASM target (#155). Captured:\n${captures}")
endif()

if(NOT captures MATCHES "-fwasm-exceptions")
  message(
    FATAL_ERROR
    "-fwasm-exceptions must remain enabled for WASM builds; the fix "
    "for #155 should switch async support, not disable native EH. "
    "Captured:\n${captures}")
endif()
