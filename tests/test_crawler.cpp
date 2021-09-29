
#include <algorithm>
#include <cstddef>
#include <iostream>
#include <set>
#include <stdint.h>
#include <stdio.h>

#include "../plexsim/include/crawler.hpp"
#include <set>
#include <unordered_set>
#include <vector>

std::vector<std::vector<EdgeColor>> create_n_edge_colors(size_t n,
                                                         size_t offset = 0) {
  std::vector<std::vector<EdgeColor>> output;

  auto tmp = std::vector<EdgeColor>(n);

  ColorNode x, y;
  for (auto idx = 1; idx < n; idx++) {
    x = ColorNode(idx + offset, (double)(idx + offset));
    y = ColorNode(idx - 1 + offset, (double)(idx - 1 + offset));
    tmp[idx] = EdgeColor(x, y);
  }
  output.push_back(tmp);
  return output;
};
int main() {

  size_t start, bounded_rational, heuristic;
  double state;

  // starting node
  start = 0;
  bounded_rational = 1;
  heuristic = 1;
  state = 0.0;
  printf("Hello\n");
  Crawler crawler(start, state, bounded_rational, heuristic, false);

  auto options = create_n_edge_colors(10, 0);
  crawler.merge_options(options, options);

  for (auto idx = 0; idx < 100; idx++) {
    auto options = create_n_edge_colors(10, 0);
    crawler.merge_options(options, options);
  }
}
