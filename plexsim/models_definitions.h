#include <iostream>
#include <math.h>
#include <complex>
#include <any>

#include <pybind11/stl.h>
#include <pybind11/pybind11.h>
#include <pybind11/numpy.h>
#include <pybind11/operators.h>

#include "randutils.hpp"
#define FORCE_IMPORT_ARRAY
#include "xtensor/xrandom.hpp"
#include "xtensor-python/pyarray.hpp"
#include "xtensor/xmath.hpp"
#include "xtensor/xcomplex.hpp"
#include "xtensor/xstrided_view.hpp"
#include "xtensor/xio.hpp"

#include "boost/unordered_map.hpp"

#include "parallel-hashmap/parallel_hashmap/phmap.h"
#include <ctime>
namespace py = pybind11;
using namespace pybind11::literals;
using namespace std;
using namespace boost;

// DEFINITIONS
// general model definitions
typedef xt::xarray<double> xarrd;
typedef size_t nodeID_t;
typedef int nodeState_t;
typedef float weight_t;
typedef xt::xarray<nodeState_t> nodeStates;
typedef std::vector<nodeState_t> agentStates_t;

typedef double foena_t;
typedef xt::xarray<foena_t> FOENA;


// sampling binding
typedef xt::xarray<nodeID_t> nodeids_a;

typedef  xt::xarray<nodeID_t> Nodeids;
// typedef std::array<nodeID_t> samples_t;

// Adjacency definition
// typedef boost::unordered_map<nodeID_t, weight_t> Neighbors;
typedef phmap::flat_hash_map<nodeID_t, weight_t> Neighbors;
struct Connection{
    Neighbors neighbors;
};


// typedef boost::unordered_map<nodeID_t, Connection> Connections;
typedef phmap::flat_hash_map<nodeID_t, Connection> Connections;



double PI =xt::numeric_constants<double>::PI ;
