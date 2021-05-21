#ifndef potts_hpp
#define potts_hpp

#include "config.hpp"
#include "model.hpp"
#include "sampler.hpp"
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
  std::vector<Node<T>> neighbors;

  // funcs
  PottsNode(Config config);
  double get_energy(state_t);
  void reset();
  state_t sample_proposal();
};

class Potts : public Model<Potts> {
public:
  std::vector<*state_t> state;
  std::vector<*state_t> new_state;

  Potts::Potts(py::dict config);
  void update(xar<id_t> nodes);
}
#endif
