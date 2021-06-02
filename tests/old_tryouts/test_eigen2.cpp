#include <iostream>
#include <Eigen/Dense>
#include <chrono>
using namespace Eigen;
int main()
{
    std::cout << "Testing here" << std::endl;
    int size=10000;
    MatrixXd A=MatrixXd::Random(size,size);
    MatrixXd B=MatrixXd::Random(size,size);
    std::chrono::time_point<std::chrono::system_clock> start =
        std::chrono::system_clock::now();
    int N = 1;
    for(int i=0;i<N;i++){
        volatile MatrixXd C=A*B;
    }
    std::chrono::duration<double> elapsed_time =
        std::chrono::system_clock::now() - start;
    std::cout<<double(elapsed_time.count())/ double(N) <<std::endl;
}
