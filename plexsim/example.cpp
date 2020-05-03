/*
 AUTHOR: Casper van Elteren
*/

#include "models_definitions.h" // includes all defintions used here

template <typename T>
class Property {
public:
  virtual ~Property() {}
  virtual T& operator= (const T& f) {return value = f;}
  virtual const T& operator() () const {return value;}
  virtual explicit operator const T& () const  {return value;}
  virtual T* operator-> () {return &value;}
protected: 
  T value;
};

// CLASS IMPLEMENTATION
// use template for the node state type ? 
class Model{
public:
  // updateProperty
  class updateProperty: public Property <string> {
  public:
    virtual string& operator = (const string &f){
      if (f == "async") return value = f;
      else if(f =="sync") return value = f;
      else return value = "async";
      }
  };

  // nudge property
  class nudgeProperty : public Property <string> {
  public:
    virtual string& operator= (const string &f){
      if (f == "constant") return value = f;
      else if (f == "pulse") return value = f;
      else return value = "constant";
      }
  };

    Connections adj; // adjecency
    py::object graph; // stash nx object inside the class

    nudgeProperty nudgeType;
    updateProperty updateType;

    size_t sampleSize;
    size_t nNodes;

    size_t nStates;
    randutils::mt19937_rng rng;
    nodeStates states;
    nodeStates newstates;

    agentStates_t  agentStates;
 
    bool write ;
  xt::xarray<nodeID_t> nodeids;

  // constructor
  Model(py::object graph,\
        agentStates_t  agentStates = agentStates_t( {0,1}),  \
        string nudgeType       = "constant",\
        string updateType      = "async",\
        size_t sampleSize         = 0 \
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
      this->sampleSize = sampleSize;
      this->nudgeType  = nudgeType;
      this->updateType = updateType;
      this->agentStates = agentStates;
      this->nStates    = agentStates.size();

      this->sampleSize = (sampleSize == 0 ? this->nNodes : sampleSize);

      this->write = false;
      // setup buffers
      // this->states     = nodeStates({this->nNodes} );
      xt::xarray<int>tmp = xt::arange(0, 5);
      xt::random::choice(tmp, 1, false);
      // this->states  = xt::random::choice(agentStates, 1);
      // this->states  = xt::zeros<nodeState_t>({this->nNodes}) ;
      this->states = xt::zeros<nodeState_t>({this->nNodes});
      for (auto node = 0 ; node < this->nNodes; node++){
          this->states[node] = this->rng.pick(agentStates);
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
       if (directed){
           this->adj[target].neighbors[source] = weight;
       }
       else{
           this->adj[source].neighbors[target] = weight;
           this->adj[target].neighbors[source] = weight;
       };
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

    nodeids_a sampleNodes(uint nSamples){

       unsigned int sampleSize   = this->sampleSize;
       int nNodes       = this->nNodes;
       Nodeids nodeids     = this->nodeids;
       // samples samples = this->samples;
       // samples.resize(nSamples * sampleSize);
       unsigned int N   = nSamples * sampleSize;
       nodeids_a nodes  = nodeids_a::from_shape({N});

       size_t idx;
       int node;
       for (size_t samplei = 0; samplei < N; samplei++){
         // shuffle the node ids
         // start = (samplei * sampleSize) % nNodes;
           if (!(samplei % nNodes)){
               for (node = this->nNodes - 1 ; node > 1; node--){
                   idx = this->rng.uniform(0, node);
                   swap(nodeids[node], nodeids[idx]);
               }
               //this->rng.shuffle(nodeids);
         }
         // assign to sample
         //ptr[samplei] = nodeids[samplei % nNodes];
           xt::view(nodes, samplei) = nodeids[samplei % nNodes];
    }
    return xt::reshape_view(nodes, {nSamples, sampleSize});
  }

    // Implement per model
  nodeStates updateState(nodeids_a nodes){
        /*
          Node update loop
        */

      for (auto node = 0; node < nodes.size(); node++){
           this->step(nodes[node]);
       }
        this->swap_buffers();
        this->write = (this->write ? false : true);

        if (this->write){
            return this->states;
           }
        else{
            return this->newstates;
        }
    }
    //implement inherited class
    virtual void step(nodeID_t node_id)  = 0;

    virtual void swap_buffers(){
        std::swap(this->states, this->newstates);
     }

    nodeStates  simulate(unsigned int nSamples){

        nodeStates results = nodeStates::from_shape({nSamples, this->sampleSize});
        
        nodeids_a nodes = this->sampleNodes(nSamples);
        for (unsigned int samplei = 0 ; samplei < nSamples; samplei++){
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

    double beta;
    double t;

    Potts(\
     py::object graph,                               \
     agentStates_t  agentStates = agentStates_t(1, 0), \
     double t               = 1,\
     string nudgeType       = "constant",\
     string updateType      = "async",\
     size_t sampleSize         = 0 \
          ): Model(graph, agentStates,\
                   nudgeType, updateType,\
                   sampleSize){
        this-> beta = 1/t; this->t = t;
        
    };

   void step(nodeID_t node){
       xt::xarray<double> energies = {0, 0};
       nodeState_t nodeState = this->states[node];
       nodeState_t neighborState;
       nodeState_t  proposal = this->rng.pick(this->agentStates);
       for (auto neighbor : this->adj[node].neighbors){
           neighborState = this->states[neighbor.first];
           energies[0] -= this->hamiltonian(nodeState, neighborState) * neighbor.second;
           energies[1] -= this->hamiltonian(proposal, neighborState) * neighbor.second;
       }
       xt::xarray<double> delta = {this->beta *(energies[1] - energies[0])};
       xt::xarray<double>p = xt::exp(- delta);
       if (this->rng.variate<double, uniform_real_distribution>(0., 1.) < p[0]){
           this->newstates[node] = proposal;
       } 
       return ;
    }

    double hamiltonian(nodeID_t x, nodeID_t y){
        double delta = 2. * xt::numeric_constants<double>::PI * (x - y) / double(this->nStates); 
        return cos(delta);
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


PYBIND11_MODULE(example, m){
  py::class_<Model, PyModel<>>(m, "Model")
    .def(py::init<\
         py::object, \
         agentStates_t,\
         string,\
         string,\
         size_t\
         >(),
         "graph"_a       ,
         "agentStates"_a = agentStates_t(1, 0),
         "nudgeType"_a   = "constant",
         "updateType"_a  = "async",
         "sampleSize"_a  = 0
         )
    .def_readwrite("graph", &Model::graph)
    .def("sampleNodes", &Model::sampleNodes,
           "Class method for sampling nodes")
    .def("simulate", &Model::simulate)
      ;//end class definition

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
           "nudgeType"_a   = "constant",
           "updateType"_a  = "async",
           "sampleSize"_a  = 0\
           )
      .def_readwrite("graph", &Potts::graph)
      .def("sampleNodes", &Potts::sampleNodes,
           "Class method for sampling nodes")
      .def("simulate", &Potts::simulate)
      ;
  m.doc() = "Testing this stuff out";
};
