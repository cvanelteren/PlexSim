/*
 AUTHOR: Casper van Elteren
*/

#include "models_definitions.h" // includes all defintions used here

struct pair_hash {
   template <class T1, class T2>
   std::size_t operator () (const std::pair<T1,T2> &p) const {
       auto h1 = std::hash<T1>{}(p.first);
       auto h2 = std::hash<T2>{}(p.second);
  return h1 ^ h2;
    }
  };


// class RandomGenerator{
// :
//     double rand();

//   private:
//     randutils::mt19937_rng rng;

//     // mt19937 gen;
//     // size_t seed;
//     // uniform_real_distribution[double] dist;

// };

// class MCMC{
//   public:
//     void recombinations(nodeids_a nodeids, Model* ptr);
//   private:
//     double p_recomb;
//     RandomGenerator rng;
// };


template<typename T>
class Property{
public:
  virtual ~Property(){}
  virtual Property& operator= (const T& f){ value = f; return *this;}
  virtual const T& operator () () const {return value;}
  virtual explicit operator const T& () const {return value;}
  virtual T* operator->() {return &value;}
protected:
  T value;
};

class Adjacency{
    public:
    Connections adj;
    nodeids_a nodeids;
    size_t nNodes;
    py::object graph;

  Adjacency() {} ;
  Adjacency(py::object graph){
    // relabel nodes
    py::object nx = py::module::import("networkx");
    graph = nx.attr("convert_node_labels_to_integers")(graph,\
                              "label_attribute"_a = "original");

    py::object nodelink = nx.attr("node_link_data")(graph);
   // fill adj
    this->adj = Connections();

//setup loop for links
    nodeID_t source, target;
    weight_t weight;
    weight_t defaultWeight = weight_t(1.);
    bool directed = py::bool_(nodelink["directed"]);

    // extract link information
    for (auto link : nodelink["links"]){
      // extract data
      source = static_cast<nodeID_t>(py::int_(link["source"]));
      target = static_cast<nodeID_t> (py::int_(link["target"]));
      weight = static_cast<weight_t> (py::float_(link.attr("get")("weight", defaultWeight)));
      // py::print(target, source, weight);

       // add target to source only
       this->adj[target].neighbors[source] = weight;
       if (!(directed)){
           this->adj[source].neighbors[target] = weight;
       }
    };
    // hide model
    this-> graph = graph;
    this-> nNodes = py::int_(graph.attr("number_of_nodes")());
    this->nodeids = xt::arange(this->nNodes);
    return ;
  }

  const Neighbors& operator[](nodeID_t node){
    return this->adj[node].neighbors; };

 };

class States {
    public:
        FOENA agentStates;
        xt::xarray< foena_t> _states;
        foena_t *states;
        foena_t *newstates;

        States() {};
        States(FOENA agentStates, size_t nNodes){
            this->_states = FOENA({2, nNodes});
            //create pointer to current state
            this->states    = &this->_states[0];
            this->newstates = &this->_states[1];

            // randomize the states
            this->reset();

            this->_states[1]  = this->_states[0];
            this->agentStates = agentStates;


        }

    void reset(){
      for (auto node = 0 ; node < this->_states.shape(1); node++){
            std::cout << xt::random::choice(agentStates, 1);
            // this->states[node] = xt::random::choice(agentStates, 1)[0];
        }
    }

    void swap(){
      // clean-up after update loop
      std::swap(this->states, this->newstates);
    }

  };
template<typename IMPL>
class Model{
public:
    FOENA states;
    FOENA newstates;
    // agentStates_t agentStates;
    FOENA agentStates; // discrete container

    size_t sampleSize;

    Adjacency adj;
    randutils::mt19937_rng rng;
    // XoshiroCpp::Xoshiro256Plus eng;
    // States states;


  class updateProperty: public Property <string> {
    public:
        virtual updateProperty& operator = (const string &f){
            if (f == "async"){
                    // Model::newstates; // = Model::states;
                        value = f;
                }
                else if (f == "sync"){
                    // Model::newstates = Model::states;
                    value = f;
                }
                return *this;
            }
        };

  // nudge property
 // TODO: make this separate class
  class nudgeProperty : public Property <string> {
    public:
        virtual nudgeProperty& operator= (const string &f){
            if (f == "constant")
                { value = f; }
            else if (f == "pulse")
                { value = f; }
            else
                { value = "constant"; }
            return *this;
            }
        };

  Model(
        py::object graph,
        FOENA agentStates,
        // agentStates_t agentStates,
        size_t sampleSize
        ){
             this->adj         = Adjacency(graph);
             this->agentStates = agentStates;
             // this->states   = States(agentStates, this->adj.nNodes);
             this->states      = FOENA::from_shape({this->adj.nNodes});
             this->newstates   = FOENA::from_shape({this->adj.nNodes});

            for (auto node = 0 ; node < this->adj.nNodes; node++){
                // std::cout << xt::random::choice(agentStates, 1);
                // this->states[node] = xt::random::choice(agentStates, 1);
                this->states[node] = this->rng.pick(agentStates);
                this->newstates[node] = this->states[node];
            }
            this->sampleSize = ( sampleSize == 0 ? this->adj.nNodes : sampleSize);
            return;
    }

    FOENA updateState(nodeids_a nodes){
        // down cast derived model
       #pragma omp simd
        for (const auto& node: nodes){
          static_cast<IMPL&>(*this).step(node);
        }
        this->swap_buffers();
        return this->states;
    }

    void swap_buffers(){
      std::swap(this->states, this->newstates);
      // this->states.swap();
    }

    nodeids_a sampleNodes(size_t nSamples){
       auto sampleSize   = this->sampleSize;
       auto nNodes       = this->adj.nNodes;
       // samples samples = this->samples;
       // samples.resize(nSamples * sampleSize);
       auto N   = nSamples * sampleSize;
       auto nodes  = nodeids_a::from_shape({N});

       auto tmp = 0;
       auto nodeids = this->adj.nodeids ;

       // size_t j;
       #pragma omp simd
       for (auto samplei = 0; samplei < N; samplei++){
           tmp = samplei % nNodes;
           if (!(tmp)){
             // xt::random::shuffle(nodeids, this->eng);
             this->rng.shuffle(nodeids);
         }
         // assign to sample
         nodes[samplei] = nodeids[tmp];
         // xt::view(nodes, samplei) = nodeids[tmp];
       }
    // return nodes;
    return xt::reshape_view(nodes, {nSamples, sampleSize});
  }

    FOENA  simulate(size_t nSamples){
        FOENA results = FOENA::from_shape({nSamples, this->adj.nNodes});
        nodeids_a nodes = this->sampleNodes(nSamples);

        this->updateState(xt::view(nodes, 0));
        #pragma omp simd
        for (auto samplei = 1; samplei < nSamples - 1; samplei++){
            xt::view(results, samplei) = this->updateState(xt::view(nodes,  samplei));
            }
        return results;
    }
 // private:
  // IMPL& impl_ = static_cast<IMPL&>(*this);

  // IMPL& impl(){
  //   return *static_cast<IMPL*>(this) ;}

};


class MCMC{
  public:

  double p_recombination;


  void recombination(nodeids_a nodes, Model<auto>* ptr){
    double numerator, denominator;
    nodeID_t node1, node2;
    foena_t state1, state2;
    //shuffle the nodes
    xt::random::shuffle(nodes);

    auto rng = xt::random::rand<double>({nodes.size() / 2}, 0., 1.);
    for (auto idx = 1; idx < nodes.size() ; idx+=2){
      // obtain random pair
      node1 = nodes[idx];
      node2 = nodes[idx - 1];

      // obtain their states
      state1 = ptr.states[node1];
      state2 = ptr.states[node2];

      // compute the probability of a swap
      denominator = ptr.step(state1, node1)  * ptr.step(state2, node2);
      numerator   = ptr.step(state2, node1)  * ptr.step(state1, node2);

      if (rng[idx] < numerator / denominator){
        ptr.newstates[node1] = state2;
        ptr.newstates[node2] = state1;
      }
      else{
        ptr.newstates[node1] = state1;
        ptr.newstates[node2] = state2;
      }

      return ;
    }
  }


  void gibbs(nodeids_a nodes, Model<auto>* ptr){
    double p, p_current, p_proposal;
    foena_t currentState, proposalState;
    for (const auto& node : nodes){
      currentState  = ptr.states[node];
      proposalState = this->sample_proposal(ptr);

      p_proposal = ptr.step(proposalState, node);
      p_current  = ptr.step(currentState, node);
      p          = p_proposal / p_current;

      if (xt::random::rand<double>({1})[0] < p){
        ptr.states[node] = proposalState;
      }

    }
    return ;
  }

  foena_t sample_proposal(Model<auto>* ptr);

  MCMC(double p_recombination = 1.){
      this->p_recombination = p_recombination;
  }
};


// auto key_selector = [](auto pair){ return pair.first ; };
// auto value_selector = [](auto pair){ return pair.second ; };

//TODO: There is someothing going wrong with a caster of xtensor with this model
// The u-fvisibility-inlines-hiddenp-down casting seems to work fine and the binding requires less boiler plate code
class Potts: public Model<Potts>{

    // friend class Model_<Potts_>;
    class Temperature: public Property <double>{
        public:
            double beta;
            virtual Temperature& operator= (double & t){
                beta = (t == 0 ? std::numeric_limits<double>::infinity() : 1 / t);
                value = t;
                return *this;
            }
    };

  public:
    Temperature t;
    // using Model_<Potts_>::Model_;

    Potts(
           py::object graph,
           FOENA agentStates = FOENA({0, 1}),
           size_t sampleSize = 0,
           double t          = 1.) : Model( graph = graph, agentStates = agentStates,
                                             sampleSize = sampleSize){
      this->t = t;
    };


    void step(nodeID_t node){
       auto  proposal            = this->rng.pick(this->agentStates);
       double energy             = this->energy(node, proposal);
       energy                   += this->energy(node, proposal);

        // for (const auto& neighbor : this->adj[node]){
        //     energy += neighbor.second *
        //         this->hamiltonian(proposal, this->states[neighbor.first]);

        //     energy += neighbor.second *
        //         this->hamiltonian(proposal, this->states[neighbor.first]);
        // }
       auto delta                = xt::xarray<double>{this->t.beta * energy};
       auto p                    = xt::exp(- delta);
       // xt::random::rand({1}, 0., 1.);
       // if ((xt::random::rand({1}, 0., 1.)[0] < p[0])){
       if ((this->rng.uniform(0., 1.) < p[0]) || (xt::isnan(p)[0])){
           this->newstates[node] = proposal;
       }
       return ;
    }


    inline double energy(nodeID_t node, foena_t proposal){
       double energy = 0;
        for (const auto& neighbor : this->adj[node]){
            energy += neighbor.second *
                this->hamiltonian(proposal, this->states[neighbor.first]);
        }
        return energy;
    }

    double hamiltonian(foena_t x, foena_t y){
            double z = double(this->agentStates.size());
            double delta = 2. * PI * (x - y) / z;
            return cos(delta);
        }

    double rand(size_t n ){
        for (auto i = 0 ; i < n ; i++){
            this->rng.uniform(0., 1.);
        }
        return 0.;
    }

};




PYBIND11_MODULE(example, m){
    xt::import_numpy();
    py::class_<Potts>(m, "Potts")
      .def(py::init<
           py::object,
           xt::pyarray<double>,
           size_t,
           double
           >(),
           "graph"_a,
           "agentStates"_a = FOENA({0, 1}),
           "sampleSize"_a = 0,
           "t"_a = 1.)
      .def("simulate", &Potts::simulate)
      .def("sampleNodes", &Potts::sampleNodes)
      .def_property("agentStates",
                    [](const Potts& self){ return self.agentStates; },
                    [](const Potts & self) {})
      .def_property("graph",
            [] (const Potts & self){return self.adj.graph;},
            [](const Potts & self){})
      .def("rand", &Potts::rand)

      ;


};



// int main(){
//     std::cout<< "testin";
//     std::cout << "test";
//     FOENA agentStates = FOENA({0, 1});
//     py::object nx = py::module::import( "networkx" );
//     py::object g  = nx.attr("path_graph")(10);
//     std::cout << "test";
//     size_t n = 1000;
//     auto  m = PottsFast(g);
//     m.simulate(n);
//     auto M = Potts_(g);
//     M.simulate(n);
//     auto N = Potts(g);
//     N.simulate(n);
// };


// Local variables:
// rmsbolt-command: "\
// g++ \
//     -I/usr/include/python3.8/  \
//     -I/home/casper/miniconda3/lib/python3.8/site-packages/numpy/core/include \
//     -I/home/casper/miniconda3/include\
// "
// rmsbolt-disassemble: nil
// End:
