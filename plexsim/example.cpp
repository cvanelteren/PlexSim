#include <pybind11/pybind11.h>
#include <iostream>
#include <map>
namespace py = pybind11;
using namespace pybind11::literals;

py::object nx = py::module::import("networkx");



typedef double weight_t;
typedef int nodeId_t;

struct Connection{
  unordered_map[nodeId_t, weight_t] Neighbors;
};

typedef unordered_map[nodeId_t, Connection] Adj;


int load_graph(py::object g){
  py::dict nodes = nx.attr("node_link_data")(g);
  Adj adj
  for (auto item : nodes["nodes"]){
    py::print(item["id"]);
  };

  for ( auto item : nodes["links"]){
    py::print(item);
  };
  return 2;
};

PYBIND11_MODULE(example, m){
  m.def("lg", &load_graph);
}
