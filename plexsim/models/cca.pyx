cimport cython, numpy as np
import numpy as np
from cython.parallel cimport parallel, prange, threadid
from cython.operator cimport dereference as deref
from cython.operator cimport preincrement as prei
from cython.operator cimport postincrement as post

cdef class CCA(Model):
    """
        Circular cellular automaton
    """
    def __init__(self, \
                 graph,\
                 threshold = 0.,\
                 agentStates = np.array([0, 1, 2], dtype = np.double),\
                 **kwargs):
   

        super(CCA, self).__init__(**locals())

        self.threshold = threshold

    cdef void _step(self, node_id_t node) nogil:
        """
        Rule : evolve if the state of the neigbhors exceed a threshold
        """
        cdef:
            long neighbor
            long nNeighbors = self.adj._adj[node].neighbors.size()
            int i
            double fraction = 0
            state_t* states = self._states
        # check neighbors and see if they exceed threshold
        it = self.adj._adj[node].neighbors.begin()
        while it != self.adj._adj[node].neighbors.end():
            neighbor = deref(it).first
            if (states[neighbor] == (states[node] + 1) % self._nStates):
                fraction += 1
            post(it)
        if (fraction / <double> nNeighbors >= self._threshold):
            self._newstates[node] = ((states[node] + 1 ) % self._nStates)
        else:
            if self._rng._rand() <= self._threshold:
                i = <int> (self._rng._rand() * self._nStates)
                self._newstates[node] = self._agentStates[i]
        return 

    # threshold for neighborhood decision
    @property
    def threshold(self):
        return self._threshold
    @threshold.setter
    def threshold(self, value):
        assert 0 <= value <= 1.
        self._threshold = value
