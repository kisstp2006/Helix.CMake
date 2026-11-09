include_guard(GLOBAL)

set(HELIX_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "")

include("${HELIX_CMAKE_DIR}/cmake/HelixPlatform.cmake")
include("${HELIX_CMAKE_DIR}/cmake/HelixOptions.cmake")
include("${HELIX_CMAKE_DIR}/cmake/HelixDependencies.cmake")
include("${HELIX_CMAKE_DIR}/cmake/HelixTargets.cmake")
