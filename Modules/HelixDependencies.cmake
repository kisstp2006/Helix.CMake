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

# The folder of a dependency by the same search as helix_require, also for one without CMake (a C# library): files
# of another repo are found where that repo is, not inside the folder of the repo that names them.
function(helix_dependency_dir out name)
    foreach(dir IN ITEMS "${CMAKE_SOURCE_DIR}/External/Helix.${name}" "${CMAKE_CURRENT_SOURCE_DIR}/External/Helix.${name}"
                         "${CMAKE_SOURCE_DIR}/../Helix.${name}")
        if(EXISTS "${dir}/README.md")
            set(${out} "${dir}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
    message(FATAL_ERROR "Helix: dependency Helix.${name} not found. Run: git submodule update --init")
endfunction()
