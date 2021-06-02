#include <iostream>
#include <armadillo>
#include <time.h>
using namespace std; using namespace arma;

void test_matrix_dot(){
    mat a;
    mat b;
    mat c;

    vec sizes = {10, 100, 1000, 10000}; 

    clock_t start;
    for (int i = 0; i < sizes.size() ; ++i){
        a = randu<mat>(sizes[i], sizes[i]);
        b = randu<mat>(sizes[i], sizes[i]);
        c = randu<mat>(sizes[i], sizes[i]) ;
        start = clock(); 
        c = a * b;

        start = clock() - start;
        cout << "size " << sizes[i] << " " << 
        start/double(CLOCKS_PER_SEC) << endl;
    }
    return;
}


int main() {
    test_matrix_dot();
    return 0;
}
