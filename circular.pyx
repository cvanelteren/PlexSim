# distutils: language = c++
from Models.models cimport Model
import numpy as np
cimport numpy as np
cimport cython
cdef class CCA(Model):
    def __init__(self, \
                    graph,\
                    threshold = 0.,\
                    agentStates = [-1 ,1],\
                    updateType = 'single',\
                    nudgeType   = 'constant',\
                    **kwargs):
        super(CCA, self).__init__(**locals())
        self.threshold = threshold

    # threshold for neighborhood decision
    @property
    def threshold(self):
        return self._threshold
    @threshold.setter
    def threshold(self, value):
        assert 0 <= value <= 1.
        self._threshold = value

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cdef long _evolve(self, long node) nogil:
        """
        Rule : evolve if the state of the neigbhors exceed a threshold
        """

        cdef:
            long neighbor, nNeighbors = self._adj[node].neighbors.size()
            int i
            double fraction = 0
        # check neighbors and see if they exceed threshold
        for neighbor in range(nNeighbors):
            neighbor = self._adj[node].neighbors[neighbor]
            if self._states[neighbor] == (self._states[node] + 1) % self._nStates:
                fraction += 1
        # consume cell
        fraction /= <double> nNeighbors
        if fraction  >= self._threshold:
            return  (self._states[node]  + 1)  %  self._nStates
        # remain unchanged
        else:
            if self.rand() <= self._threshold:
                i = <long> self.rand() * self._nStates
                self._states[node] = self._agentStates[i]
            return self._states[node]

    cpdef long[::1] updateState(self, long[::1] nodesToUpdate):
        return self._updateState(nodesToUpdate)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cdef long [::1]  _updateState(self, long[::1] nodesToUpdate) nogil:
        """
        Circular update rule with threshold:
        A cell evolves from 1 to N only when :theta: neighbors are the next state otherwise
        it remains the same
        """
        cdef:
            int node, N = len(nodesToUpdate)
        for node in range(N):
            node = nodesToUpdate[node]
            self._newstates[node] = self._evolve(node)
        for node in range(self._nNodes):
            self._states[node] = self._newstates[node]
        return self._states
