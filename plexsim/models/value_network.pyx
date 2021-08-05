import networkx as nx, numpy as np
cimport numpy as np, cython
from cython.parallel cimport parallel, prange, threadid
from cython.operator cimport dereference as deref, postincrement as post
from libc.math cimport exp, cos, pi

from libcpp.set cimport set as cset

cdef extern from "<iterator>" namespace "std":
    void advance(Iter, size_t n)

cdef extern from "<algorithm>" namespace "std" nogil:
    void swap[T] (T &a, T &b)

cdef class ValueNetwork(Potts):
    def __init__(self, graph,
                 rules,
                 t = 1,
                 bounded_rational = -1,
                 heuristic = 0,
                 agentStates = np.arange(0, 2, dtype = np.double),
                 **kwargs
                 ):
        """Model for studying value network

        Novel computational  model developed by  van Elteren
        (2021) for studying value networks.

        Parameters
        ----------
        graph : nx.Graph or nx.DiGraph
            Interaction structure of the system
        rules : nx.Graph or nx.DiGraph
            Role-role interaction structure
        t : double
            Noise level of the system
        bounded_rational : int
            Bounded  rationality  implementation;  indicates
            how far an agent is affected in the network.
        agentStates : np.ndarray
            Role labels
        **kwargs : dict
            General model settings (see Model)

        Examples
        --------
        FIXME: Add docs.

        """
        super(ValueNetwork, self).__init__(graph = graph,
                                     agentStates = agentStates,
                                     rules = rules,
                                     t = t,
                                     **kwargs)

        self.verbose = False
        self.bounded_rational = bounded_rational
        self.heuristic = heuristic

    @property
    def bounded_rational(self):
        return self._bounded_rational
    @bounded_rational.setter
    def bounded_rational(self, value):
        # default value to full edges
        if value == -1:
            tmp = [True for k, v in
                   nx.get_edge_attributes(self.rules, 'weight').items() if v > 0]
            value = len(tmp)
        else:
            assert 1 <= value <= self.rules.number_of_edges()
        self._bounded_rational = int(value)

    @property
    def heuristic(self):
        return self._heuristic
    @heuristic.setter
    def heuristic(self, value):
        self._heuristic = value

    cpdef vector[double] siteEnergy(self, state_t[::1] states):
        cdef:
            vector[double] siteEnergy = vector[double](self.adj._nNodes)
            int node
            double Z, energy
            state_t* ptr = self._states
        # reset pointer to current state
        self._states = &states[0]
        energy = 0
        for node in range(self.adj._nNodes):
            # Z = <double> self.adj._adj[node].neighbors.size()
            energy = - self._energy(node) #/ <double>(self.adj._adj[node].neighbors.size()) # just average
            siteEnergy[node] = energy
        # reset pointer to original buffer
        self._states = ptr
        return siteEnergy

    cdef double  magnetize_(self, Model mod, size_t n, double t):
        """ Custom magnetization function

        Computed average number  of completed value networks
        for a given temperature.

        Parameters
        ----------
        mod: Model of type ValueNetwork

        \n: int
            Number of samples to take.
        \t: double
            temperature(noise) of the system.

        Returns
        -------
        Number of completed value networks
        """
        # setup simulation
        cdef double Z = 1 / <double> self._nStates
        mod.t         =  t
        # calculate phase and susceptibility
        #mod.reset()
        mod.states[:] = mod.agentStates[0]
        res = mod.simulate(n)
        #res = np.array([mod.siteEnergy(i) for i in res]).mean()
        res = np.array([mod.siteEnergy(i) for i in res]).mean()
        return res
        #return np.array([self.siteEnergy(i) for i in res]).mean()
        #return np.abs(np.real(np.exp(2 * np.pi * np.complex(0, 1) * res)).mean())
        #return res
        

    # cdef void _prune_options(self, Crawler *crawler) nogil:
    #     """ Removes options that  cannot be reached from the
    #     current node anymore """

    #     cdef:
    #         EdgeColor *current_edge = &crawler.path.back()
    #         vector[EdgeColor] option
    #         size_t idx
    #         bint prune
    #         double weight
    #         size_t counter
    #     # check all options
    #     # prune options that are not reachable by the current edge in path
    #     for idx in range(crawler.options.size() - 1, 0):
    #         option = crawler.options[idx]
    #         # assume prune
    #         prune = True
    #         counter = 0
    #         for jdx in range(option.size() - 1, 0):
    #             weight = self._rules._adj[current_edge.other.state][option[jdx].current.state]
    #             if weight > 0:
    #                 counter += 1
    #         if counter == 0:
    #             crawler.options.erase( crawler.options.begin() + idx)
    #     return






    cdef bint _check_endpoint(self, state_t current_state, Crawler *crawler) nogil:
        """"
        Checks endpoint of the role space

        Parameters
        ==========
        current_state: state_t
            Checks  for the  current edge  state whether  it
            could in principle complete the value network
        \crawler: pointer to crawler object
            Holds the paths, completed value networks and possible paths(see cpp implementation)

        Returns
        =======
        Bool value whether the current state is an endpoint.
        True if it is and endpoint, False otherwise.

        """
        # update paths
        cdef size_t idx
        cdef state_t other_state
        cdef double weight_edge


        # count frequency of end point occurence
        cdef size_t counter = 0
        cdef size_t target = 0

        it = self._rules._adj[current_state].begin()
        while it != self._rules._adj[current_state].end():
            other_state = deref(it).first
            weight_edge = deref(it).second

            if weight_edge > 0:
                target += 1
                # traverse path and find the edge
                # TODO: smartify this with set operation?
                jt = crawler.path.begin()
                while jt != crawler.path.end():
                    # check if the value edge exists
                    if current_state == deref(jt).current.state:
                        if other_state == deref(jt).other.state:
                            counter += 1
                    # check if reverse of value edge exists
                    if current_state == deref(jt).other.state:
                        if other_state == deref(jt).current.state:
                            counter += 1
                    post(jt)
            post(it)
        cdef bint is_endpoint = False
        if counter == target:
            is_endpoint = True
        return is_endpoint


    cpdef list check_df(self, node_id_t start, bint verbose = False):
        """ Computes completed value networks

        Recursively checks for a node in the current system state
        the number of completed value networks.

        Parameters
        ==========
        start: node_id_t
            Node label which to check the completed value networks for.
        verbose: bool (default False)
            For debugging.

        Returns
        =======
        List of paths from the node that completes the value networks
        """
        cdef Crawler *crawler = new Crawler(start,
                                        self._states[start],
                                        self._bounded_rational,
                                        self._heuristic,
                                        verbose)
        self._check_df(crawler)

        cdef list results = []

        # cdef cset[cset[EdgeColor]].iterator it = crawler.results.begin()
        # cdef cset[EdgeColor].iterator jt

        cdef vector[vector[EdgeColor]].iterator it = crawler.results.begin()
        cdef vector[EdgeColor].iterator jt

        while it != crawler.results.end():
            jt = deref(it).begin()
            results.append([])
            while jt != deref(it).end():
                e = [deref(jt).current.name, deref(jt).other.name]
                ev = [deref(jt).current.state, deref(jt).other.state]
                # results[-1].append((e, ev))
                results[-1].append(e)
                post(jt)
            post(it)
        del crawler
        return results

    cdef vector[vector[EdgeColor]] _check_df(self, Crawler *crawler) nogil:
        """  Low level callable for check_df
        The function works recursively via a depth-first search approach.

        In order to check the completed value networks one must:
         steps:
            1. check end points
            2. check neighbors
            3. check branch
            4. check merge

        Parameters
        ==========
        *crawler: pointer to crawler object

        Returns
        =======
        *crawler: pointer to crawler object
        """
        cdef EdgeColor current_edge
        cdef EdgeColor *proposal_edge = new EdgeColor()
        cdef vector[EdgeColor] option
        cdef vector[vector[EdgeColor]] options
        cdef vector[vector[EdgeColor]] branch_options, branch_option
        cdef double edge_weight
        cdef size_t idx, opt_idx, bidx
        cdef node_id_t neighbor_idx

        # exit early if heuristic approach is
        # satisfied

        if self._heuristic:
            if crawler.results.size() == self._heuristic:
                return options

        # with gil:
        #     import time; time.sleep(.2)

        if crawler.queue.size():
            # pop the queue
            current_edge.current = crawler.queue.back().current
            current_edge.other   = crawler.queue.back().other
            crawler.queue.pop_back()
            # expand path with positive edge
            if self._rules._adj[current_edge.current.state][current_edge.other.state] > 0:
                crawler.path.push_back(current_edge)

            # 1. check endpoints
            if self._check_endpoint(current_edge.other.state, crawler):
                if crawler.verbose:
                    with gil:
                        print("At endpoint")
                        print("Inserting edge:")
                    current_edge.print()

                option.clear()
                # add option
                option.push_back(crawler.path.back().sort())
                options.push_back(option)

                # pop the path from current path
                crawler.path.pop_back()
                return options

            proposal_edge.current = ColorNode(current_edge.other.name,
                                              current_edge.other.state)

            # 2. check neighbors
            it = self.adj._adj[current_edge.other.name].neighbors.begin()
            while it != self.adj._adj[current_edge.other.name].neighbors.end():

                # exit early if heuristic approach is
                # satisfied

                if self._heuristic:
                    if crawler.results.size() == self._heuristic:
                        return options

                neighbor_idx = deref(it).first
                proposal_edge.other = ColorNode(neighbor_idx, self._states[neighbor_idx])

                if proposal_edge.other.name == proposal_edge.current.name:
                    if crawler.verbose:
                        with gil:
                            print("Found node already in path (cycle)")
                    post(it)
                    continue

                # check if branch is valid
                edge_weight = self._rules._adj[proposal_edge.current.state][proposal_edge.other.state]
                # 3. step into brach
                if edge_weight <= 0:
                    if crawler.verbose:
                        with gil:
                            print(f"Found negative {edge_weight=}")
                        proposal_edge.print()
                    post(it)
                    continue

                if crawler.verbose:
                    with gil:
                        print("Considering")
                    proposal_edge.print()

                # check if coloring of edge already exists
                if not crawler.in_vpath(deref(proposal_edge), crawler.path):
                    crawler.queue.push_back(deref(proposal_edge))
                    if crawler.verbose:
                        with gil:
                            print("Adding to branch:")
                            proposal_edge.sort().print()
                            crawler.print(options)

                    # start merging
                    branch_option = self._check_df(crawler)
                    crawler.merge_options(options, branch_option)

                post(it) # never forget :)
            # crawler.merge_options(options, options)
            if crawler.verbose:
                crawler.print(options)

        # push back current node as option
        if crawler.path.size():
            option.clear()
            option.push_back(crawler.path.back().sort())
            options.push_back(option)
            crawler.path.pop_back()
        return options



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

        cdef Crawler *crawler = new Crawler(node,
                                            self._states[node],
                                            self._bounded_rational,
                                            self._heuristic,
                                            False)
        self._check_df(crawler)
        energy += crawler.results.size()
        del crawler

        cdef size_t mi
        # TODO: move to separate function
        for mi in range(self._memorySize):
            energy += exp(mi * self._memento) * self._hamiltonian(states[node], self._memory[mi, node])
        return energy
        # try-out match trees:
        # return energy * (1 + counter)
        #return energy + counter


    cdef double probability(self, state_t state, node_id_t node) nogil:
        """ See base model
        """
        cdef state_t tmp = self._states[node]
        self._states[node] = state
        cdef:
            double energy = self._energy(node)
            double p = exp(self._beta * energy)

        self._states[node] = tmp
        return p

    # default update TODO remove this
    cdef double _hamiltonian(self, state_t x, state_t  y) nogil:
        """ Node Hamiltonian based on Potts model
        The Hamiltonian is not used if a rule exists, i.e. if
        a rule exists between two spin states this method is skipped.
        This function serves as a fallback function in case partial
        rules are used.
        """
        return cos(2 * pi  * ( x - y ) * self._z)

    cdef void _step(self, node_id_t node) nogil:
        cdef:
            state_t proposal = self._sample_proposal()
            state_t cur_state= self._states[node]
            double p     = self.probability(proposal, node) / \
                self.probability(cur_state, node)
        if self._rng._rand () < p:
            self._newstates[node] = proposal
        return

    def dump_rules(self) -> nx.Graph or nx.DiGraph:
        """
        Takes the possibly "full" graph, i.e. a networkx graph with negative edges weights,
        and removes all those edges.

        Returns
        -------
        Networkx graph without any negative or zero edge weight.
        """
        edges = [(i, j) for i, j, d in self.rules.edges(data = True) if dict(d).get('weight', 0) > 0]
        return nx.from_edgelist(edges)
