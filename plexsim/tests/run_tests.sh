g++ -O2 -Wall -fopenmp -fopenmp-simd -march=native -DNDEBUG  -std=c++17 -I /usr/include/eigen3 test_eigen.cpp -o eigen


echo "testing Eigen"
./eigen

echo "testing numpy"
python test_numpy.py
