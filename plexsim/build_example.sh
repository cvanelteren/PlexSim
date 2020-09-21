g++ `python3-config --cflags` \
    -Ofast  \
    -fopenmp\
    -DNDEBUG \
    -std=c++17\
    -fno-wrapv \
    -fopenmp-simd \
    -funroll-loops \
    -march=native\
    -frename-registers \
    -march=native \
    -flto  \
    -shared \
    -Wfatal-errors -I/usr/include  \
    -I/home/casper/miniconda3/lib/python3.8/site-packages/numpy/core/include -I/home/casper/miniconda3/include \
    -D_FORTIFY_S \
    example.cpp -o example`python3-config --extension-suffix`
