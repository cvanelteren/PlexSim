#ifndef models_base
#define models_base

#include "types.hpp"
#include <math.h>

#include "sampler.hpp"

// should contain the atomic unit of computation
// define crtp inheritance for node dynamics
template <typename node_base> class Node {
public:
  Node(id_t name);
  id_t name;
  void update();
};

// node class that operates on graphs
class NodeGraph : public Node<NodeGraph> {
public:
  NodeGraph(size_t node);
  std::vector<Node> neighbors;
};

// Node class with discrete dynamics
class NodeDiscrete : public Node<NodeDiscrete> {
  state_t agentStates;
  state_t state;
  Sampler rng;
};

// implement using composition
class Model {
public:
  Model(Config config);
  // props
  Nodes nodes;

  // funcs
  void update(xar<id_t> nodes);

  void reset();
};
#endif
