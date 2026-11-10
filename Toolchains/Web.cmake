# The web build must use the Emscripten that ships with the .NET wasm-tools workload,
# because the engine is linked into the .NET browser runtime.

if(NOT DEFINED HELIX_DOTNET_ROOT)
    if(DEFINED ENV{HELIX_DOTNET_ROOT})
        set(HELIX_DOTNET_ROOT "$ENV{HELIX_DOTNET_ROOT}")
    elseif(DEFINED ENV{DOTNET_ROOT})
        set(HELIX_DOTNET_ROOT "$ENV{DOTNET_ROOT}")
    else()
        find_program(dotnet_exe dotnet)
        if(dotnet_exe)
            file(REAL_PATH "${dotnet_exe}" dotnet_exe)
            get_filename_component(HELIX_DOTNET_ROOT "${dotnet_exe}" DIRECTORY)
        endif()
    endif()
endif()
set(HELIX_DOTNET_ROOT "${HELIX_DOTNET_ROOT}" CACHE PATH ".NET root with the wasm-tools workload")

if(CMAKE_HOST_WIN32)
    set(host_rid win-x64)
    set(exe_suffix .exe)
elseif(CMAKE_HOST_APPLE)
    set(host_rid osx-arm64)
    set(exe_suffix "")
else()
    set(host_rid linux-x64)
    set(exe_suffix "")
endif()

function(helix_find_pack out kind)
    file(GLOB packs "${HELIX_DOTNET_ROOT}/packs/Microsoft.NET.Runtime.Emscripten.*.${kind}.${host_rid}/*")
    list(SORT packs COMPARE NATURAL ORDER DESCENDING)
    list(LENGTH packs count)
    if(count EQUAL 0)
        message(FATAL_ERROR "Helix: Emscripten ${kind} pack not found under ${HELIX_DOTNET_ROOT}. Run: dotnet workload install wasm-tools")
    endif()
    list(GET packs 0 pack)
    set(${out} "${pack}/tools" PARENT_SCOPE)
endfunction()

helix_find_pack(emsdk_tools Sdk)
helix_find_pack(node_tools Node)
helix_find_pack(cache_tools Cache)
if(CMAKE_HOST_WIN32)
    helix_find_pack(python_tools Python)
endif()

set(HELIX_EMSCRIPTEN_ROOT "${emsdk_tools}/emscripten" CACHE INTERNAL "")
set(HELIX_EMSCRIPTEN_NODE "${node_tools}/bin/node${exe_suffix}" CACHE INTERNAL "")
if(NOT EXISTS "${HELIX_EMSCRIPTEN_NODE}")
    set(HELIX_EMSCRIPTEN_NODE "${node_tools}/node${exe_suffix}" CACHE INTERNAL "")
endif()

set(HELIX_EMSCRIPTEN_CONFIG "${CMAKE_BINARY_DIR}/helix.emscripten" CACHE INTERNAL "")
file(WRITE "${HELIX_EMSCRIPTEN_CONFIG}"
    "LLVM_ROOT = r'${emsdk_tools}/bin'\n"
    "BINARYEN_ROOT = r'${emsdk_tools}'\n"
    "NODE_JS = r'${HELIX_EMSCRIPTEN_NODE}'\n"
    "CACHE = r'${cache_tools}/emscripten/cache'\n"
    "FROZEN_CACHE = True\n")

set(ENV{EM_CONFIG} "${HELIX_EMSCRIPTEN_CONFIG}")
if(CMAKE_HOST_WIN32)
    set(ENV{EMSDK_PYTHON} "${python_tools}/python.exe")
endif()

set(env_launcher "${CMAKE_COMMAND};-E;env;EM_CONFIG=${HELIX_EMSCRIPTEN_CONFIG}")
if(CMAKE_HOST_WIN32)
    list(APPEND env_launcher "EMSDK_PYTHON=${python_tools}/python.exe")
endif()
set(CMAKE_C_COMPILER_LAUNCHER "${env_launcher}")
set(CMAKE_CXX_COMPILER_LAUNCHER "${env_launcher}")
set(CMAKE_C_LINKER_LAUNCHER "${env_launcher}")
set(CMAKE_CXX_LINKER_LAUNCHER "${env_launcher}")

include("${HELIX_EMSCRIPTEN_ROOT}/cmake/Modules/Platform/Emscripten.cmake")

set(HELIX_EMSCRIPTEN_AR "${emsdk_tools}/bin/llvm-ar${exe_suffix}" CACHE INTERNAL "")
set(HELIX_EMSCRIPTEN_RANLIB "${emsdk_tools}/bin/llvm-ranlib${exe_suffix}" CACHE INTERNAL "")
set(CMAKE_CROSSCOMPILING_EMULATOR "${HELIX_EMSCRIPTEN_NODE}")
