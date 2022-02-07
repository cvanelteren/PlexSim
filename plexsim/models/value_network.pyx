## cython: linetrace=True
## cython: binding=True
## distutils: define_macros=CYTHON_TRACE_NOGIL=1
import networkx as nx, numpy as np
cimport numpy as np; np.import_array()
cimport cython
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
                 redundancy = 1,
                 agentStates = np.arange(0, 2, dtype = np.double),
                 consider_options = False,
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
        self._max_bounded_rational = self.dump_rules().number_of_edges()
        self.heuristic = heuristic
        self.redundancy = redundancy
        self._consider_options = consider_options
        self._path_size = self.dump_rules().number_of_nodes()

    @property
    def consider_options(self):
        return self._consider_options

    @consider_options.setter
    def consider_options(self, value):
        if value:
            self._consider_options = True
        else:
            self._consider_options = False
    @property
    def redundancy(self)->int:
        return self._redundancy

    @property
    def max_bounded_rational(self) -> int:
        return self._max_bounded_rational


    @max_bounded_rational.setter
    def max_bounded_rational(self, value):
        self._max_bounded_rational = value

    @redundancy.setter
    def redundancy(self, value):
        if value >= 0:
            self._redundancy = value
        else:
            print(f"Warning trying to set redundancy to {value}")
            print("Should be >= 0")


    @property
    def bounded_rational(self)->int:
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
    def heuristic(self)->int:
        return self._heuristic

    @heuristic.setter
    def heuristic(self, value):
        self._heuristic = value

    # cpdef vector[double] siteEnergy(self, state_t[::1] states):
    #     cdef:
    #         vector[double] siteEnergy = vector[double](self.adj._nNodes)
    #         int node
    #         double Z, energy
    #         state_t* ptr = self._states
    #     # reset pointer to current state
    #     self._states = &states[0]
    #     energy = 0
    #     for node in range(self.adj._nNodes):
    #         # Z = <double> self.adj._adj[node].neighbors.size()
    #         energy = -self._energy(node) #/ <double>(selsf.adj._adj[node].neighbors.size()) # just average
    #         siteEnergy[node] = energy
    #     # reset pointer to original buffer
    #     self._states = ptr
    #     return siteEnergy

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
        cdef Crawler *crawler = new Crawler(
                                    start,
                                    self._states[start],
                                    self._bounded_rational,
                                    self._heuristic,
                                    self._path_size,
                                    verbose)
        cdef vector[vector[EdgeColor]] options = self._check_df(crawler)

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

        options_ = []
        for idx in range(options.size()):
            option = []
            for jdx in range(options[idx].size()):
                e = (options[idx][jdx].current.name,
                     options[idx][jdx].other.name)
                option.append(e)
            options_.append(option)
        return results

    # @cython.profile(True)
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
        cdef bint edge_in_option
        cdef size_t branch_counter = 0

        # exit early if heuristic approach is
        # satisfied
        if self._heuristic:
            if crawler.results.size() == self._heuristic:
                return options

        if crawler.queue.size():
            # pop the queue
            current_edge.current = crawler.queue.back().current
            current_edge.other   = crawler.queue.back().other
            crawler.queue.pop_back()


            # expand path with positive edge only
            if self._rules._adj[current_edge.current.state][current_edge.other.state] > 0:
                crawler.path.push_back(current_edge)

            # # don't allow path to be larger than what is possible
            # with gil:
            #     for idx in range(crawler.path.size()):
            #         print(crawler.path[idx].current.name)
            #         print(crawler.path[idx].other.name)
            #     print(get_path_size(crawler.path))

            if crawler.path.size() <= self._bounded_rational:

                # 1. check endpoints
                if crawler.path.size():
                    # case: leaf node
                    if self.adj._adj[current_edge.other.name].neighbors.size()  == 1:
                        option.clear()
                        option.push_back(current_edge.sort())
                        options.push_back(option)
                        crawler.path.pop_back()
                        return options

                # case: endpoint
                if self._check_endpoint(current_edge.other.state, crawler):
                    if crawler.verbose:
                        with gil:
                            print("At endpoint")
                            print("Inserting edge:")
                            current_edge.sort().print()

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
                    neighbor_idx = deref(it).first
                    proposal_edge.other = ColorNode(neighbor_idx, self._states[neighbor_idx])
                    if crawler.verbose:
                        with gil:
                            print("Considering")
                            proposal_edge.sort().print()

                    # exit early if heuristic approach is
                    # satisfied
                    if self._heuristic:
                        if crawler.results.size() == self._heuristic:
                            return options

                    # case: cycling
                    if proposal_edge.other.name == proposal_edge.current.name:
                        if crawler.verbose:
                            with gil:
                                print("Found node already in path (cycle)")
                                proposal_edge.print()
                        post(it)
                        continue

                    # edge_in_option = False
                    # if crawler.in_options(deref(proposal_edge), options):
                    #     post(it)
                    #     continue


                    # case: negative role-role interaction
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

                    # check if coloring of edge already exists
                    if not crawler.in_vpath(deref(proposal_edge), crawler.path):
                        crawler.queue.push_back(deref(proposal_edge))
                        if crawler.verbose:
                            with gil:
                                print("Adding to branch:")
                                proposal_edge.sort().print()

                        # start merging
                        branch_option = self._check_df(crawler)
                        if branch_option.size():
                            branch_counter += 1
                        crawler.merge_options(options, branch_option)
                        if crawler.verbose:
                            with gil:
                                print("After merging")
                                crawler.print(options)
                    post(it) # never forget :)

                if branch_counter == 0:
                    option.clear()
                    if crawler.path.size():
                        current_edge = crawler.path.back()
                        option.push_back(current_edge.sort())
                        options.push_back(option)

                # crawler.merge_options(options, options)
        if crawler.verbose:
            with gil:
                print("-"*32)
                crawler.print(options)

        # push back current node as option
        if crawler.path.size():
            # option.clear()
            # option.push_back(crawler.path.back().sort())
            # options.push_back(option)
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
            double K
        # cdef double counter = self._match_trees(node)

        # local update
        if self._consider_options == False:
            it = self.adj._adj[node].neighbors.begin()
            while it != self.adj._adj[node].neighbors.end():
                weight   = deref(it).second
                neighbor = deref(it).first
                # check rules
                energy += self._rules._adj[proposal][states[neighbor]]
                post(it)

            # compute positive edges
            K = 0
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


        # energy = energy
        # energy = 1 - 1/(<double>(self._redundancy)) * energy
        # energy = energy/k - energy**2/(2 * (K * self._redundancy))


        # compute completed value networks
        cdef Crawler *crawler = new Crawler(
                                    node,
                                    self._states[node],
                                    self._bounded_rational,
                                    self._heuristic,
                                    self._path_size,
                                    False)

        cdef vector[vector[EdgeColor]] options = self._check_df(crawler)
        for idx in range(crawler.results.size()):
            energy += (crawler.results[idx].size() / <double>(self._bounded_rational)) ** 2

        cdef double max_size = 0
        if self._consider_options:
            for idx in range(options.size()):
                # max_size += options[idx].size() / <double>(self._bounded_rational)
                # if options[idx].size() > max_size:
                    # max_size = options[idx].size()
                energy +=  (options[idx].size() / <double>(self._bounded_rational))**2
                #
        # if options.size():
            # energy += (max_size / <double>(options.size()))**2
        # energy += (max_size / <double>(self._bounded_rational))**2

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
            state_t proposal  = self._sample_proposal()
            state_t cur_state = self._states[node]

            double p = self.probability(proposal, node) / \
                self.probability(cur_state, node)
        if self._rng._rand () < p:
            self._newstates[node] = proposal
        return

    def dump_rules(self):
        """
        Takes the possibly "full" graph, i.e. a networkx graph with negative edges weights,
        and removes all those edges.

        Returns
        -------
        Networkx graph without any negative or zero edge weight.
        """
        edges = [(i, j) for i, j, d in self.rules.edges(data = True)
                 if dict(d).get('weight', 0) > 0]
        return nx.from_edgelist(edges)

# cdef size_t get_path_size(vector[EdgeColor] path) nogil:
#     cdef cset[node_id_t] uniques
#     for idx in range(path.size()):
#         uniques.insert(path[idx].current.name)
#         uniques.insert(path[idx].other.name)
#     return uniques.size()
