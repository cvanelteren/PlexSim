g++ \
    -Ofast  \
    -fopenmp\
    -fdevirtualize\
    -fopenmp-simd \
    -DNDEBUG \
    -std=c++17\
    -march=native\
    -shared \
    -funroll-loops\
    -fPIC\
    -flto\
    -lcblas\
    -freorder-blocks-and-partition\
    -Wfatal-errors \
    -I/usr/include/python3.8/  \
    -I/home/casper/miniconda3/lib/python3.8/site-packages/numpy/core/include \
    -I/home/casper/miniconda3/include \
    example.cpp -o example`python3-config --extension-suffix`\
