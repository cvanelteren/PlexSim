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
  // EdgeColor(const EdgeColor &);
  EdgeColor(size_t name, size_t name_other, double name_state,
            double other_state);

  ColorNode current;
  ColorNode other;

  void print() const;
  EdgeColor sort();

  bool operator=(const EdgeColor &other) const;
};

bool operator<(const EdgeColor &current, const EdgeColor &other);
bool operator==(const EdgeColor &current, const EdgeColor &other);

// general bool

class Crawler {
public:
  Crawler(size_t start, double state, size_t bounded_rational);
  Crawler(size_t start, double state, size_t bounded_rational, bool verbose);

  std::vector<EdgeColor> queue;
  std::vector<EdgeColor> path;

  std::vector<std::vector<EdgeColor>> results;
  // std::set<std::set<EdgeColor>> results;
  std::vector<std::vector<EdgeColor>> options;

  bool verbose;
  size_t bounded_rational;

  // option merging
  void merge_options();
  bool merge_option(std::vector<EdgeColor>, std::vector<EdgeColor>,
                    std::vector<std::vector<EdgeColor>> *);
  void check_options();

  // path
  bool in_path(EdgeColor);
  bool in_path(EdgeColor, std::vector<EdgeColor>);

  bool in_options(EdgeColor option);

  void add_result(std::vector<EdgeColor>);
  void print();
  void print(std::vector<EdgeColor>);
};

#endif
