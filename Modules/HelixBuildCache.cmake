include_guard(GLOBAL)

# The shared object cache (local builds): on when HELIX_BUILD_CACHE (a cache variable or the environment) names a
# folder and the .NET SDK is found. Every C and C++ compile goes through Tools/CompileCache, which keeps object files
# by the preprocessed source and the command line with the folders of the Helix repositories and of the build written
# as names, so the copies of a repository in the External folders of different repositories (and the same files built
# again) compile once per preset. The build's dependency tracking stays the compiler's. HELIX_BUILD_CACHE_SIZE (GB, 20)
# bounds the folder: objects used least lately go at configure time.
set(HELIX_BUILD_CACHE "$ENV{HELIX_BUILD_CACHE}" CACHE PATH "Folder of the shared object cache (empty: off)")
set(HELIX_BUILD_CACHE_SIZE 20 CACHE STRING "Size of the shared object cache in GB")

function(helix_enable_build_cache)
    if(NOT HELIX_BUILD_CACHE OR NOT HELIX_DOTNET)
        return()
    endif()
    file(TO_CMAKE_PATH "${HELIX_BUILD_CACHE}" cache)
    set(source "${HELIX_CMAKE_DIR}/Tools/CompileCache")
    # The tool, built once per version of its sources.
    file(SHA256 "${source}/Program.cs" program_hash)
    file(SHA256 "${source}/CompileCache.csproj" project_hash)
    string(SHA256 tool_hash "${program_hash}${project_hash}")
    string(SUBSTRING "${tool_hash}" 0 16 tool_hash)
    set(tool_dir "${cache}/tool/${tool_hash}")
    set(tool "${tool_dir}/HelixCompileCache.dll")
    if(NOT EXISTS "${tool}")
        execute_process(COMMAND "${HELIX_DOTNET}" build "${source}/CompileCache.csproj" -c Release -o "${tool_dir}"
                                --artifacts-path "${cache}/tool/artifacts-${tool_hash}" --nologo -v quiet
                        RESULT_VARIABLE result OUTPUT_QUIET ERROR_QUIET)
        if(NOT result EQUAL 0 OR NOT EXISTS "${tool}")
            message(WARNING "Helix: the object cache tool did not build; compiling without the cache")
            return()
        endif()
    endif()
    execute_process(COMMAND "${HELIX_DOTNET}" "${tool}" --cache "${cache}" --prune "${HELIX_BUILD_CACHE_SIZE}" OUTPUT_QUIET ERROR_QUIET)
    # The folders written as names: the build, the repository and the copies of its dependencies.
    get_filename_component(top_name "${CMAKE_SOURCE_DIR}" NAME)
    set(map "${CMAKE_BINARY_DIR}\t<build>\n${CMAKE_SOURCE_DIR}\t<${top_name}>\n")
    file(GLOB externals LIST_DIRECTORIES true "${CMAKE_SOURCE_DIR}/External/Helix.*")
    foreach(dir IN LISTS externals)
        get_filename_component(name "${dir}" NAME)
        string(APPEND map "${dir}\t<${name}>\n")
    endforeach()
    set(map_file "${CMAKE_BINARY_DIR}/HelixCompileCache.map")
    file(CONFIGURE OUTPUT "${map_file}" CONTENT "${map}" @ONLY)
    set(launcher "${HELIX_DOTNET}" "${tool}" --cache "${cache}" --map "${map_file}" --)
    foreach(lang IN ITEMS C CXX)
        set(CMAKE_${lang}_COMPILER_LAUNCHER ${launcher} ${CMAKE_${lang}_COMPILER_LAUNCHER} PARENT_SCOPE)
    endforeach()
    message(STATUS "Helix: shared object cache in ${cache}")
endfunction()

helix_enable_build_cache()
