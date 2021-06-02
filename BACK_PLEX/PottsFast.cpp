
#include "models_definitions.h"
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
    this-> nNodes = static_cast <size_t>(py::int_(graph.attr("number_of_nodes")()));
    this->nodeids = xt::arange(this->nNodes);
    return ;
  }

  Neighbors operator[](nodeID_t node){
    return this->adj[node].neighbors; };

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

    agentStates_t  agentStates;

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
        agentStates_t  agentStates = agentStates_t( {0,1}),  \
        string nudgeType       = "constant",\
        string updateType      = "async",\
        size_t sampleSize      = 0, \
        double t               = 0) {

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
      // this->states     = nodeStates({this->nNodes} );
      // xt::xarray<int>tmp = xt::arange(0, 5);
      // xt::random::choice(tmp, 1, false);
      // this->states  = xt::random::choice(agentStates, 1);
      // this->states  = xt::zeros<nodeState_t>({this->nNodes}) ;
      this->states = xt::zeros<nodeState_t>({this->adj.nNodes});
      for (size_t node = 0 ; node < this->adj.nNodes; node++){
          this->states[node] = this->rng.pick(agentStates);
      }
      this->newstates  = this->states;
      this->t          = t;

    // this->newstates  = nodeStates({this->nNodes});
  }

    //double rand(){
    //  return this->_dist(this->_gen);
    //}

    nodeids_a sampleNodes(uint nSamples){

       size_t sampleSize   = this->sampleSize;
       size_t nNodes       = this->adj.nNodes;
       // samples samples = this->samples;
       // samples.resize(nSamples * sampleSize);
       size_t N   = nSamples * sampleSize;
       nodeids_a nodes  = nodeids_a::from_shape({N});

       size_t tmp;
       Nodeids nodeids = this->adj.nodeids ;

       // size_t j;
       // #pragma omp parallel for private(tmp, nodeids, j)
       for (size_t samplei = 0; samplei < N; samplei++){
         // shuffle the node ids

           // tmp = samplei & (nNodes - 1);
           tmp = samplei % nNodes;
           if (!(tmp)){

             // for (int  i = this->nNodes; i > 0 ; i--){
             //   j = this->rng.uniform(0, i);
             //   swap(nodeids[i], nodeids[j]);

             // }
             //
             this->rng.shuffle(nodeids);
         }
         // assign to sample
         xt::view(nodes, samplei) = nodeids[tmp];
       }
       // return nodes;
    return nodes;
    // return xt::reshape_view(nodes, {nSamples, sampleSize});
  }

  void checkRand(long N){
    for (auto i = 0; i < N ; i++){
      this->rng.uniform(0., 1.);
    }
  }

    // Implement per model
  FOENA updateState(nodeids_a nodes){
        /*
          Node update loop
        */

      for (nodeID_t node : nodes){
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
       nodeState_t  proposal = this->rng.pick(this->agentStates);
       double energy = 0;

       for (auto neighbor : this->adj[node]){
         energy += neighbor.second *
            this->hamiltonian(proposal, this->states[neighbor.first]);
                }

       xarrd delta = {this->t.beta *energy};
       xarrd p     = xt::exp(- delta);
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

        FOENA results = FOENA::from_shape({nSamples, this->sampleSize});

        nodeids_a nodes = this->sampleNodes(nSamples);
        for (size_t samplei = 0 ; samplei < nSamples; samplei++){
          // results[samplei] = this->updateState(nodes[samplei])
            xt::view(results, samplei) = this->updateState(
                        xt::view(nodes, xt::range(samplei, samplei + this->sampleSize)));
            }
        return results;
    }
};

int main(){
  py::object nx = py::module::import( "networkx" );                          
  py::object g  = nx.attr("path_graph")(100);
  PottsFast m = PottsFast(g);
  m.simulate(10);
}

// Local Variables:
// rmsbolt-command: "g++ -O3 -I/home/casper/miniconda3/lib/python3.8/site-packages/numpy/core/include -I/home/casper/miniconda3/include -I/usr/include/python3.8"
// rmsbolt-disassemble: nil
// End:
