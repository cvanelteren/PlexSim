#include "NumCpp/include/NumCpp.hpp"
#include <iostream>
#include <time.h>
using namespace std;

void test_numcpp(nc::NdArray<double> & a, nc::NdArray<double> & b){
    nc::dot(a, b);
};


int main(){
         
    int N = 2000;
    nc::NdArray<double> a = nc::random::randN<double>(nc::Shape(N, N));
    nc::NdArray<double> b = nc::random::randN<double>(nc::Shape(N, N));

    
    clock_t start = clock();
    for(auto i= 0 ; i< 10; ++i){
        test_numcpp(a, b);
    }
    start = clock() - start;
    cout << "Time taken : " << start / double(CLOCKS_PER_SEC) << endl;
         return 0;
}
