include_guard(GLOBAL)

# .NET for the build: the SDK (HELIX_DOTNET, from HELIX_DOTNET_ROOT, DOTNET_ROOT or the path), the version of the
# runtime it ships, and packs of the NuGet cache (runtime packs, crossgen2) restored when they are missing.
find_program(HELIX_DOTNET NAMES dotnet HINTS "$ENV{HELIX_DOTNET_ROOT}" "$ENV{DOTNET_ROOT}")

# The highest Microsoft.NETCore.App version of the SDK's shared/ folder (empty without an SDK).
function(helix_dotnet_runtime_version out)
    set(version "")
    if(HELIX_DOTNET)
        file(REAL_PATH "${HELIX_DOTNET}" dotnet)
        get_filename_component(root "${dotnet}" DIRECTORY)
        file(GLOB versions LIST_DIRECTORIES true RELATIVE "${root}/shared/Microsoft.NETCore.App" "${root}/shared/Microsoft.NETCore.App/*")
        list(SORT versions COMPARE NATURAL ORDER DESCENDING)
        if(versions)
            list(GET versions 0 version)
        endif()
    endif()
    set(${out} "${version}" PARENT_SCOPE)
endfunction()

# The NuGet cache: NUGET_PACKAGES, else the user's .nuget/packages.
function(helix_nuget_cache out)
    if(DEFINED ENV{NUGET_PACKAGES})
        set(cache "$ENV{NUGET_PACKAGES}")
    elseif(DEFINED ENV{USERPROFILE})
        set(cache "$ENV{USERPROFILE}/.nuget/packages")
    else()
        set(cache "$ENV{HOME}/.nuget/packages")
    endif()
    file(TO_CMAKE_PATH "${cache}" cache)
    set(${out} "${cache}" PARENT_SCOPE)
endfunction()

# helix_dotnet_pack(<out> <package id> [VERSION <version>]): the folder of a package of the NuGet cache, restored
# through a PackageDownload project when it is missing (the exact version, the SDK's runtime version by default;
# NuGet checks the package's hash). Empty with a warning when it cannot be had.
function(helix_dotnet_pack out id)
    cmake_parse_arguments(ARG "" "VERSION" "" ${ARGN})
    set(version "${ARG_VERSION}")
    if(NOT version)
        helix_dotnet_runtime_version(version)
    endif()
    helix_nuget_cache(cache)
    string(TOLOWER "${id}" lower)
    set(dir "${cache}/${lower}/${version}")
    if(NOT EXISTS "${dir}/.nupkg.metadata" AND HELIX_DOTNET AND version)
        set(work "${CMAKE_BINARY_DIR}/HelixDotnetPacks/${id}")
        file(WRITE "${work}/Download.csproj"
"<Project Sdk=\"Microsoft.NET.Sdk\">
  <!-- Written by helix_dotnet_pack: brings ${id} ${version} into the NuGet cache. -->
  <PropertyGroup>
    <TargetFramework>net11.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageDownload Include=\"${id}\" Version=\"[${version}]\" />
  </ItemGroup>
</Project>
")
        message(STATUS "Helix: restoring ${id} ${version}")
        execute_process(COMMAND "${HELIX_DOTNET}" restore "${work}/Download.csproj" --nologo -v quiet
                        RESULT_VARIABLE result OUTPUT_VARIABLE output ERROR_VARIABLE output)
        if(NOT result EQUAL 0)
            message(WARNING "Helix: ${id} ${version} could not be restored:\n${output}")
        endif()
    endif()
    if(EXISTS "${dir}/.nupkg.metadata")
        set(${out} "${dir}" PARENT_SCOPE)
    else()
        set(${out} "" PARENT_SCOPE)
    endif()
endfunction()

# The function that makes .NET executables on the Web (helix_add_executable ... DOTNET): set by the repo of the .NET
# host with helix_set_dotnet_web_executable(<function>); the function gets the executable target after its creation.
function(helix_set_dotnet_web_executable function)
    set_property(GLOBAL PROPERTY HELIX_DOTNET_WEB_EXECUTABLE "${function}")
endfunction()

# helix_dotnet_ready_to_run(<out list> OUTPUT_DIR <folder> ASSEMBLIES <dll>... [DEPENDS <target or file>...]): ReadyToRun
# images of the assemblies (crossgen2 of the NuGet cache, for this machine's OS and architecture) in OUTPUT_DIR, made
# against the SDK's shared framework and each other; <out list> names them (empty, with a warning, when there is no
# crossgen2). Native code ready at start up; the runtime falls back to the JIT where an image does not fit it.
function(helix_dotnet_ready_to_run out)
    cmake_parse_arguments(ARG "" "OUTPUT_DIR" "ASSEMBLIES;DEPENDS" ${ARGN})
    if(CMAKE_HOST_WIN32)
        set(host_rid win-x64)
        set(os windows)
        set(exe crossgen2.exe)
    else()
        set(host_rid linux-x64)
        set(os linux)
        set(exe crossgen2)
    endif()
    helix_dotnet_pack(crossgen "Microsoft.NETCore.App.Crossgen2.${host_rid}")
    helix_dotnet_runtime_version(version)
    file(REAL_PATH "${HELIX_DOTNET}" dotnet)
    get_filename_component(dotnet_root "${dotnet}" DIRECTORY)
    set(framework "${dotnet_root}/shared/Microsoft.NETCore.App/${version}")
    if(NOT crossgen OR NOT EXISTS "${crossgen}/tools/${exe}" OR NOT EXISTS "${framework}")
        message(WARNING "Helix: no crossgen2 for ${host_rid}; the assemblies stay IL only")
        set(${out} "" PARENT_SCOPE)
        return()
    endif()
    set(images "")
    foreach(assembly IN LISTS ARG_ASSEMBLIES)
        get_filename_component(name "${assembly}" NAME)
        set(image "${ARG_OUTPUT_DIR}/${name}")
        set(references "")
        foreach(other IN LISTS ARG_ASSEMBLIES)
            if(NOT other STREQUAL assembly)
                list(APPEND references "-r:${other}")
            endif()
        endforeach()
        add_custom_command(
            OUTPUT "${image}"
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${ARG_OUTPUT_DIR}"
            COMMAND "${crossgen}/tools/${exe}" "${assembly}" -o "${image}" "-r:${framework}/*.dll" ${references} --targetos ${os} --targetarch x64 -O
            DEPENDS "${assembly}" ${ARG_DEPENDS}
            COMMENT "ReadyToRun: ${name}"
            VERBATIM)
        list(APPEND images "${image}")
    endforeach()
    set(${out} "${images}" PARENT_SCOPE)
endfunction()
