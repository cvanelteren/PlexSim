from plexsim.models.types cimport *
from plexsim.models.base cimport *
from cython.operator cimport dereference as deref
from cython.operator cimport postincrement as post
cimport numpy as np
import numpy as np

cdef class Conway(Model):
    """Conway's game of life

    Implements  conways  game  of life  on  an  abitrary
    network structure.

    Parameters
    ----------
    object graph : nx.Graph, nx.DiGraph
    size_t threshold : int
        Threshold indicating when a  cell will survive or
        die.  The threshold  will be  used by  comparing
        \theta - 1 <= #alive <= theta.
    **kwargs : dict
        General  settings   for  the  base   model  (see
        Model).

    Examples
    --------
    FIXME: Add docs.
    """

    def __init__(self, object graph, size_t threshold = 3,
                 **kwargs):
        s = np.arange(2)
        super(Conway, self).__init__(graph = graph, agentStates = s,
                                     **kwargs)
        self.threshold = threshold

    @property
    def threshold(self):
        return self._treshold
    @threshold.setter
    def threshold(self, value):
       self._threshold = value

    cdef void _step(self, node_id_t node) nogil:
        it = self.adj._adj[node].neighbors.begin()
        cdef state_t counter = 0 # float
        while it != self.adj._adj[node].neighbors.end():
            counter += self._states[deref(it).first]
            post(it)
        # deal with alive nodes
        if self._states[node] == 1:
            # goldey lock zone
            if self._threshold-1 <= counter <= self._threshold:
                self._newstates[node] = 1
            # overpopulation or underpopulatoin
            else:
                self._newstates[node] = 0
        # deal with dead nodes
        else:
            # expansion
            if counter == self._threshold:
                self._newstates[node] = 1

