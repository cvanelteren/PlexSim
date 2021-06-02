#include <random>
#include <cstdio>
#include <stdlib.h>
#include <iostream>
#include <cblas.h>
void test_blas(){

    // Random numbers
    std::mt19937_64 rnd;
    std::uniform_real_distribution<double> doubleDist(0, 1);

    // Create arrays that represent the matrices A,B,C
    const int n = 2000;
    double*  A = new double[n*n];
    double*  B = new double[n*n];
    double*  C = new double[n*n];

    // Fill A and B with random numbers

    // Calculate A*B=C
    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, n, n, n, 1.0, A, n, B, n, 0.0, C, n);
        // Clean up
    delete[] A;
    delete[] B;
    delete[] C;
    return ;

}
int main ( int argc, char* argv[] ) {

    clock_t start = clock();
    for (auto i = 0; i < 10; ++i){
        test_blas();
    }
    clock_t end = clock();
    double time = double(end - start)/ CLOCKS_PER_SEC;
    std::cout<< "Time taken : " << time << std::endl; 

    return 0;
}
