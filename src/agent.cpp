#include "agent.hpp"
#include <ctime>
#include <xtensor/xmath.hpp>

double hamiltonian(double x, double y){return xt::cos(x - y)}

Potts::Potts() {
  this->state = 1.;
  this->beta = 1.;
}

Potts::Potts(Config &config) { this->beta = config.beta; }

void Potts::update() {
  double energy = 0;
  double proposal = this->rng.random_choice(this->states);
  for (auto &neighbor : this->adj.neighbors) {
    energy += neighbor.second * hamiltonian(this->state, neighbor.first.state)
  }

  double p = exp(-beta * energy);
  if (this->rng.rand() < p) {
    this->state = proposal;
  }
}
