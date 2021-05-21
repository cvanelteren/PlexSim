#include "config.h"

Config::Config() {
  this->agentStates = state_t{0, 1};
  this->state = {0};
  this->t = 1;
}
