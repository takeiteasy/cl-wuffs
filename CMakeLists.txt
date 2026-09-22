cmake_minimum_required(VERSION 3.20)
project(cl_wuffs LANGUAGES CXX)

add_library(cl_wuffs SHARED src/shim.cpp)
target_compile_features(cl_wuffs PRIVATE cxx_std_17)
target_include_directories(cl_wuffs PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")
set_target_properties(cl_wuffs PROPERTIES OUTPUT_NAME cl_wuffs)

install(TARGETS cl_wuffs LIBRARY DESTINATION lib)
