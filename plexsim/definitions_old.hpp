#include <iostream>
#include <pybind11/stl.h>
#include <pybind11/pybind11.h>
#include <pybind11/numpy.h>

#define FORCE_IMPORT_ARRAY
#include "xtensor/xrandom.hpp"
#include "xtensor-python/pyarray.hpp"
#include "xtensor-python/pycontainer.hpp"

#include <random>
#include <ctime>
namespace py = pybind11;
using namespace pybind11::literals;
using namespace std;

// DEFINITIONS
// general model definitions
typedef int nodeID_t; 
typedef int nodeState_t;
typedef float weight_t;
typedef xt::xarray<nodeState_t> nodeStates;
typedef std::vector<long> agentStates_t;

// sampling binding
typedef xt::xarray<nodeID_t> samples_t;
// typedef std::array<nodeID_t> samples_t;

// Adjacency definition
typedef unordered_map<nodeID_t, weight_t> Neighbors;
struct Connection{
    Neighbors neighbors;
};
typedef unordered_map<nodeID_t, Connection> Connections;
