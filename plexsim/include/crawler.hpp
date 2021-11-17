#ifndef crawler_hpp
#define crawler_hpp

#include <algorithm>
#include <cstddef>
#include <iostream>
#include <set>
#include <vector>

// defines coloring of nodes
class ColorNode {
  /**
   *@brief Vertex node holding color and a name.
   **/
public:
  ColorNode();
  ColorNode(size_t name, double state);
  size_t name;
  float state;
};

class EdgeColor {
  /**@brief Edge holding color nodes.
   *
   * @details An edge consists  of two vertices. Each vertex
   * holds a color and a label
   **/
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
  /**
   * @brief  Crawler object
   *
   * @details  The crawler  object  traverses  a graph.  The
   * whole object merely holds solution. The actual model is
   * implemented  in cython.  The  Crawler  is a  convenient
   * storage  unit that  holds:  - the  current  path -  the
   * possible  option  as   branches  (y-structures)  -  the
   * solutions
   *
   * In addition,  it has a  few options that  manages these
   * structures,   e.g.   pruning   solutions   or   merging
   * options. */
public:
  Crawler(size_t start, double state, size_t bounded_rational, size_t heuristic,
          size_t path_size, bool verbose);
  // Crawler(size_t start, double state, size_t bounded_rational, bool verbose);

  std::vector<EdgeColor> queue;
  std::vector<EdgeColor> path;

  std::vector<std::vector<EdgeColor>> results;

  bool verbose;
  size_t bounded_rational;
  size_t heuristic;
  size_t path_size;

  // option merging
  // void merge_options();
  void merge_options(std::vector<std::vector<EdgeColor>> &options);

  void merge_options(std::vector<std::vector<EdgeColor>> &options,
                     std::vector<std::vector<EdgeColor>> &other_options);

  // bool merge_option(std::vector<EdgeColor>, std::vector<EdgeColor>,
  //                   std::vector<std::vector<EdgeColor>> *);

  uint8_t merge_option(size_t, size_t, std::vector<std::vector<EdgeColor>> &);

  // void check_options();

  // path
  bool in_path(EdgeColor);
  bool in_path(EdgeColor, std::vector<EdgeColor>);
  bool in_vpath(EdgeColor, std::vector<EdgeColor>);

  bool in_options(EdgeColor &option,
                  std::vector<std::vector<EdgeColor>> &options);

  bool in_options(std::vector<EdgeColor> &option,
                  std::vector<std::vector<EdgeColor>> &options, size_t target);

  void add_result(std::vector<EdgeColor>);
  void print(std::vector<std::vector<EdgeColor>> options);
  void print(std::vector<EdgeColor>);

  void print_results();
  void print_options(std::vector<std::vector<EdgeColor>> options);
  void print_path();

  template <typename C> bool check_size(C &path);
};

bool compare_edge_color(const EdgeColor &, const EdgeColor &);

size_t get_path_size(std::vector<EdgeColor> path);

#endif
