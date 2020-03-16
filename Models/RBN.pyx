#distutils: language = c++
include "definitions.pxi"
from PlexSim.Models.Models cimport Model
cimport cython, numpy as np
import numpy as np
cdef class RBN(Model):
    def __init__(self, graph, rule = None, \
                 updateType = 'sync',\
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
    cpdef long[::1] updateState(self, long[::1] nodesToUpdate):
        return self._updateState(nodesToUpdate)


    @property
    def rules(self):
        return self._rules
    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cdef long[::1] _updateState(self,\
                                long[::1] nodesToUpdate) nogil:
            cdef:
                int N = nodesToUpdate.shape[0];
                int idx
                int node, neighbor
                int neighborState
                int nNeighbor;
            for node in range(N):
                node = nodesToUpdate[node];
                # compute input and rule
                idx = 0;
                nNeighbor = self._adj[node].neighbors.size();
                for neighbor in range(nNeighbor):
                    #idx += self._states[self._adj[node].neighbors[neighbor]]
                    neighborState = self._states[self._adj[node].neighbors[neighbor]]
                    if neighborState:
                        idx += 2 ** neighbor
                    #idx *= self._states[self._adj[node].neighbors[neighbor]] * 2 ** neighbor 
                self._newstates[node] = self._rules[node][idx]

            for node in range(self._nNodes):
                self._states[node] = self._newstates[node]
            return self._states

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


