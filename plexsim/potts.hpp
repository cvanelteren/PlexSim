#ifndef potts_hpp
#define potts_hpp

#include "config.hpp"
#include "model.hpp"
#include "types.hpp"

// helper functions
double hamiltonian(state_t x, state_t y);

class PottsNode : public Node<PottsNode> {
public:
  // temperature
  double t;
  // inverse temperature
  double beta;
  // external magnetic field
  double H;
  // random number generator
  Sampler *rng;

  // discrete states
  DiscreteState dynamic;
  Adjacency adj;

  // funcs
  PottsNode();
  PottsNode(Config config);
  double get_energy(state_t);
};
#endif
