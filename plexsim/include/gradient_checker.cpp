#include "gradient_checker.hpp"
#include <set>
unordered_map<size_t, double> check_gradients(
    vector<double> coloring,
    unordered_map<size_t, unordered_map<size_t, double>> roles,
    unordered_map<size_t, unordered_map<size_t, double>> adjacency) {

  unordered_map<size_t, double> heuristic;
  vector<double> neighbor_roles, role_neighbors, uni;
  vector<size_t> suff_connected;

  size_t role_degree;
  double node_color;
  for (auto &it : adjacency) {
    // clear buffers
    neighbor_roles.clear();
    role_neighbors.clear();
    uni.clear();

    node_color = coloring[it.first];

    // get the roles of the neighbors in the social graph
    for (auto &neighbor : it.second) {
      neighbor_roles.push_back(coloring[neighbor.first]);
    }

    // get the neighbors in the rule graph
    for (auto &neighbor : roles[node_color]) {
      if (neighbor.second.second > 0) {
        role_neighbors.push_back(neighbor.first);
      }
    }
    role_degree = roles[node_color].size();

    std::set_intersection(role_neighbors.begin(), role_neighbors.end(),
                          neighbor_roles.begin(), neighbor_roles.end(),
                          uni.begin());
    if (uni.size() == role_degree) {
      suff_connected.push_back(it.first);
    }
  }

  return heuristic;
};
