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

  int sampleSize;
  int nNodes;

  samples_t samples;
  std::vector<nodeID_t> nodeids;

  // constructor
  Model(py::object graph,\
        nodeStates agentStates = nodeStates(1, 0),  \
        string nudgeType       = "constant",\
        string updateType      = "async",\
        int sampleSize         = 0, \
        int seed               = -1\
        ) {

    cout << "In base constuctor\n";
    // setup seed
    std::time_t ts = std::time(nullptr);
    if (seed < 0 ){
      seed = ts;
    }
    this->_dist = std::uniform_real_distribution<double>(0., 1.);
    this->_gen  = std::mt19937(seed);


    // create adj
    create_adj(graph);

    // setup properties
    this->sampleSize = sampleSize;
    this->nudgeType  = nudgeType;
    this->updateType = updateType;

    if (sampleSize <= 0) this->sampleSize = this->nNodes;

    // setup buffers
    this->states     = nodeStates(this->nNodes);
    this->newstates  = nodeStates(this->nNodes);
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
    this-> nNodes= this->adj.size();

    this->nodeids = std::vector<nodeID_t>(this->nNodes);
    for (auto node = 0; node < nNodes; ++node){
        this->nodeids[node] = node;
    }

    return ;
  }
  double rand(){
    return this->_dist(this->_gen);
  }

    samples_t sampleNodes(int nSamples){

    int sampleSize   = this->sampleSize;
    int nNodes       = this->nNodes;

    auto nodeids = this->nodeids;
    // samples_t samples = this->samples;
    // samples.resize(nSamples * sampleSize);
    int N = nSamples * sampleSize;
    samples_t samples = samples_t(N,0);
    for (int samplei = 0; samplei < N; ++samplei){
      // shuffle the node ids
      // start = (samplei * sampleSize) % nNodes;
      if (samplei % nNodes >= nNodes){
          std::shuffle(nodeids.begin(), nodeids.begin() + sampleSize, std::default_random_engine());
          }
      // assign to sample
      //ptr[samplei] = nodeids[samplei % nNodes];
      samples[samplei] = nodeids[samplei % nNodes];
    }
    return samples;
  }
  // Implement per model
  virtual void step(nodeID_t node_id)  = 0;

  virtual void swap_buffers(){
    std::swap(this->states, this->newstates);
  }

private:
  std::mt19937 _gen; // RNG generator 
  std::uniform_real_distribution<double> _dist; 

  // buffers to write updates to
  nodeStates states;
  nodeStates newstates;
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


PYBIND11_MODULE(example, m){
  py::class_<Model, PyModel<>>(m, "Model")
    .def(
         py::init<py::object, nodeStates, string, string, int, int>(),
         "graph"_a       ,
         "agentStates"_a = nodeStates(1, 0),
         "nudgeType"_a   = "constant",
         "updateType"_a  = "async",
         "sampleSize"_a  = -1,
         "seed"_a        = -1
         )
    .def_readwrite("graph", &Model::graph)
      .def("sampleNodes", &Model::sampleNodes,
           "Class method for sampling nodes")
      ;//end class definition

  m.doc() = "Testing this stuff out";
}

