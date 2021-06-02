#include <iostream>
#include <time.h>
#include <chrono>

#define EIGEN_USE_MK_ALL
#include <Eigen/Dense>
#include <Eigen/Core>

#include "xtensor/xrandom.hpp"
#include "xtensor-blas/xlinalg.hpp"
#include "xtensor/xnoalias.hpp"

using namespace xt;

using namespace std;
using namespace chrono;
using namespace Eigen;



void test_dot_mat(MatrixXd* a, MatrixXd* b,\
                  MatrixXd* c){
    (*c).noalias() = (*a) * (*b);
    return ;
}


void timeit_eigen(){
    VectorXi sizes(4);
    sizes << 10, 100, 1000 ;
    MatrixXd a;
    MatrixXd b;
    MatrixXd c;
 
    int nTrials = 3;
    for (int i = 0; i < sizes.size(); ++i){
        a = MatrixXd::Random(sizes(i), sizes(i)) ;
        b = MatrixXd::Random(sizes(i), sizes(i)) ;
        c = MatrixXd::Random(sizes(i), sizes(i)) ;
        auto start = high_resolution_clock::now();
        for (int trial = 0; trial < nTrials; ++trial){
           test_dot_mat(&a, &b, &c);
        }
        auto stop = high_resolution_clock::now();
        auto duration = duration_cast<milliseconds>(stop - start);
        cout << "Size " << sizes(i) << " " << duration.count() / double(nTrials) << " ms" << endl;
    }
    return ;
}


 void timeit_xtensor(){
     //xarray<int> mat = xarray<int>({10, 100, 1000, 10000}) ;
     xarray<int> mat = xarray<int>({10, 100, 1000} ) ;

     xarray<float> a;
     xarray<float> b;
     xarray<float> c;


     int nTrials = 3;
     for (int i = 0 ; i < mat.size(); ++i){

         
         auto start =  high_resolution_clock::now();
         a = random::randn<float>({mat[i] , mat[i]});
         b = random::randn<float>({mat[i] , mat[i]});
         c = random::randn<float>({mat[i], mat[i]});
         auto v1 = xt::view(b, xt::range(0,mat[i]), xt::range(0,mat[i]));

         auto stop = high_resolution_clock::now();
         auto duration = duration_cast<milliseconds>(stop - start);
         //cout << "Alloc Size " << mat[i] << " " << duration.count() << " ms" << endl;

         start = high_resolution_clock::now();
         for (int trial = 0; trial < nTrials ; ++trial){
             xt::noalias(c) = linalg::dot(\
                                          a, b);

         }
         stop = high_resolution_clock::now();
         duration = duration_cast<milliseconds> (stop - start);
         cout << "Size " << mat[i] << " " << duration.count() / double(nTrials) << " ms" << endl;
         }
     return;
 }

int main(){
    cout << "Testing eigen" << endl;
    timeit_eigen();

    cout << "Testing xtensor" << endl;
     timeit_xtensor();
    return 0;
}
