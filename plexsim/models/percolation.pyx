cimport cython, numpy as np
from cython.operator cimport dereference as deref
from cython.operator cimport preincrement as prei
from cython.operator cimport postincrement as post

import numpy as np

cdef class Percolation(Model):
    """"
    Percolation model. Each bond (edge) can percolate with probability p

    Paramaters
    ----------
    p: double
        probabililty of bond percolation

    agentStates: np.ndarray
        States of each vertex/node 1 indicates occupied, 0 is empty
    """
    def __init__(self, graph, p = 1, \
                 agentStates = np.array([0, 1], dtype = np.double), \
                **kwargs):
        super(Percolation, self).__init__(**locals())
        self.p = p


    cdef void _step(self, node_id_t node) nogil:
        cdef:
            long neighbor
        if self._states[node]:
            it = self.adj._adj[node].neighbors.begin()
            while it != self.adj._adj[node].neighbors.end():
                if self._rng._rand() < self._p:
                    neighbor = deref(it).first
                    self._newstates[neighbor] = 1
                post(it)
        return 

    @property
    def p(self):
        return self._p
    
    @p.setter
    def p(self, value):
        self._p = value
