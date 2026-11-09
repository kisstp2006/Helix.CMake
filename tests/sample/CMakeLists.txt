helix_add_library(helix_sample ALIAS Sample)
helix_add_executable(helix_sample_app SOURCES app/main.cpp DEPS Helix::Sample)
