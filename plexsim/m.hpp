#ifndef models_base
#define models_base

#include "types.hpp"
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
// define crtp inheritance for node dynamics
template <typename node_base> class Node {
public:
  Node(id_t name);
  id_t name;
  void update();
};

typedef xt::xarray xar;
typedef std::unordered_map<size_t, Node> Nodes;

class NodeGraph : public Node<NodeGraph> {
public:
  NodeGraph(size_t node);
  std::vector<Node> neighbors;
};

// implement using composition
class Model {
public:
  // props
  Nodes nodes;

  // funcs
  void update(xar<size_t> nodes);

  void reset();
};

#endif
