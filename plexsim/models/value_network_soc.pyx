from plexsim.models.value_network cimport ValueNetwork
cimport numpy as np
import numpy as np
from cython.operator cimport dereference as deref, postincrement as post
from libc.math cimport exp

cdef class VNSoc(ValueNetwork):
    """
    Value network implementation as self-organizing criticality.
    Roles are fixed, but edges can change. The goal for each agent is to obtain $C$
    number of completed value networks;
    If vns < C:
       Connect to another random node
    If vns = C:
       Don't edit connections
    If vnc > C:
       prune one of the connections
    Designed and implemented by Casper van Elteren
    """
    def __init__(self, graph,
                 rules,
                 t = 1,
                 bounded_rational = -1,
                 explore_rate = 1.0,
                 heuristic = 0,
                 w0 = 1.0,
                 agentStates = np.arange(0, 2, dtype = np.double),
                 **kwargs
                 ):

        super(VNSoc, self).__init__(graph = graph,
                                    rules = rules,
                                    bounded_rational = bounded_rational,
                                    heuristic = heuristic,
                                    t = t,
                                    agentStates = agentStates,
                                    **kwargs)
        self._theta = heuristic
        self._explore_rate = explore_rate
        self._w0 = w0

        self._completed_vns = np.zeros(self.adj._nNodes, dtype = float)


    @property
    def completed_vns(self):
        return self._completed_vns.base
    cdef double _energy(self, node_id_t node) nogil:
        """
        Compute the number of completed value networks
        """
        cdef Crawler *crawler = new Crawler(node,
                                            self._states[node],
                                            self._bounded_rational,
                                            self._heuristic,
                                            self._path_size,
                                            False)
        # search for completed vns
        self._check_df(crawler)
        return crawler.results.size()

    cdef void _step(self, node_id_t node) nogil:
        """
        Isolate yourself with (murder/arrest etc)

        p(x = isolate | completed_vns) = 1 / (1 + exp(-(completed_vns - theta)))

        Exploration step
        p(x = True | completed_vns) = exp(- beta * completed_vns)

        Local search step (triadic closure)
        p(local_search = True) = completed_vns / theta

        """

        cdef double p_isolate, p_explore, p_local_search
        cdef size_t idx, completed_vns
        cdef node_id_t neighbor
        cdef Crawler *crawler

        cdef size_t behavior = <size_t> (self._rng._rand() * 3)

        # isolate
        if behavior == 0:
            p_isolate = self.adj._adj[node].neighbors.size() / self.adj._nNodes
            if self._rng._rand() < p_isolate:
                it = self.adj._adj[node].neighbors.begin()
                while it != self.adj._adj[node].neighbors.end():
                    self.adj._remove_edge(node, deref(it).first)
                    post(it)
            return

        # made the if else separte to share the expensive crawler step
        # shared code for next two steps
        crawler = new Crawler(node,
                            self._states[node],
                            self._bounded_rational,
                            self._heuristic,
                            self._path_size,
                            False)
        self._check_df(crawler)
        completed_vns = crawler.results.size()
        self._completed_vns[node] = completed_vns
        del crawler

        # explore
        if behavior == 1:
            p_explore = exp(- self._explore_rate * completed_vns)
            if self._rng._rand() < p_explore:
                idx = <node_id_t> (self._rng._rand() * self.adj._nNodes)
                self.adj._add_edge(node, idx, weight = self._w0)
            return

        # local search
        if behavior == 2:
            p_local_search = completed_vns / self._theta
            if self._rng._rand() < p_local_search:
                self.adj._add_edge(node, self._local_search(node))
            return

    cdef node_id_t _local_search(self, node_id_t node) nogil:
        cdef node_id_t neighbor = self._get_random_neighbor(node, use_weight = True)
        cdef size_t idx = <size_t> (self._rng._rand() * self.adj._adj[neighbor].neighbors.size())
        it = self.adj._adj[neighbor].neighbors.begin()
        while idx > 0:
            post(it)
            idx -= 1
        return deref(it).first

    cdef node_id_t _get_random_neighbor(self,
                                        node_id_t node,
                                        bint use_weight = True) nogil:
       cdef node_id_t idx
       cdef vector[double] weight
       cdef double z = 0
       cdef double p, left_side, right_side
       if use_weight:
           # get edge weights
           it = self.adj._adj[node].neighbors.begin()
           while it != self.adj._adj[node].neighbors.end():
               weight.push_back(deref(it).second)
               z += deref(it).second
               post(it)


           it = self.adj._adj[node].neighbors.begin()
           jt = weight.begin()

           # create bin sides for cumulative
           left_side = 0
           right_side = 0
           p = self._rng._rand() # draw rng
           while jt != weight.end():
               right_side += deref(jt)
               if left_side < p < right_side:
                   break
               left_side += right_side
               # advance
               post(it)
               post(jt)
           idx = deref(it).first
       else:
            idx = <node_id_t> (self._rng._rand() * self.adj._adj[node].neighbors.size())
            it = self.adj._adj[node].neighbors.begin()
            while idx > 0:
                post(it)
                idx -= 1
            idx = deref(it).first
       return idx

   # test functions
    cpdef node_id_t local_search(self, node_id_t node):
        return self._local_search(node)

    cpdef node_id_t get_random_neighbor(self, node_id_t node, bint use_weight = False):
        return self._get_random_neighbor(node, use_weight)
