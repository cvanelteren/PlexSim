#include <iostream>
#include <stdio.h>
#include "xtensor/xarray.hpp"
#include "xtensor/xio.hpp"
#include "xtensor/xview.hpp"
#include "xtensor/xrandom.hpp"
#include "xtensor-blas/xlinalg.hpp"
#include "xtensor/xnoalias.hpp"
#include <time.h>
using namespace std;
using namespace xt;
void test_dot(){
    //xarray<int> mat = xarray<int>({10, 100, 1000, 10000}) ;
    xarray<int> mat = xarray<int>({10}) ;

    xarray<float> a;
    xarray<float> b;
    xarray<float> c;


    clock_t start;
    for (int i = 0 ; i < mat.size(); ++i){
        a = random::randn<float>({mat[i] * mat[i]});
        b = random::randn<float>({mat[i] * mat[i]});
        c = random::randn<float>({mat[i], mat[i]});
        auto v1 = xt::view(b, xt::range(0,mat[i]), xt::range(0,mat[i]));

        printf("testing prinf %d %s ", v1.size(), v1.shape());
        start = clock();
        xt::noalias(c) = linalg::dot(                         \
                        xt::view(a, xt::range(0,mat[i]), xt::range(0, mat[i])), \
                        xt::view(b, xt::range(0,mat[i]), xt::range(0,mat[i])) \
                        );


        start = clock() - start;
        cout << "Size : " << mat[i] << " " << start / double(CLOCKS_PER_SEC) << endl;
    }
    return;
}
int main(int argc, char* argv[])
{
    test_dot(); 

    return 0;
}
