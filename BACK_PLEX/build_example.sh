g++  -Ofast  -fopenmp -fdevirtualize -fopenmp-simd  -DNDEBUG  -std=c++20  \
-march=native -shared  -funroll-loops -fPIC -flto -lcblas \
-freorder-blocks-and-partition -Wfatal-errors \
-I/home/casper/miniconda3/include/python3.8/ \
-I/home/casper/miniconda3/lib/python3.8/site-packages/numpy/core/include \
-I/home/casper/miniconda3/lib/python3.8/site-packages/pybind11/include/ \
-I/home/casper/miniconda3/include  example.cpp -o example`python3-config \
--extension-suffix`
