#include "sampler.hpp"

Sampler::Sampler() {
  this->seed = time(NULL);
  xt::random::seed(this->seed);
}
void Sampler::set_seed(size_t seed) { this->seed = seed; }
double Sampler::rand() { return xt::random::rand(); }
