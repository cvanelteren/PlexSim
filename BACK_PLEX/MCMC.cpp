#include "data_types.hpp"
#include "MCMC.h"
#include "mt19937.h"
#include "randutils.hpp"

using namespace std;


class  MCMC{
  public:
  unsigned long seed;
  double rand();

  double sample_proposal(vector<double> proposal_states);
  double sample_proposal(vector<double> proposal_states, \
                         std::vector<double> p );



  private:
  randutils::mt19937_rng rng;

  // mt19937 _gen
  // std::uniform_real_distribution<double> _dist

  //init_model

  MCMC(){
  }

  // MCMC(unsigned long seed){
  //   this->seed  = seed;
  //   this->_gen  = mt19937(seed);
  //   this->_dist = std::unifrom_real_distribution<double>(0.0, 1.0);
  // }

}


// double MCMC::rand(){
//   return this->._dist(this->_gen);
// }
