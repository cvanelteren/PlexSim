#include <iostream>
#include <pybind11/stl.h>
#include <pybind11/pybind11.h>
#include <ctime>
#include <random>

namespace py = pybind11;
using namespace pybind11::literals;
using namespace std;

// DEFINITIONS
// general model definitions
typedef int nodeID_t; 
typedef int nodeState_t;
typedef float weight_t;
typedef std::vector<nodeState_t> nodeStates;

// sampling binding
typedef std::vector<nodeID_t> samples_t;
// typedef std::array<nodeID_t> samples_t;

// Adjacency definition
typedef unordered_map<nodeID_t, weight_t> Neighbors;
struct Connection{
  Neighbors neighbors;
};
typedef unordered_map<nodeID_t, Connection> Connections;



