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
    Connections adj; // adjecency
    py::object graph; // stash nx object inside the class

    
    size_t sampleSize;
    size_t nNodes;

    size_t nStates;
    randutils::mt19937_rng rng;
    nodeStates states;
    nodeStates newstates;

    agentStates_t  agentStates;
 
    bool write ;
    xt::xarray<nodeID_t> nodeids;


  // updateProperty
    class updateProperty: public Property <string> {
  public:
    virtual string& operator = (const string &f){
        if (f == "async"){
            // Model::newstates; // = Model::states;
            return value = f;
        }
        else if (f == "sync"){
            // Model::newstates = Model::states;
            return value = f;
        }
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

  nudgeProperty nudgeType;
  updateProperty updateType;

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
      this->sampleSize   = sampleSize;
      this->nudgeType    = nudgeType;
      this->updateType   = updateType;
      this->agentStates  = agentStates;
      this->nStates      = agentStates.size();

      this->sampleSize   = (sampleSize == 0 ? this->nNodes : sampleSize);

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

    nodeids_a sampleNodes(uint nSamples){

       unsigned int sampleSize   = this->sampleSize;
       int nNodes                = this->nNodes;
       // samples samples = this->samples;
       // samples.resize(nSamples * sampleSize);
       unsigned int N   = nSamples * sampleSize;
       nodeids_a nodes  = nodeids_a::from_shape({N});

       size_t tmp;
       Nodeids nodeids = this->nodeids ;

// #pragma omp parallel private(tmp, nodeids) 
       // #pragma omp for
       for (size_t samplei = 0; samplei < N; samplei++){
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

    // Implement per model
  nodeStates updateState(nodeids_a nodes){
        /*
          Node update loop
        */

      for (auto node = 0; node < nodes.size(); node++){
           this->step(nodes[node]);
       }
        auto tmp = this->newstates;
        this->swap_buffers();
        this->write = (this->write ? false : true);
        return tmp;

    }
    //implement inherited class
    virtual void step(nodeID_t node_id)  = 0;

    virtual void swap_buffers(){
        std::swap(this->states, this->newstates);
     }

    nodeStates  simulate(unsigned int nSamples){

        nodeStates results = nodeStates::from_shape({nSamples, this->sampleSize});
        
        nodeids_a nodes = this->sampleNodes(nSamples);
        for (size_t samplei = 0 ; samplei < nSamples; samplei++){
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
        virtual double& operator= (double & t){
            beta = (t == 0 ? std::numeric_limits<double>::infinity() : 1 / t);
            return value = t;
        }
    };

    Temperature t;

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
        this->t = t; 
        
    };

   void step(nodeID_t node){
       nodeState_t nodeState = this->states[node];
       nodeState_t neighborState;
       nodeState_t  proposal = this->rng.pick(this->agentStates);

       double cEn = 0;
       double fEn = 0;
       Connection* tmp = &this->adj[node]; 

       #pragma parallel reduction(+:cEn, +:fEn) for
       for (auto neighbor : tmp->neighbors){
           neighborState = this->states[neighbor.first];
           cEn -= this->hamiltonian(nodeState, neighborState) * neighbor.second;
           fEn -= this->hamiltonian(proposal, neighborState) * neighbor.second;
       }
       xarrd delta = {this->t.beta *(fEn - cEn)};
       xarrd p     = xt::exp(- delta);
       if ((this->rng.uniform(0., 1.) < p[0]) || (xt::isnan(p)[0])){
           this->newstates[node] = proposal;
       } 
       return ;
    }

    double hamiltonian(nodeID_t x, nodeID_t y){
        double delta = 2. * PI * (x - y) / double(this->nStates); 
        return cos(delta);
    }

     xarrd magnetize(\
                  xt::pyarray<double>& temps,   \
                  size_t nSamples,\
                  double match){

         xarrd results    = xt::zeros<double>({3, static_cast<int>(nSamples)}) ;
         Temperature tcopy  = this->t;
         double z         = this->nStates;

         xarrd  tmp;
         xarrd phase;
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
         // if (match >= 0){
         //    py::object optimize  = py::module::import("scipy.optimize");
         //    py::list param = optimize.attr("curve_fit")(sigmoid, temps, xt::view(results, 1), maxfev = 10000);

         //    double t = optimize.attr("fmin")(sigmoidOps, x0 = 0, args = (param[0], match));
         //    tcopy.t = t;
            
         // }
         this->t = tcopy;

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


PYBIND11_MODULE(example, m){
    xt::import_numpy();
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
      .def("sampleNodes",     &Model::sampleNodes)
      .def("simulate",        &Model::simulate)
        ;//end class definition

    // py::class_<Potts::Temperature, PyPotts>(m, "temp")
    //   .def(py::init<double>())
    //   .def(py::self+py::self)
    //   // .def(py::self + float())
    //   ;

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
        .def("sampleNodes",     &Potts::sampleNodes)
        .def("simulate",        &Potts::simulate)
        .def("magnetize",       &Potts::magnetize,\
             "temps"_a = static_cast<xt::pyarray<double>>(xt::             logspace(-3, 1, 10)), \
             "nSamples"_a = 1000,\
            "match"_a    = -1)
       .def("t", &Potts::t)
       ;
     m.doc() = "Testing this stuff out";
};

