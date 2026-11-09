cmake_minimum_required(VERSION 3.28)
project(Helix.CMake LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/Helix.cmake")

add_subdirectory(tests/sample)
