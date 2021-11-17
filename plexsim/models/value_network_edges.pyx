from plexsim.models.value_network cimport ValueNetwork
cimport numpy as np
import numpy as np
from cython.operator cimport dereference as deref, postincrement as post



cdef class VNE(ValueNetwork):
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
                 heuristic = 0,
                 agentStates = np.arange(0, 2, dtype = np.double),
                 **kwargs
                 ):

        super(VNE, self).__init__(graph = graph,
                                    rules = rules,
                                    bounded_rational = bounded_rational,
                                    heuristic = heuristic,
                                    t = t,
                                    agentStates = agentStates,
                                    **kwargs)
        self._theta = heuristic

        self._completed_vns = np.zeros(self.adj._nNodes, dtype = float)

    @property
    def completed_vns(self):
        return self._completed_vns.base

    # cdef double _energy(self, node_id_t node) nogil:
    #     """
    #     Compute the number of completed value networks
    #     """
    #     cdef Crawler *crawler = new Crawler(node,
    #                                         self._states[node],
    #                                         self._bounded_rational,
    #                                         self._heuristic,
    #                                         False)
    #     # search for completed vns
    #     self._check_df(crawler)
    #     del crawler
    #     return crawler.results.size()

    cdef void _step(self, node_id_t node) nogil:
        """
        Checks the number of completed value networks for @node.
        Adds edges if #vns < @heuristic
        Adds edges if #vns > @heuristic
        Does nothing if #vns = @heuristic

        NOTE: this func is used to merely force the update on the completed value networks
        The energy is computed according to the parent class (value network)
        """
        cdef:
            double completed_vn
            vector[node_id_t] remove_options
            node_id_t neighbor
            state_t node_state, neighbor_state
            size_t idx
            Neighbors.iterator it


        # compute energy
        # cdef double energy = self._energy(node)
        cdef Crawler *crawler = new Crawler(node,
                                            self._states[node],
                                            self._bounded_rational,
                                            self._heuristic,
                                            self._path_size,
                                            False)
        # search for completed vns
        self._check_df(crawler)
        # energy += crawler.results.size()
        completed_vn = crawler.results.size()
        self._completed_vns[node] = completed_vn
        return

    cdef void _remove_node(self, node_id_t node,
                           vector[vector[EdgeColor]] value_member) nogil:
        """
        Removes edge that does not break any value network
        """
        it = self.adj._adj[node].neighbors.begin()
        cdef vector[node_id_t] options
        cdef size_t idx, jdx
        while it != self.adj._adj[node].neighbors.end():
            add = True
            for idx in range(value_member.size()):
                for jdx in range(value_member[idx].size()):
                    if value_member[idx][jdx].current.name == deref(it).first:
                        add = False
                        break
                    if value_member[idx][jdx].other.name == deref(it).first:
                        add = False
                        break
                if add == False:
                    break
            if add:
                options.push_back(deref(it).first)
            post(it)
        if options.size():
            idx = <node_id_t> (self._rng._rand() * options.size())
            self.adj._remove_edge(node, options[idx])
        else:
            idx = <node_id_t> (self._rng._rand() * self.adj._adj[node].neighbors.size())
            it = self.adj._adj[node].neighbors.begin()
            while idx >= 0:
                idx -= 1
                post(it)
            self.adj._remove_edge(node, deref(it).first)
        return


    # cdef vector[node_id_t] _get_neighbors(self, node_id_t node) nogil:
    #     """
    #     Checks collision of the boid. Ensures the coordinates remain in the
    #     bounding box

    #     Parameters
    #     ----------
    #     node: size_t, boid to update
    #     """
    #     cdef:
    #         double distance
    #         node_id_t other
    #         size_t idx
    #         double weight
    #         double x1, x2
    #         vector[node_id_t] neighbors

    #     for other in range(self._nNodes):
    #         distance = 0
    #         for idx in range(2):
    #             x1 = self._coordinates[node, idx]
    #             x2 = self._coordinates[other, idx]
    #             distance += (x1 - x2)**2
    #         distance = sqrt(distance)
    #         if distance <= self._boid_radius:
    #             if deref(it).first != node:
    #                 neighbors.push_back(deref(it).first)
    #     return neighbors
