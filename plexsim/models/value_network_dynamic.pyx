from plexsim.models.value_network cimport ValueNetwork
cimport numpy as np; np.import_array()
import numpy as np
from cython.operator cimport dereference as deref, postincrement as post
from plexsim.models.types cimport *


cdef class ValueDynamic(ValueNetwork):
    def __init__(self, graph,
                 rules,
                 t = 1,
                 bounded_rational = -1,
                 heuristic = 0,
                 **kwargs
                 ):


        agentStates = np.arange(0, len(rules) , dtype = np.double)
        super(ValueDynamic, self).__init__(graph = graph, rules = rules,
                                           bounded_rational = bounded_rational,
                                           heuristic = heuristic,
                                           t = t,
                                           agentStates = agentStates,
                                           **kwargs)

        self._agentStates = np.arange(0, len(rules) + 2, dtype = np.double)
        self._nStates = len(self._agentStates)

    cdef void _step(self, node_id_t node) nogil:
        cdef:
            state_t proposal = self._sample_proposal()
            state_t current  = deref(self._states)[node]
            double p

            node_id_t other
        p = self.probability(current, node)
        # add an edge or remove and edge
        if proposal == (self._nStates - 2) or proposal == (self._nStates - 1):
            other = node
            while other == node:
                other = <node_id_t>(self._rng._rand() * self.adj._nNodes)

            # sample new edge
            if proposal == (self._nStates - 1):
                self.adj._add_edge(node, other)
            else:
                self.adj._remove_edge(node, other)

            p =  self.probability(current, node) / p

            # reject state
            if self._rng._rand() > p:
                # reverse operator above
                if proposal == (self._nStates):
                    self.adj._remove_edge(node, other)
                else:
                    self.adj._add_edge(node, other)


        # attempt role switch
        else:
            p =  self.probability(proposal, node) / p
            if self._rng._rand () < p:
                deref(self._newstates)[node] = proposal
        return
