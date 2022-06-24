import numpy as np
cimport numpy as np
np.import_array()
from libcpp.vector cimport vector
from plexsim.models.base cimport Model
from plexsim.models.types cimport *
from cython.operator cimport dereference as deref, postincrement as post

cdef class BakSneppen(Model):
    def __init__(self, graph):
        super().__init__(graph = graph)
        self.states = np.random.rand(len(graph))

    cdef void _step(self, node_id_t node) nogil:
        cdef state_t min_value = 1
        cdef size_t neighbor
        # get lowest value in system
        for node in range(self.adj._nNodes):
            if deref(self._states)[node] <= min_value:
                min_value = deref(self._states)[node]

        # replace lowest values and neighbors
        for node in range(self.adj._nNodes):
            if deref(self._states)[node] == min_value:
                deref(self._newstates)[node] = self._rng._rand()
                it = self.adj._adj[node].neighbors.begin()
                end = self.adj._adj[node].neighbors.end()
                while it != end:
                    deref(self._newstates)[deref(it).first] = self._rng._rand()
                    post(it)
