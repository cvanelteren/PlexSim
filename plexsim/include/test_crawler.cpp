
#include <algorithm>
#include <cstddef>
#include <iostream>
#include <set>
#include <stdio.h>

#include "crawler.hpp"
#include <set>
#include <unordered_set>
#include <vector>

EdgeColor make_ec(size_t name, double state, size_t other, double other_state) {
  return EdgeColor(ColorNode(name, state), ColorNode(other, other_state));
}

int test_merge_separate() {
  printf("Testing merge_separate\n");
  auto crawler = Crawler(0, 0.0, 10, true);

  std::vector<std::vector<EdgeColor>> x1 = {{make_ec(0, 0., 1, 1.)}};

  std::vector<std::vector<EdgeColor>> x2 = {{make_ec(3, 0., 4, 1.)}};

  std::set<EdgeColor> o;
  std::set_union(x1[0].begin(), x1[0].end(), x2[0].begin(), x2[0].end(),
                 std::inserter(o, o.begin()), compare_edge_color);
  printf("O =%d\n", o.size());
  printf("x1 \t %d x2 \t %d\n", x1.size(), x2.size());

  crawler.merge_options(x1, x2);

  printf("After merge size x1=%d\n", x1.size());
  printf("After merge size x2=%d\n", x2.size());
  if (x1.size() == 2)
    return 0;
  else
    return 1;
}

int test_no_merge() {
  printf("Testing no_merge\n");
  auto crawler = Crawler(0, 0.0, 10, true);

  std::vector<std::vector<EdgeColor>> x1 = {{make_ec(0, 0., 1, 1.)}};

  std::vector<std::vector<EdgeColor>> x2 = {{make_ec(1, 0., 2, 1.)}};
  printf("x1 \t %d x2 \t %d\n", x1.size(), x2.size());

  crawler.merge_options(x1, x2);

  printf("After merge size x1=%d\n", x1.size());
  printf("After merge size x2=%d\n", x2.size());

  if (x1.size() == 2)
    return 0;
  else
    return 1;
}

int test_merge() {
  printf("Testing merge\n");
  auto crawler = Crawler(0, 0., 10, true);

  std::vector<std::vector<EdgeColor>> x1 = {{make_ec(0, 0., 1, 1.)}};

  std::vector<std::vector<EdgeColor>> x2 = {{make_ec(1, 1., 2, 2.)}};

  printf("x1 \t %d x2 \t %d\n", x1.size(), x2.size());

  crawler.merge_options(x1, x2);

  printf("After merge size x1=%d\n", x1.size());
  printf("After merge size x2=%d\n", x2.size());

  if (x1.size() == 3)
    return 0;
  else
    return 1;
}

int test_triple_merge() {
  printf("Testing triple merge\n");
  auto crawler = Crawler(0, 0., 10, true);

  std::vector<std::vector<EdgeColor>> x1 = {{make_ec(0, 0., 1, 1.)}};

  std::vector<std::vector<EdgeColor>> x2 = {{make_ec(1, 1., 2, 2.)},
                                            {make_ec(2, 2., 3, 3.)}};

  printf("x1 \t %d x2 \t %d\n", x1.size(), x2.size());

  crawler.merge_options(x1, x2);

  printf("After merge size x1=%d\n", x1.size());
  printf("After merge size x2=%d\n", x2.size());

  if (x1.size() == 7)
    return 0;
  else
    return 1;
}

int main() {

  int x;

  // 1
  x = test_merge_separate();
  (x ? printf("Fail \n") : printf("Succes\n"));
  // 2
  x = test_no_merge();
  (x ? printf("Fail \n") : printf("Succes\n"));

  // 3
  x = test_merge();
  (x ? printf("Fail \n") : printf("Succes\n"));
  // 4
  x = test_triple_merge();
  (x ? printf("Fail \n") : printf("Succes\n"));
  // std::set<int> a = {1, 1, 1};
  // std::set<int> b = {1, 2, 3};
  // std::set<int> c;
  // std::set<int> d;
}
