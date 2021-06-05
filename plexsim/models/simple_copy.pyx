import networkx as nx
cimport cython
from cython.operator cimport dereference as deref, preincrement, postincrement as post
cdef class SimpleCopy(Potts):
    def __init__(self,
                 double weight = 0, **kwargs):

        # create path graph with directed edge
        graph = nx.path_graph(3, create_using = nx.DiGraph())
        graph.add_edge(0, len(graph))

        super(SimpleCopy, self).__init__(graph = graph, **kwargs)

        # self._target = self.adj.mapping["target"]
        # print(f"init with copy target {self._target}")


    # cdef void _step(self, node_id_t node) nogil:
    #     cdef:
    #         state_t proposal = self._sample_proposal()
    #         state_t cur_state= self._states[node]
    #         double p

    #     # copy operator
    #     if node == self._target:
    #         self._states[node] = self._states[0]

    #     else:
    #         p = self.probability(proposal, node) / \
    #             self.probability(cur_state, node)
    #         if self._rng._rand () < p:
    #             self._newstates[node] = proposal
    #     return
    cdef void _step (self, node_id_t node) nogil:
        cdef state_t proposal

        it = self.adj._adj[node].neighbors.begin()
        end = self.adj._adj[node].neighbors.end()
        if node != 0:
            while it != end:
                self._states[node] = self._states[deref(it).first]
                post(it)
        else:
            proposal = self._sample_proposal()
            if self._rng._rand() < .5:
                self._newstates[node] = proposal
