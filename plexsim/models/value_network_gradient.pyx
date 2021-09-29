from plexsim.models.value_network cimport ValueNetwork
cimport numpy as np
import numpy as np
from cython.operator cimport dereference as deref, postincrement as post
from collections import Counter
from libcpp.unordered_map cimport *
from libcpp.vector cimport *

import networkx as nx


cdef class VNG(ValueNetwork):
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

        super(VNG, self).__init__(graph = graph,
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
                                            False)
        # search for completed vns
        self._check_df(crawler)
        # energy += crawler.results.size()
        completed_vn = crawler.results.size()
        self._completed_vns[node] = completed_vn
        return


    cdef double _energy(self, node_id_t node) nogil:
        """ Computed the local energy of a node
        """
        cdef:
            size_t neighbors = self.adj._adj[node].neighbors.size()
            state_t* states = self._states # alias
            size_t  neighbor, neighboridx
            double weight # TODO: remove delta

            double energy  = self._H[node] * self._states[node]

        if self._nudges.find(node) != self._nudges.end():
            energy += self._nudges[node] * self._states[node]

        # compute the energy
        cdef:
            pair[bint, pair[state_t, double]] rule;
            double update
            MemoizeUnit memop

        cdef size_t idx

        #TODO: cleanup
        # get the distance to consider based on current state
        #cdef size_t distance = self.distance_converter[proposal]
        # only get nodes based on distance it can reach based on the value network
        # current state as proposal
        cdef state_t proposal = self._states[node]
        cdef:
            state_t start
            rule_t rule_pair
            size_t j
        # cdef double counter = self._match_trees(node)

        # local update
        it = self.adj._adj[node].neighbors.begin()
        while it != self.adj._adj[node].neighbors.end():
            weight   = deref(it).second
            neighbor = deref(it).first
            # check rules
            energy += self._rules._adj[proposal][states[neighbor]]
            post(it)

        # piece-wise linear function

        # compute positive edges
        cdef double k = 0
        jt = self._rules._adj[proposal].begin()
        while jt != self._rules._adj[proposal].end():
            if deref(jt).second > 0:
                k += deref(jt).second
            post(jt)
        kt = self._rules._adj[states[node]].begin()

        cdef size_t K = 0
        while  kt != self._rules._adj[states[node]].end():
            if deref(kt).second > 0:
                K += 1
            post(kt)

        # energy = energy
        # energy = 1 - 1/(<double>(self._redundancy)) * energy
        energy = energy/k - energy**2/(2 * (K * self._redundancy))
        cdef unordered_map[node_id_t, double] completed_vn
        with gil:
            completed_vn = self._check_gradient(verbose = False)
        energy += completed_vn[node]
        return energy


    cdef void _check_sufficient_connected(self, node_id_t node, vector[node_id_t] &suff_connected) nogil:
        """
        checks if the node is sufficiently connected that is satisfies at least the deg of
        the rule graph
        """

        cdef:
            vector[state_t] role_neighbors, neighbor_roles, uni
            size_t role_degree, idx
            state_t node_color
            unordered_map[double, size_t] counter

        node_color = self._states[node]
        # get neighbor roles in social graph
        it = self.adj._adj[node].neighbors.begin()
        while it != self.adj._adj[node].neighbors.end():
            neighbor_roles.push_back(self._states[deref(it).first])
            post(it)

        # get neighbor roles in rule graph
        jt = self._rules._adj[node_color].begin()
        role_degree = 0
        while jt != self._rules._adj[node_color].end():
            if deref(jt).second > 0:
                role_neighbors.push_back(deref(jt).first)
                role_degree += 1
            post(jt)

        uni.resize(min(role_neighbors.size(), neighbor_roles.size()))
        output_iterator = set_intersection(role_neighbors.begin(), role_neighbors.end(),
                        neighbor_roles.begin(), neighbor_roles.end(),
                        uni.begin()
                         )
        # uni.resize(output_iterator - uni.begin())

        # for idx in range(uni.size()):
            # counter[uni[idx]] += 1

        if uni.size() == role_degree:
            suff_connected.push_back(node)
        return

    cpdef dict check_gradient(self, verbose: bint = False):
        return dict(self._check_gradient(verbose))

    cdef unordered_map[node_id_t, double] _check_gradient(self, bint verbose = False):
        """
        Return gradient for all nodes
        """

        cdef:
            unordered_map[node_id_t, double] heuristic
            vector[node_id_t] suff_connected, remapped_connected
            node_id_t node

        for node in range(self.adj._nNodes):
            self._check_sufficient_connected(node, suff_connected)
            heuristic[node] = 0 # default

        # map the labels back
        remapped_connected = [self.adj.rmapping[node] for node in suff_connected]
        if verbose:
           print(suff_connected)
        # # TODO: make this cpp friendly
        subgraph = self.graph.subgraph(remapped_connected)
        for cc in nx.connected_components(subgraph):
            if verbose:
                print(cc)
            cnt = Counter([self._states[self.adj.mapping[node]] for node in cc])
            if len(cnt) >= self._nStates:
                cc_rolecounts = list(Counter([self._states[self.adj.mapping[node]] for node in cc]).values())
                # let's see if we can also compute a fractional count of VNs (so, if two complete VNs intersect in one role, say B, then the fractional number of VNs would be 1+4/5=1.8 instead of 1.0 as above)
                fractional_num_vns = 0.0
                cc_rolecounts = np.array(cc_rolecounts)  # convert so we can subtract easily
                while not np.max(cc_rolecounts) == 0:
                    cnts_of_cnts = Counter(cc_rolecounts)
                    fractional_num_vns += 1.0 - float(cnts_of_cnts[0]) / self._nStates
                    cc_rolecounts = np.max([np.zeros(len(cc_rolecounts)), np.subtract(cc_rolecounts, 1)], axis=0)  # subtract all role counts by 1 but don't go negative

                # # assign  fractional num_vns per node
                # if fractional_num_vns > 1:
                #     fractional_num_vns = 1
                # else:
                #     fractional_num_vns = 0

                for node in cc:
                    heuristic[self.adj.mapping[node]] += fractional_num_vns
        return heuristic
