#ifndef value_edges_hpp
#define value_edges_hpp
#include <cstddef>

// defines coloring of nodes
class color_node {
public:
  size_t name;
  double state;
  // bool operator<(edge_t current, edge_t other);
};

// holds an edge in the value network
class edge_vn {
public:
  color_node current;
  color_node other;

  bool operator<(const edge_vn &other);
  // bool operator<(const edge_vn &current, const edge_vn &other);
  bool operator<=(const edge_vn &other);
  // bool operator<(const edge_vn &current, const edge_vn &other);
};

bool operator<(const edge_vn &current, const edge_vn &other);
#endif
