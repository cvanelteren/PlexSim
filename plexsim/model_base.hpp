#ifndef models_base
#define model_base
#include <any>
#include <complex>
#include <iostream>
#include <math.h>
#include <string>
#include <unordered_map>

#include "randutils.hpp"
#define FORCE_IMPORT_ARRAY
#include "xtensor-blas/xlinalg.hpp"
#include "xtensor-python/pyarray.hpp"
#include "xtensor/xarray.hpp"
#include "xtensor/xcomplex.hpp"
#include "xtensor/xindex_view.hpp"
#include "xtensor/xio.hpp"
#include "xtensor/xmath.hpp"
#include "xtensor/xrandom.hpp"
#include "xtensor/xstrided_view.hpp"

#include "parallel-hashmap/parallel_hashmap/phmap.h"
#include "robin-map/include/tsl/robin_map.h"
#include "sparse-map/include/tsl/sparse_map.h"
// #include "Xoshiro-cpp/XoshiroCpp.hpp"
#define PHMAP_USE_ABSL_HASH

#include <ctime>

#include "kwargs.h"

// base node mode should be able to update
class Node {
  Node(char name);
  char name;
  void update();
};

// graph based modeling
class NodeGraph : Node {
  NodeGraph(char name);
  unordered_map<Node, double> neighbors;
};

struct Settings {};

class Model {
  Model(kwargs);
  vector<Node> nodes;
  size_t sample_size;
  void update();
};

#endif
