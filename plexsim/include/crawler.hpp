#ifndef crawler_hpp
#define crawler_hpp

#include <algorithm>
#include <cstddef>
#include <iostream>
#include <set>
#include <vector>

// defines coloring of nodes
class ColorNode {
public:
  ColorNode();
  ColorNode(size_t name, double state);
  size_t name;
  float state;
};

// holds an edge in the value network
class EdgeColor {
public:
  EdgeColor();
  EdgeColor(ColorNode current, ColorNode other);
  EdgeColor(size_t name, size_t name_other, double name_state,
            double other_state);

  ColorNode current;
  ColorNode other;

  void print() const;
  bool operator=(const EdgeColor &other) const;
};

bool operator<(const EdgeColor &current, const EdgeColor &other);
bool operator==(const EdgeColor &current, const EdgeColor &other);

// general bool

class Crawler {
public:
  Crawler(size_t start, size_t bounded_rational);
  Crawler(size_t start, size_t bounded_rational, bool verbose);

  std::vector<EdgeColor> queue;
  std::vector<EdgeColor> path;

  std::vector<std::vector<EdgeColor>> results;
  std::vector<std::vector<EdgeColor>> options;

  bool verbose;
  size_t bounded_rational;

  void merge_options();
  bool in_path(EdgeColor);
  void add_result(std::vector<EdgeColor>);
};

#endif
