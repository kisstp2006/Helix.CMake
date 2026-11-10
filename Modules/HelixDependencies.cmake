include_guard(GLOBAL)

# A dependency is taken from the top-level repo External/ folder first, so every repo is built once.
function(helix_require name)
    if(TARGET Helix::${name})
        return()
    endif()
    set(candidates
        "${CMAKE_SOURCE_DIR}/External/Helix.${name}"
        "${CMAKE_CURRENT_SOURCE_DIR}/External/Helix.${name}"
        "${CMAKE_SOURCE_DIR}/../Helix.${name}")
    foreach(dir IN LISTS candidates)
        if(EXISTS "${dir}/CMakeLists.txt")
            add_subdirectory("${dir}" "${CMAKE_BINARY_DIR}/External/Helix.${name}" EXCLUDE_FROM_ALL)
            if(NOT TARGET Helix::${name})
                message(FATAL_ERROR "Helix: ${dir} does not define Helix::${name}")
            endif()
            return()
        endif()
    endforeach()
    message(FATAL_ERROR "Helix: dependency Helix.${name} not found. Run: git submodule update --init")
endfunction()
