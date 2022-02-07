#ifndef GRADIENT_CHECKER_H_
#define GRADIENT_CHECKER_H_

#include <unordered_map>
#include <vector>
using namespace std;

unordered_map<size_t, double>
check_gradients(vector<double> coloring,
                unordered_map<size_t, unordered_map<size_t, double>> roles,
                unordered_map<size_t, unordered_map<size_t, double>> adjacency);
#endif // GRADIENT_CHECKER_H_
