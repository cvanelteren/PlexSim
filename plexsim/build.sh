g++ -Ofast  -march=native -Wall -shared -std=c++17 -fno-wrapv -fPIC `python3 -m pybind11 --includes` example.cpp -o example`python3-config --extension-suffix`
