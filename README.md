# Helix.CMake

Shared CMake modules, toolchains, presets and CI workflow for all Helix repositories.

## Repository layout (all Helix repositories)

```
Helix.<Name>/
  Source/Helix/<Name>/                     the library; Source/ is the include root
    <Topic>/<Class>.h                      public headers, one class per file, PascalCase
    <Topic>/Implementation/<Class>.cpp     sources and internal headers of the topic
    <Topic>/Platform/<Os>/<Class><Os>.cpp  Os = Win, Linux, Android, Web, Posix
  Tests/<Topic>/<Class>Test.cpp            mirrors Source/
  Benchmarks/                              benchmarks
  Fuzz/                                    fuzz targets of the parsers
  Examples/<Example>/<Example>.cpp         runnable examples, Examples/Shared for common files
  Tools/                                   generators and scripts
  External/Helix.<Dependency>/             git submodules
  CMakeLists.txt, CMakePresets.json, README.md, LICENSE, .github/
```

- Includes always use the full path: `#include <Helix/Core/Containers/Array.h>`.
- Every repository lists all of its direct and indirect dependencies in its own `External/`; the build uses only that level,
  so submodules are fetched without `--recursive` (nested checkouts exceed the Windows path limit).
- Small libraries keep their headers directly in `Source/Helix/<Name>/` without topic folders.
- Files under `Platform/Win/` build only on Windows, `Platform/Linux/` only on Linux, `Platform/Android/` only on Android, `Platform/Web/` only on the web, `Platform/Posix/` on Linux, Android and the web.

## Contents

| Path | Purpose |
|---|---|
| `Helix.cmake` | Entry point included by every repository |
| `Modules/HelixPlatform.cmake` | Platform detection (`windows`, `linux`, `android`, `web`) and platform folder names |
| `Modules/HelixOptions.cmake` | C++23, warnings, no exceptions and no RTTI for runtime targets, `HELIX_ENABLE_ASAN` |
| `Modules/HelixDependencies.cmake` | `helix_require(Name)` resolves `Helix.<Name>` from `External/`; `helix_dependency_dir(out Name)` finds its folder (also for repos without CMake) |
| `Modules/HelixTargets.cmake` | `helix_add_library`, `helix_add_executable`, `helix_add_test_suite`, `helix_add_benchmark_suite`, `helix_add_fuzz_suite`, `helix_add_shared_runtime` |
| `Toolchains/Android.cmake` | Android NDK, arm64-v8a, API 24, the shared C++ runtime (`HELIX_ANDROID_STL_LIBRARY`, which applications carry) |
| `Toolchains/Web.cmake` | Emscripten from the .NET `wasm-tools` workload |
| `Presets/HelixPresets.json` | Configure, build and test presets for every platform |
| `Tests/Sample/` | A minimal library and executable in the standard layout |
| `.github/workflows/build.yml` | Reusable CI workflow for all platforms; `sanitize: true` adds the AddressSanitizer builds and tests |
| `.github/workflows/dotnet.yml` | Reusable CI workflow for C# repositories (build and run a test project) |

## Using it in a repository

```
git submodule add https://github.com/kisstp2006/Helix.CMake External/Helix.CMake
```

`CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.28)
project(Helix.Example LANGUAGES CXX)
if(NOT COMMAND helix_add_library)
    include(External/Helix.CMake/Helix.cmake)
endif()
helix_add_library(helix_example ALIAS Example)
helix_add_test_suite(helix_example_tests DEPS Helix::Example)
```

`CMakePresets.json`:

```json
{ "version": 6, "include": ["External/Helix.CMake/Presets/HelixPresets.json"] }
```

## Shared runtimes

`helix_add_shared_runtime(<target> ROOT <static library> ALIAS <name> OUTPUT_NAME <file name>)` makes one shared
library of a static library and every static Helix library it links (their object files, every symbol exported), for
programs that load modules at run time: the program and its modules link it and share one copy of the libraries'
state. Code built against it gets `HX_SHARED_IMPORT`, under which `HX_IMPORT_DATA` (Helix.Core) imports the global
data headers read on Windows. It is built only when something links it, and not on the Web.

## Presets

| Preset | Requirements |
|---|---|
| `windows-debug`, `windows-release` | Visual Studio 2022 C++ tools, run from a developer prompt |
| `linux-debug`, `linux-release` | clang, ninja |
| `android-arm64-debug`, `android-arm64-release` | Android NDK, `ANDROID_NDK_HOME` or `ANDROID_HOME` |
| `web-debug`, `web-release` | .NET SDK with `dotnet workload install wasm-tools`, `DOTNET_ROOT` or `HELIX_DOTNET_ROOT` |
| `windows-fuzz`, `linux-fuzz` | As above; optimized with assertions on, AddressSanitizer and debug information, for long fuzz runs |

```
cmake --preset windows-debug
cmake --build --preset windows-debug
ctest --preset windows-debug
```

Web tests run under the Node.js that ships with the workload.

## License

GPL-3.0, see `LICENSE`.
