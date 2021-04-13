#ifndef models_base
#define models_base

#include <math.h>

#include "xtensor-blas/xlinalg.hpp"
#include "xtensor-python/pyarray.hpp"
#include "xtensor/xarray.hpp"
#include "xtensor/xcomplex.hpp"
#include "xtensor/xindex_view.hpp"
#include "xtensor/xio.hpp"
#include "xtensor/xmath.hpp"
#include "xtensor/xrandom.hpp"
#include "xtensor/xstrided_view.hpp"

// should contain the atomic unit of computation
class Node {
  Node(id_t name);
  id_t name;
  void update();
};

typedef xt::xarray xar;
typedef std::unordered_map<size_t, Node> Nodes;

class NodeGraph : Node {
  NodeGraph(size_t node);
  std::vector<Node> neighbors;
};

class Models {

public:
  // props
  Nodes nodes;
  // funcs
  void update(xar<size_t> nodes);
  void reset();
};

#endif
