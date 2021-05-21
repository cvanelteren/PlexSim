#include "model.h"

Node::Node(id_t name) { this->name = name; };

DiscreteState::DiscreteState(py::dict config) {
  // how to deal with state initialization?
  this->agentStates = config.attr("get")("agentStates", state_t{0});
}

void Model::update(xar<id_t> nodes) {
  // loop through nodes and update them
  for (auto node : nodes) {
    this->nodes[node].update();
  }
}

ModelGraph::ModelGraph(py::dict config) {
  this->setup_adjacency(config.attr("get")("graph"));
}

adj_t ModelGraph::setup_adjacency(py::object graph) {
  // relabel nodes
  py::object nx = py::module::import("networkx");
  // graph = nx.attr("convert_node_labels_to_integers")(
  //     graph, "label_attribute"_a = "original");
  py::object nodelink = nx.attr("node_link_data")(graph);
  // fill adj
  adj_t this->adj = {};

  // setup loop for links
  id_t source, target;
  double weight;
  double defaultWeight = 1.;

  bool directed = py::bool_(nodelink["directed"]);

  // extract link information
  for (auto link : nodelink["links"]) {
    // extract data
    source = static_cast<id_t>(py::int_(link["source"]));
    target = static_cast<id_t>(py::int_(link["target"]));
    weight = static_cast<double>(
        py::float_(link.attr("get")("weight", defaultWeight)));

    // py::print(target, source, weight);

    // add target to source only
    this->adj[target].neighbors[source] = weight;
    if (!(directed)) {
      this->adj[source].neighbors[target] = weight;
    }
  };
}
// hide model
