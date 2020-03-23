# distutils: language = c++
include "definitions.pxi"
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
            long* states = self._states_ptr
        # check neighbors and see if they exceed threshold
        for neighbor in range(nNeighbors):
            neighbor = self._adj[node].neighbors[neighbor]
            if states[neighbor] == (states[node] + 1) % self._nStates:
                fraction += 1
        # consume cell
        fraction /= <double> nNeighbors
        if fraction  >= self._threshold:
            return  (states[node]  + 1)  %  self._nStates
        # remain unchanged
        else:
            if self._rand() <= self._threshold:
                i = <long> self._rand() * self._nStates
                states[node] = self._agentStates[i]
            return self._states[node]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cdef void _step(self, long node) nogil:
        self._newstates_ptr[node] = self._evolve(node)
        return
