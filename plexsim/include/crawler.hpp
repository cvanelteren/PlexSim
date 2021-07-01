#ifndef crawler_hpp
#define crawler_hpp
#include <cstddef>
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

  ColorNode current;
  ColorNode other;

  void print() const;
  // bool operator<(EdgeColor &other);
  // bool operator<=(EdgeColor &other);
  bool operator=(const EdgeColor &other) const;
};

bool operator<(const EdgeColor &current, const EdgeColor &other);
bool operator==(const EdgeColor &current, const EdgeColor &other);

class Crawler {
public:
  Crawler(size_t start, size_t bounded_rational);
  Crawler(size_t start, size_t bounded_rational, bool verbose);

  std::vector<EdgeColor> queue;
  std::set<EdgeColor> path;
  std::vector<std::set<EdgeColor>> results;
  std::vector<std::set<EdgeColor>> options;
  bool verbose;
  size_t bounded_rational;

  void merge_options();
  void add_result(std::set<EdgeColor>);
};

#endif
