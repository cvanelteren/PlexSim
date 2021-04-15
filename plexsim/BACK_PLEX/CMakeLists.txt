cmake_minimum_required(VERSION 3.10)
set(CMAKE_CXX_STANDARD c++17)
set(CMAKE_CXX_STANDARD_REQUIRED true)
set(PYBIND11_CPP_STANDARD -std=c++latest)

set(Python3_FIND_VIRTUALENV "FIRST")
find_package(Python3 3.8.2 COMPONENTS Interpreter Development NumPy REQUIRED)
find_package(pybind11 REQUIRED)

project(cpp_models)

pybind11_add_module(example Release example.cpp)

