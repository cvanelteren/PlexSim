cmake_minimum_required(VERSION 3.10)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED true)

set(Python3_ROOT_DIR "%{CONDA_ROOT}/envs/plexsim")

find_package(Python3 COMPONENTS NumPy REQUIRED)
include_directories(${CONDA_ROOT}/envs/plexsim/lib/python3.8/site-packages/include)

include_directories(${CONDA_ROOT}/envs/plexsim/lib/python3.8/site-packages/numpy/core/include/)

include_directories(/usr/include)


project(cpp_models)
find_package(pybind11 REQUIRED)

pybind11_add_module(example example.cpp)

