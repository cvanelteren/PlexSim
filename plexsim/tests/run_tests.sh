#g++ -O3 -Wall -march=native -DNDEBUG  -std=c++17 -DEIGEN_USE_MKL_ALL -DMKL_ILP64 -m64 -I/usr/include/eigen3 -I/opt/intel/mkl/include -I. test_eigen.cpp -o eigen -L /opt/intel/mkl/lib/intel64 -Wl,--no-as-needed -lmkl_intel_ilp64 -lmkl_intel_thread -lmkl_core -liomp5 -lpthread -lm -ldl 

g++ -Ofast -Wall -fopenmp -march=native -DNDEBUG -std=c++17 -I/usr/include/eigen3 test_eigen.cpp -o eigen -lcblas

./eigen

echo "testing numpy"
python test_numpy.py
