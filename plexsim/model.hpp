#ifndef models_base
#define models_base

#include "sampler.hpp"
#include "types.hpp"
#include <math.h>

#include <pybind11.h>

using namespace pybind11::literals;

// TODO remove the CRTP here for composition
// should contain the atomic unit of computation
// define crtp inheritance for node dynamics
template <class T> class Node {
public:
  Node(id_t name);
  id_t name;
  void update();
};

// node class that operates on graphs
class Adjacency {
public:
  std::vector<Node<T>> neighbors;
};

// Node class with discrete dynamics
class DiscreteState {
public:
  state_t agentStates;
  state_t state;
  // Sampler *rng;
  // DiscreteState(Config config);
  // python compatibility
  DiscreteState(py::dict config);
};

// implement using composition
template <class T> class Model {
public:
  // Model(py::dict config);

  // Model(Config config);
  // props
  Nodes nodes;

  // funcs
  void update(xar<id_t> nodes);
  void setup_nodes();
  void reset();
};

template <class T> class ModelGraph : public Model<T> {
public:
  // helper function
  adj_t adj;
  void setup_adjacency(py::object graph);
};

#endif
