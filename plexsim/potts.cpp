#include "potts.hpp"

#include "xtensor/xmath.hpp"

double hamiltonian(state_t x, state_t y) { return xt::cos(x - y); };

PottsNode::PottsNode(id_t name, py::dict config)
    : public Node<PottsNode>(name) {
  // init random sampler
  this->rng = Sampler();
  // initialize state
  this->dynamic = DiscreteState(config);
  this->reset();

  this->t = config.attr("get")("t", 1);
  this->beta = 1 / this->t;

  // TODO: cant add array -> fix this with id?
  this->H = config.attr("get")("H", 0);
}

// PottsNode::PottsNode(Config config) : public PottsNode() {
//   this->dynamic = config->discrete;
//   this->t = config->t;
//   this->beta = 1 / this->t;
//   this->h = 0;
//   // Sampler *rng;
// }

double PottsNode::get_energy(state_t state) {
  double energy = 0;
  for (auto neighbor : this->adj.neighbors) {
    energy -= hamiltonian(state, neighbor->dynamic.state);
  }
  return energy;
}

void PottsNode::update() {
  // sample proposal
  state_t proposal = this->sample_proposal();
  // compute difference in energy
  double energy = this->get_energy(this->dynamic.state);
  double energy_prop = this->get_energy(proposal);
  double p = xt::exp(this->beta * (energy_prop - energy));

  // do MCMC step
  if (this->rng->rand() < p) {
    this->dynamic.state = proposal;
  }
  return;
}

state_t PottsNode::sample_proposal() {
  auto idx =
      static_cast<size_t>(this->rng->rand() * this->dynamic.agentStates.size());
  return this->dynamic.agentStates[idx];
}

PottsNode::reset() { this->dynamic.state = this->sample_proposal(); }

// Potts
Potts::Potts(py::dict config) : public ModelGraph<Potts>(config) {
  // setup adjacency for all nodes
  PottsNode node;

  // reset dict
  this->nodes = {};

  for (auto key_value : this->adj) {
    node = PottsNode(key_value->first, config);
    node.neighbors = key_value->second;
    // init random state for node
    node.reset();
    // setup node
    this->nodes[key_value->first] = node;

    // setup state vectors for convenience
    this->state.push_back(&node.dynamic.state);
    this->new_state.push_back(&node.dynamic.state);
  }
}
