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
class Model_{
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

  Model_(
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


auto key_selector = [](auto pair){ return pair.first ; };
auto value_selector = [](auto pair){ return pair.second ; };
//TODO: There is someothing going wrong with a caster of xtensor with this model
// The u-fvisibility-inlines-hiddenp-down casting seems to work fine and the binding requires less boiler plate code
class Potts_: public Model_<Potts_>{

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

    Potts_(
           py::object graph,
           FOENA agentStates = FOENA({0, 1}),
           size_t sampleSize = 0,
           double t          = 1.) : Model_( graph = graph, agentStates = agentStates,
                                             sampleSize = sampleSize){
      this->t = t;
    };


    void step(nodeID_t node){
       // nodeState_t state     = this->states[node];
       auto  proposal = this->rng.pick(this->agentStates);
       double energy = 0;
        for (const auto& neighbor : this->adj[node]){
            energy += neighbor.second *
                this->hamiltonian(proposal, this->states[neighbor.first]);
            energy += neighbor.second * this->hamiltonian(this->states[node], this->states[neighbor.first]);
        }

       auto delta = xt::xarray<double>{this->t.beta * energy};
       auto p     = xt::exp(- delta);
       // xt::random::rand({1}, 0., 1.);
       // if ((xt::random::rand({1}, 0., 1.)[0] < p[0])){
       if ((this->rng.uniform(0., 1.) < p[0]) || (xt::isnan(p)[0])){
           this->newstates[node] = proposal;
       }
       return ;
    };

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


// CLASS IMPLEMENTATION
// use template for the node state type ?
class Model{
public:
    Connections adj; // adjecency
    py::object graph; // stash nx object inside the class


    size_t sampleSize;
    size_t nNodes;

    size_t nStates;
    randutils::mt19937_rng rng;
    FOENA states;
    FOENA newstates;

    agentStates_t agentStates;

    bool write ;
    xt::xarray<nodeID_t> nodeids;


  // updateProperty
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

  nudgeProperty nudgeType;
  updateProperty updateType;

  // constructor
  Model(
        py::object graph,                     \
        agentStates_t  agentStates = agentStates_t(0,1 ),  \
        string nudgeType       = "constant",\
        string updateType      = "async",\
        size_t sampleSize      = 0
        ) {

      // setup seed
      // std::time_t ts = std::time(nullptr);
      // if (seed < 0 ){
      //    this->_gen  = std::mt19937_64(0);
      //}
      //else {
      //    this -> _gen = std::mt19937_64(seed);
      //}
      //this->_dist = std::uniform_real_distribution<double>(0., 1.);
      // create adj
      create_adj(graph);

      // setup properties
      this->sampleSize   = sampleSize;
      this->nudgeType    = nudgeType;
      this->updateType   = updateType;
      this->agentStates  = agentStates;
      this->nStates      = agentStates.size();

      this->sampleSize   = (sampleSize == 0 ? this->nNodes : sampleSize);

      this->write = false;
      // setup buffers
      // this->states     = nodeStates({this->nNodes} );
      // xt::xarray<int>tmp = xt::arange(0, 5);
      // xt::random::choice(tmp, 1, false);
      // this->states  = xt::random::choice(agentStates, 1);
      // this->states  = xt::zeros<nodeState_t>({this->nNodes}) ;
      this->states = xt::zeros<nodeState_t>({this->nNodes});
      for (auto node = 0 ; node < this->nNodes; node++){
          this->states[node] = static_cast<foena_t>(this->rng.pick(agentStates));
      }
      this->newstates  = this->states;

    // this->newstates  = nodeStates({this->nNodes});
  }
  virtual ~Model()  = default;


  void create_adj(py::object graph) {

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
       //
       this->adj[target].neighbors[source] = weight;
       if (!(directed)){
           this->adj[source].neighbors[target] = weight;
       }
    };
    // hide model
    this-> graph = graph;
    this-> nNodes = static_cast <unsigned int>(py::int_(graph.attr("number_of_nodes")()));

    this->nodeids = xt::arange(this->nNodes);
    return ;
  }
    //double rand(){
    //  return this->_dist(this->_gen);
    //}

    nodeids_a sampleNodes(size_t nSamples){

       auto sampleSize   = this->sampleSize;
       auto nNodes                = this->nNodes;
       // samples samples = this->samples;
       // samples.resize(nSamples * sampleSize);
       auto N   = nSamples * sampleSize;
       auto nodes  = nodeids_a::from_shape({N});

       size_t tmp;
       auto& nodeids = this->nodeids ;

       size_t j;
       for (auto samplei = 0; samplei < N; samplei++){
         // shuffle the node ids

           // tmp = samplei & (nNodes - 1);
           tmp = samplei % nNodes;
           if (!(tmp)){
             this->rng.shuffle(nodeids);
         }
         // assign to sample
         xt::view(nodes, samplei) = nodeids[tmp];
       }
       return xt::reshape_view(nodes, {nSamples, sampleSize});
  }


  double rand(size_t n ){
    for (auto i = 0 ; i < n ; i++){
        this->rng.uniform(0., 1.);
    }
    return 0.;
  }


  // double rand(long N){
  //     this->rng.uniform(0., 1.);
  // }

    // Implement per model
  FOENA  updateState(nodeids_a nodes){
        /*
          Node update loop
        */

       for (const auto & node : nodes){
           this->step(node);
       }
        // nodeStates& tmp = this->newstates;
        this->swap_buffers();
        this->write = (this->write ? false : true);
        return this->states;

    }
    //implement inherited class
    virtual void step(nodeID_t node_id)  = 0;

    virtual void swap_buffers(){
        std::swap(this->states, this->newstates);
     }

    FOENA  simulate(unsigned int nSamples){
        auto results = FOENA::from_shape({nSamples, this->nNodes});
        auto nodes = this->sampleNodes(nSamples);
        for (size_t samplei = 0 ; samplei < nSamples; samplei++){
          // results[samplei] = this->updateState(nodes[samplei])
            xt::view(results, samplei) = this->updateState(xt::view(nodes, samplei));
        }
        return results;
    }



private:
  // std::mt19937_64 _gen; // RNG generator
  // std::uniform_real_distribution<double> _dist;
  // randutils::mt199337_rng rng;


  // buffers to write updates to
};

class Potts: public Model{
public:

    class Temperature: public Property <double>{
    public:
        double beta;
        virtual Temperature& operator= (double & t){
            beta = (t == 0 ? std::numeric_limits<double>::infinity() : 1 / t);
            value = t;
            return *this;
        }
    };

    Temperature t;

    Potts(\
     py::object graph,                               \
     agentStates_t  agentStates = agentStates_t(1, 0), \
     double t                   = 1,\
     string nudgeType           = "constant",\
     string updateType          = "async",\
     size_t sampleSize          = 0 \
          ): Model(
                graph,
                agentStates,
                nudgeType,
                updateType,
                sampleSize){
        this->t = t;

    };

   void step(nodeID_t node){

       auto  proposal = this->rng.pick(this->agentStates);
       double energy = 0;

        for (const auto& neighbor : this->adj[node].neighbors){
          energy += neighbor.second *
             this->hamiltonian(proposal, this->states[neighbor.first]);
                 }

       auto delta = xt::xarray<double>{this->t.beta *energy};
       auto p     = xt::exp(- delta);
       // xt::random::rand({1}, 0., 1.);
       // if ((xt::random::rand({1}, 0., 1.)[0] < p[0])){
       if ((this->rng.uniform(0., 1.) < p[0]) || (xt::isnan(p)[0])){
           this->newstates[node] = proposal;
       }
       return ;
    }

    double hamiltonian(foena_t x, foena_t y){
        double delta = 2. * PI * (x - y) / double(this->nStates);
        return cos(delta);
    }

     xarrd magnetize(\
                  xt::pyarray<double>& temps,   \
                  size_t nSamples,\
                  double match){

         xarrd  results = xt::zeros<double>({3, static_cast<int>(nSamples)}) ;
         Temperature   tcopy   = this->t;
         double z       = this->nStates;

         FOENA  tmp;
         FOENA phase;
         for (size_t tidx = 0; tidx < temps.size(); tidx++){
             this->t = temps[tidx];
             xt::view(this->states, xt::all()) = this->agentStates[0];

             tmp   = 2 * PI * this->simulate(nSamples) / z;
             phase = xt::mean(xt::real(xt::exp( 1i * tmp)));

             xt::view(results, 0, tidx) = temps[tidx];
             xt::view(results, 1, tidx) = phase;
             if (tidx >= 1){
                xt::view(results, 2, tidx) = (results[1, tidx] - results[1, tidx - 1]) / (temps[0, tidx] - temps[0, tidx - 1]);
                }
            }
         // reset temperature
         this->t = tcopy;
         return results;
     }
};


class PottsFast{

public:
    Adjacency adj; // adjecency
    py::object graph; // stash nx object inside the class


    size_t sampleSize;
    size_t nNodes;

    size_t nStates;
    randutils::mt19937_rng rng;
    FOENA states;
    FOENA newstates;

    FOENA  agentStates;

    bool write ;
    xt::xarray<nodeID_t> nodeids;

    class Temperature: public Property <double>{
    public:
        double beta;
        virtual Temperature& operator= (double & t){
            beta = (t == 0 ? std::numeric_limits<double>::infinity() : 1 / t);
            value = t;
            return *this;
        }
    };

    Temperature t;


  // updateProperty
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

  nudgeProperty nudgeType;
  updateProperty updateType;


  PottsFast(py::object graph,\
        FOENA  agentStates = FOENA( {0,1}),     \
        string nudgeType   = "constant",        \
        string updateType  = "async",           \
        size_t sampleSize  = 0,                 \
        double t           = 0) {

      this->adj = Adjacency(graph);
      // setup properties
      this->sampleSize   = sampleSize;
      this->nudgeType    = nudgeType;
      this->updateType   = updateType;
      this->agentStates  = agentStates;
      this->nStates      = agentStates.size();

      this->sampleSize   = (sampleSize == 0 ? this->adj.nNodes : sampleSize);

      this->write = false;
      // setup buffers
      this->states = xt::zeros<foena_t>({this->adj.nNodes});
      for (auto node = 0 ; node < this->adj.nNodes; node++){
          this->states[node]    = this->rng.pick(agentStates);
          this->newstates[node] = this->states[node];
      }
      this->t          = t;

    // this->newstates  = nodeStates({this->nNodes});
  }


  double rand(size_t n ){
    for (auto i = 0 ; i < n ; i++){
        this->rng.uniform(0., 1.);
    }
    return 0;
  }

    // double rand(size_t n){
    //   this->rng.uniform(0., 1.);
    // }

    nodeids_a sampleNodes(size_t nSamples){

       size_t sampleSize   = this->sampleSize;
       size_t nNodes       = this->adj.nNodes;
       // samples samples = this->samples;
       // samples.resize(nSamples * sampleSize);
       size_t N   = nSamples * sampleSize;
       nodeids_a nodes  = nodeids_a::from_shape({N});

       size_t tmp;
       Nodeids nodeids = this->adj.nodeids ;

       // size_t j;
       for (auto samplei = 0; samplei < N; samplei++){
           tmp = samplei % nNodes;
           if (!(tmp)){
             this->rng.shuffle(nodeids);
         }
         // assign to sample
         xt::view(nodes, samplei) = nodeids[tmp];
       }
    return xt::reshape_view(nodes, {nSamples, sampleSize});
  }


    // Implement per model
  FOENA updateState(nodeids_a nodes){
        /*
          Node update loop
        */

      for (const auto& node : nodes){
           this->step(node);
       }
        // nodeStates& tmp = this->newstates;
        this->swap_buffers();
        this->write = (this->write ? false : true);
        return this->states;

    }
    //implement inherited class
    //

    void step(nodeID_t node){
       // nodeState_t state     = this->states[node];
       auto  proposal = this->rng.pick(this->agentStates);
       auto energy = 0.;

       for (const auto & neighbor : this->adj[node]){
         energy += neighbor.second *
            this->hamiltonian(proposal, this->states[neighbor.first]);
         energy += neighbor.second *
            this->hamiltonian(proposal, this->states[neighbor.first]);
        }

       auto delta = xt::xarray<double>{this->t.beta *energy};
       auto p     = xt::exp(- delta);
       if ((this->rng.uniform(0., 1.) < p[0]) || (xt::isnan(p)[0])){
           this->newstates[node] = proposal;
       }
       return ;
    }
    double hamiltonian(nodeState_t x, nodeState_t y){
        // double delta = 2. * PI * (x - y) / double(this->nStates);
        double z = this->agentStates.size();
        double delta = 2. * PI * (x - y) / z;
        return cos(delta);
    }

    virtual void swap_buffers(){
        std::swap(this->states, this->newstates);
     }

    FOENA  simulate(unsigned int nSamples){

        auto results = FOENA::from_shape({nSamples, this->adj.nNodes});
        auto nodes   = this->sampleNodes(nSamples);
        for (auto samplei = 0 ; samplei < nSamples; samplei++){
          // results[samplei] = this->updateState(nodes[samplei])
            xt::view(results, samplei) = this->updateState(xt::view(nodes, samplei));
            }
        return results;
    }
};
template <class Base = Model>
class PyModel: public Base {
public:
  // inherit constructors
  using Base::Base;

  void swap_buffers() override {
    PYBIND11_OVERLOAD(void, Base, swap_buffers,);
  }
   void step(nodeID_t node_id) override{
     PYBIND11_OVERLOAD_PURE(void, //return type
                            Base, //parent class
                            step, //function name
                            node_id//arguments
                            );
     }
};


template <class Base = Potts>
class PyPotts: public PyModel<Base>{
public:
    using PyModel<Base>::PyModel;

    void step (nodeID_t node) override{
        PYBIND11_OVERLOAD(void, Base, step, node);
    }
};

// class PyPottsFast: public Base {
//   public:
//     using Base::Base;
// };


PYBIND11_MODULE(example, m){
    xt::import_numpy();
    py::class_<Potts_>(m, "PD")
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
      .def("simulate", &Potts_::simulate)
      .def("sampleNodes", &Potts_::sampleNodes)
      .def_property("agentStates",
                    [](const Potts_& self){ return self.agentStates; },
                    [](const Potts_ & self) {})
      .def_property("graph",
            [] (const Potts_ & self){return self.adj.graph;},
            [](const Potts_ & self){})
      .def("rand", &Potts_::rand)
      ;

    py::class_<PottsFast>(m,"PottsFast")
      .def(py::init<\
             py::object, \
             xt::pyarray<double>,\
             string,\
             string,\
             size_t\
             >(),
           "graph"_a       ,
           "agentStates"_a = FOENA({0, 1}),
           "nudgeType"_a   = "constant",
           "updateType"_a  = "async",
           "sampleSize"_a  = 0
            )
      .def_readwrite("graph", &PottsFast::graph)
      .def("sampleNodes",     &PottsFast::sampleNodes)
      .def("simulate",        &PottsFast::simulate)
      .def_property("nudgeType", \
                      [] (const PottsFast &self){
                      return static_cast<string>(self.nudgeType);
                        },\
                       [](Model &self, string s){
                      self.nudgeType = s;
                    })
      .def_property("updateType", \
                       [](const PottsFast& self){
                      return static_cast<string>(self.updateType);
                    },\
                       [](PottsFast &self, string s){
                      self.updateType = s;
                    })

        .def_property("t", \
           [](const PottsFast &self) { return static_cast<double>(self.t);}, \
           [](PottsFast &self, double value) {self.t = value;})
        .def("rand", &PottsFast::rand)
       ;

    py::class_<Model, PyModel<>>(m, "Model")
      .def(py::init<\
             py::object, \
             agentStates_t,\
             string,\
             string,\
             size_t\
             >(),
           "graph"_a       ,
           "agentStates"_a ,
           "nudgeType"_a   = "constant",
           "updateType"_a  = "async",
           "sampleSize"_a  = 0
            )
      .def_readwrite("graph", &Model::graph)
      .def("sampleNodes",     &Model::sampleNodes)
      .def("simulate",        &Model::simulate)
      .def_property("nudgeType", \
                      [] (const Model &self){
                      return static_cast<string>(self.nudgeType);
                        },\
                      [](Model &self, string s){
                      self.nudgeType = s;
                    })
      .def_property("updateType", \
                      [](const Model& self){
                      return static_cast<string>(self.updateType);
                    },\
                      [](Model &self, string s){
                      self.updateType = s;
                    })
        ;//end class definition


//     //ignore tryout
//     // py::class_<Potts::Temperature, PyPotts>(m, "temp")
//     //   .def(py::init<double>())
//     //   .def(py::self+py::self)
//     //   // .def(py::self + float())
//     //   ;

     py::class_<Potts, PyPotts<>>(m, "Potts")
        .def(py::init<\
              py::object, \
              agentStates_t,\
              double,\
              string,\
              string,\
              size_t        >(),
             "graph"_a       ,
             "agentStates"_a = agentStates_t({0, 1}),
             "t"_a           = 1.,\
               "nudgeType"_a = "constant",
             "updateType"_a  = "async",
             "sampleSize"_a  = 0\
                )
        .def_readwrite("graph", &Potts::graph)
        .def("sampleNodes",     &Potts::sampleNodes)
        .def("simulate",        &Potts::simulate)
        .def("magnetize",       &Potts::magnetize,\
                "temps"_a = static_cast<xt::pyarray<double>>(xt::             logspace(-3, 1, 10)), \
                "nSamples"_a = 1000,\
               "match"_a    = -1)
       .def_property("t", \
           [](const Potts &self) { return static_cast<double>(self.t);}, \
           [](Potts &self, double value) {self.t = value;})
       .def("rand", &Potts::rand)
       ;
     m.doc() = "PlexSim reimplentation. Testing pybind11 out.";
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
