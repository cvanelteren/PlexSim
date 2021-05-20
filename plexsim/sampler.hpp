#ifndef sampler_hpp
#define sampler_hpp

#include "types.hpp"
#include <random>
// rng sample
class Sampler {
public:
  size_t seed;
  uniform_real_distribution dist;
  mt19937_64 gen;

  Sampler();
  Sampler(size_t seed);
  state_t sample_proposal(state_t states);
  double rand();
};
#endif
