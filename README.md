# Helix.CMake

Shared CMake modules, toolchains and presets for all Helix repositories.

## Contents

| Path | Purpose |
|---|---|
| `Helix.cmake` | Entry point included by every repository |
| `cmake/HelixPlatform.cmake` | Platform detection (`windows`, `linux`, `android`, `web`) |
| `cmake/HelixOptions.cmake` | C++23, warnings, no exceptions and no RTTI for runtime targets |
| `cmake/HelixDependencies.cmake` | `helix_require(Name)` resolves `Helix.<Name>` from `external/` |
| `cmake/HelixTargets.cmake` | `helix_add_library`, `helix_add_executable`, `helix_add_test_suite`, `helix_add_benchmark_suite` |
| `toolchains/android.cmake` | Android NDK, arm64-v8a, API 24 |
| `toolchains/web.cmake` | Emscripten from the .NET `wasm-tools` workload |
| `presets/HelixPresets.json` | Configure, build and test presets for every platform |
| `.github/workflows/build.yml` | Reusable CI workflow for all platforms |

## Using it in a repository

```
git submodule add https://github.com/kisstp2006/Helix.CMake external/Helix.CMake
```

`CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.28)
project(Helix.Example LANGUAGES CXX)
if(NOT COMMAND helix_add_library)
    include(external/Helix.CMake/Helix.cmake)
endif()
helix_add_library(helix_example ALIAS Example)
```

`CMakePresets.json`:

```json
{ "version": 6, "include": ["external/Helix.CMake/presets/HelixPresets.json"] }
```

Sources are collected from `src/`. Files under `src/platform/<platform>/` are only built for
that platform, files under `src/platform/posix/` for Linux, Android and the web.

## Presets

| Preset | Requirements |
|---|---|
| `windows-debug`, `windows-release` | Visual Studio 2022 C++ tools, run from a developer prompt |
| `linux-debug`, `linux-release` | clang, ninja |
| `android-arm64-debug`, `android-arm64-release` | Android NDK, `ANDROID_NDK_HOME` or `ANDROID_HOME` |
| `web-debug`, `web-release` | .NET SDK with `dotnet workload install wasm-tools`, `DOTNET_ROOT` or `HELIX_DOTNET_ROOT` |

```
cmake --preset windows-debug
cmake --build --preset windows-debug
ctest --preset windows-debug
```

Web tests run under the Node.js that ships with the workload.

## License

GPL-3.0, see `LICENSE`.
