#include <pybind11/pybind11.h>
namespace py = pybind11;


typedef int nodeId_t
typedef int nodeState_t


class Model{
public:

  Model(\
        graph,\

        )
  virtual void swap_buffers() {
    std::swap(this._states, this._newstates);
  }

  virtual void step(int node) {}

  virtual nodeState_t * updateState(nodeId_t* nodes){
    // stash size in pointer
    int nNodes = *nodeId_t;
    for (auto node + 1 ; node < nNodes; ++node){
      this.step(nodes[node]);
    }
    this.swap_buffers();
    return this._states;
  }
    
  }
private:
// buffers
nodeState_t[] __states
nodeState_t[] __newstates

// pointers
nodeState_t* _states
nodeState_t* _newstates
}
