#distutils: language = c++
include "definitions.pxi"
from PlexSim.Models.Models cimport Model
cimport cython, numpy as np
import numpy as np
cdef class RBN(Model):
    def __init__(self, graph, rule = None, \
                 updateType = "sync",\
                 **kwargs):


        agentStates = [0, 1]

        super(RBN, self).__init__(**locals())
        self.states = np.asarray(self.states.base.copy())

        # init rules
        # draw random boolean function
        for node in range(self.nNodes):
            k = self._adj[node].neighbors.size()
            _rule = np.random.randint(0, 2**(2 ** k), dtype = int)
            _rule = format(_rule, f'0{2 ** k}b')[::-1]
            self._rules[node] = [int(i) for i in _rule]

    @property
    def rules(self):
        return self._rules

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cdef void _step(self, long node) nogil:
       """
       Update step for Random Boolean networks
       Count all the 1s from the neighbors and index into fixed rule
       """
       cdef:
           long counter = 0
           long neighbor
           long N = self._adj[node].neighbors.size()
        # get neighbors
       for neighbor in range(N):
          # count if 1
          if self._states_ptr[self._states_ptr[neighbor]]:
              counter += 2 ** neighbor
        #update
       self._newstates_ptr[node] = self._rules[node][counter]
       return
    
    # overloading parrent
    def __deepcopy__(self, memo):
        tmp = {i : getattr(self, i) for i in dir(self)}
        tmp = RBN(**tmp)
        return tmp
    def __reduce__(self):
        graph = self.graph
        states = self.states.base.copy()
        nudges = self.nudges.base.copy()
        updateType = self.updateType
        return (rebuild, (graph, states, nudges, updateType))

def rebuild(graph, states, nudges, updateType):
    cdef RBN tmp = RBN(graph, updateType = updateType)
    tmp.states = states.copy()
    tmp.nudges = nudges.copy()
    return tmp


