#include "sampler.hpp"
#include <time.h>

Sampler::Sampler() {
  this->dist = uniform_real_distribution<double>(0.0, 1.0);
  // use time as default seed
  struct timespec ts;
  this->seed = clock_gettime(CLOCK_REALTIME, ts.tv_sec);
  this->gen = mt19937(this->seed);
}

Sampler::Sampler(size_t seed) : Sampler::Sampler() {
  if (seed >= 0) {
    this->seed;
    this->gen = mt19937(this->seed);
  }
}

double Sampler::rand() { return this->dist(this->gen); }
