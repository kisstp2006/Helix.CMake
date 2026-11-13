include_guard(GLOBAL)

set(HELIX_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "")

include("${HELIX_CMAKE_DIR}/Modules/HelixPlatform.cmake")
include("${HELIX_CMAKE_DIR}/Modules/HelixOptions.cmake")
include("${HELIX_CMAKE_DIR}/Modules/HelixDependencies.cmake")
include("${HELIX_CMAKE_DIR}/Modules/HelixDotnet.cmake")
include("${HELIX_CMAKE_DIR}/Modules/HelixBuildCache.cmake")
include("${HELIX_CMAKE_DIR}/Modules/HelixTargets.cmake")
