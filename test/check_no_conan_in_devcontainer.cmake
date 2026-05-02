# Regression test for issue #117: Conan was installed in the dev container but
# never used; the project manages dependencies via CPM. This script asserts that
# the dev container Dockerfile does not reference Conan.

set(DOCKERFILE "${CMAKE_CURRENT_LIST_DIR}/../.devcontainer/Dockerfile")

if(NOT EXISTS "${DOCKERFILE}")
  message(FATAL_ERROR "Expected dev container Dockerfile at: ${DOCKERFILE}")
endif()

file(READ "${DOCKERFILE}" DOCKERFILE_CONTENT)
string(TOLOWER "${DOCKERFILE_CONTENT}" DOCKERFILE_CONTENT_LOWER)

if(DOCKERFILE_CONTENT_LOWER MATCHES "conan")
  message(
    FATAL_ERROR
    "Issue #117: '.devcontainer/Dockerfile' must not reference Conan; "
    "the project uses CPM for dependency management.")
endif()
