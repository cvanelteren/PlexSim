from plexsim.models.base cimport Model
from cython.operator cimport dereference as deref, postincrement as post
cimport numpy as np
import numpy as np, networkx as nx
from libcpp.vector cimport vector
cdef class Sandpile(Model):
    """
    Implementation of the sandpile model

    Parameters
    ----------

    graph: nx.Graph, nx.DiGraph, default 10x10 lattice
    threshold: int, threshold for avalanche
    """
    def __init__(self, object graph = nx.grid_graph((10, 10)),
                 size_t threshold = 3,
                 *args, **kwargs
                 ):
        super().__init__(graph, agentStates = np.arange(0, threshold), **kwargs)
        self.threshold = threshold

    cdef void _step(self, node_id_t node) nogil:
        """
        Add a grain and recursively check for avalanches
        """
        cdef size_t counter = 0
        cdef vector[node_id_t] queue
        self._states[node] += 1
        if self._states[node] > self._threshold:
            queue.push_back(node)
            counter = self._check_avalanche(queue, counter)

    cdef size_t _check_avalanche(self, vector[node_id_t] queue, size_t counter) nogil:
        """
        Pop queue
        Add to its neighbors one grain
        Check their threshold
        """

        cdef node_id_t node, neighbor

        with gil:
            print(counter, queue.size())
        if queue.size():
            counter += 1
            node = queue.back()
            self._states[node] -= self._threshold
            queue.pop_back()
            it = self.adj._adj[node].neighbors.begin()
            while it != self.adj._adj[node].neighbors.end():
                neighbor = deref(it).first
                if deref(it).second > 0:
                    self._states[neighbor] += 1
                if self._states[neighbor] > self._threshold:
                    queue.push_back(neighbor)
                post(it)
        return counter + self._check_avalanche(queue, counter)

    @property
    def threshold(self):
        return self._threshold

    @threshold.setter
    def threshold(self, value):
        self._threshold = int(value)
