from plexsim.models.value_network cimport ValueNetwork
cimport numpy as np
import numpy as np
from cython.operator cimport dereference as deref, postincrement as post
from collections import Counter
from libcpp.unordered_map cimport *
from libcpp.vector cimport *
from libcpp.set cimport set as cset
from libc.math cimport pi

import networkx as nx


cdef double cauchy_pdf(double x, double x0, double gamma):
    return 1.0 / (pi * (1 + ((x - x0)/gamma)**2))


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
                                            self._path_size,
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

        # compute positive role edges
        cdef double K = 0
        kt = self._rules._adj[states[node]].begin()
        while  kt != self._rules._adj[states[node]].end():
            if deref(kt).second > 0:
                K += 1
            post(kt)
        K = K  * self._redundancy
        # piece-wise linear function
        if energy <= K:
            energy = 1/K * energy
        else:
            energy = 1 - (energy * 1/K - 1)

        cdef double completed_vn
        with gil:
            # completed_vn = self._check_gradient(verbose = False)[node]
            completed_vn = self.check_gradient_node(node)
        energy += completed_vn
        return energy


    cdef void _check_sufficient_connected(self, node_id_t node, cset[node_id_t] &suff_connected) nogil:
        """
        checks if the node is sufficiently connected that is satisfies at least the deg of
        the rule graph
        """

        cdef:
            cset[state_t] role_neighbors, neighbor_roles, uni
            size_t role_degree, idx
            state_t node_color
            unordered_map[double, size_t] counter

        node_color = self._states[node]
        # get neighbor roles in social graph
        it = self.adj._adj[node].neighbors.begin()
        while it != self.adj._adj[node].neighbors.end():
            neighbor_roles.insert(self._states[deref(it).first])
            post(it)

        # get neighbor roles in rule graph
        jt = self._rules._adj[node_color].begin()
        role_degree = 0
        while jt != self._rules._adj[node_color].end():
            if deref(jt).second > 0:
                role_neighbors.insert(deref(jt).first)
                role_degree += 1
            post(jt)

        # FIX: resize gaat hier fout
        # uni.resize(min(role_neighbors.size(), neighbor_roles.size()))
        set_intersection(role_neighbors.begin(), role_neighbors.end(),
                        neighbor_roles.begin(), neighbor_roles.end(),
                        insert_iterator[cset[state_t]](uni, uni.begin())
                         )
        # uni.resize(output_iterator - uni.begin())

        # for idx in range(uni.size()):
            # counter[uni[idx]] += 1

        if uni.size() == role_degree:
            suff_connected.insert(node)
        return

    cpdef dict check_gradient(self, verbose: bint = False):
        return dict(self._check_gradient(verbose))

    cpdef object cut_components(self, cset[node_id_t] suff_connected):
        """
        Creates a subgraph in which edges are removed with matching colors
        """
        remapped_connected = [self.adj.rmapping[node] for node in suff_connected]
        subgraph = self.graph.subgraph(remapped_connected)
        subgraphc = subgraph.copy()
        for i, j in subgraph.edges():
            if self._rules._adj[i][j] <= 0:
              subgraphc.remove_edge(i, j)
        return subgraphc


    cpdef double fractional_count(self, cset[node_id_t] nodes, size_t threshold,  bint verbose = False):
        """
        Rick's fractional count estimator
        TODO: check this
        TODO: make this cpp friendly
        """
        if verbose:
            print(nodes)
        cnt = Counter([self._states[self.adj.mapping[node]] for node in nodes])
        # threshold was first set to the number of states in the system
        # I for some reason changed this to a threshold.
        # The input for this function now takes the number of states at some sight radius away
        # This would imply that if the states of those nodes contains doubles, the
        # value network is not unique. Therefore it, it not being completed (locally). At least
        # this was intention.
        if len(cnt) >=  threshold:
            cc_rolecounts = list(Counter([self._states[self.adj.mapping[node]] for node in nodes]).values())
            # let's see if we can also compute a fractional count of VNs (so, if two complete VNs intersect in one role, say B,
            # then the fractional number of VNs would be 1+4/5=1.8 instead of 1.0 as above)
            fractional_num_vns = 0.0
            cc_rolecounts = np.array(cc_rolecounts)  # convert so we can subtract easily
            while not np.max(cc_rolecounts) == 0:
                cnts_of_cnts = Counter(cc_rolecounts)
                fractional_num_vns += 1.0 - float(cnts_of_cnts[0]) / self._nStates
                # subtract all role counts by 1 but don't go negative
                cc_rolecounts = np.max([np.zeros(len(cc_rolecounts)), np.subtract(cc_rolecounts, 1)], axis=0)
        return fractional_num_vns


    cdef unordered_map[node_id_t, double] _check_gradient(self, bint verbose = False):
        """
        Return gradient for all nodes
        """

        cdef:
            unordered_map[node_id_t, double] heuristic
            vector[node_id_t] remapped_connected
            cset[node_id_t] suff_connected
            node_id_t node

        # TODO: check output van deze functie
        for node in range(self.adj._nNodes):
            self._check_sufficient_connected(node, suff_connected)
            heuristic[node] = 0 # default

        # map the labels back
        if verbose:
           print(suff_connected)

        cdef object subgraph = self.cut_components(suff_connected)
        cdef double fractional_num_vns = 0
        for cc in nx.connected_components(subgraph):
            fractional_num_vns = self.fractional_count(cc, self._nStates)
            for node in cc:
                heuristic[self.adj.mapping[node]] += fractional_num_vns
        return heuristic

    cpdef double check_gradient_node(self, node_id_t node):
        """
        Check gradient from a node point of view

        1. check node sufficiently connected.
        2. Check for all the the sufficient connected its neighbors
        """
        cdef:
            vector[node_id_t] remapped_connected
            cset[node_id_t] suff_connected
            cset[node_id_t] neighbors
            # check number of edges + 1 additional as it is a size_t
            size_t sight = self._bounded_rational + 2

            # loop stuff
            node_id_t proposal
            node_id_t neighbor
            vector[node_id_t] queue
            size_t old_size = suff_connected.size()

        # init queue
        queue.push_back(node)
        # node is connected
        while sight > 0 and queue.size():
            # decrease sight
            sight -= 1
            # generate new proposal
            proposal = queue.back()
            queue.pop_back()
            # sufficient connected will generate new proposals
            self._check_sufficient_connected(proposal, suff_connected)

            # node was sufficiently connected
            if suff_connected.size() > old_size:
                old_size = suff_connected.size()
                this_state = self._states[proposal]

                # check all neighbors with valid color assignments
                it = self.adj._adj[proposal].neighbors.begin()
                while it != self.adj._adj[proposal].neighbors.end():
                    neighbor = deref(it).first
                    other_state = self._states[neighbor]
                    if self._rules._adj[this_state][other_state] > 0:
                        queue.push_back(neighbor)
                    post(it) # never forget

        #
        cdef size_t states_at_distance_n = len(
            nx.generators.ego.ego_graph(
                self.dump_rules(),
                self._states[node],
                radius = self._bounded_rational)
        )

        return self.fractional_count(suff_connected, states_at_distance_n)
#        return self.fractional_count(suff_connected, self._bounded_rational)
