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
                 agentStates = np.arange(0, 2, dtype = np.double),
                 **kwargs
                 ):
        super(ValueNetwork, self).__init__(graph = graph,
                                     agentStates = agentStates,
                                     rules = rules,
                                     t = t,
                                     **kwargs)

        self.verbose = False
        self.bounded_rational = bounded_rational

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
            assert 1 <= value <= len(self.rules)
        self._bounded_rational = int(value)

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
        
    # TODO tmp
    @property
    def pat(self):
        return self.paths

    cpdef bint check_doubles(self, list path, list results, bint verbose = False):
        """
        Don't allow for double edges
        Adds path inplace if it does not occur in results
        """
        add = True
        if path:
            for r in results[0]:
                if all([True if i in r or i[::-1] in r else False for i in path]):
                    add = False
                    break

            if add:
                if verbose:
                    print(f"adding {path} to {results[0]}")
                results[0].append(path.copy())
        return add

    cdef bint _check_endpoint(self, state_t current_state, Crawler *crawler) nogil:
        """"
        Checks the endpoint of the value network
        @param: current_state, double state of the edge looking towards its neighbors
        @param: crawler, crawler_t, crawler object (see header)
        """
        # update paths
        cdef size_t idx
        cdef state_t other_state
        cdef double weight_edge


        # count frequency of end point occurence
        cdef size_t counter = 0

        it = self._rules._adj[current_state].begin()
        while it != self._rules._adj[current_state].end():
            other_state = deref(it).first
            weight_edge = deref(it).second
            if weight_edge > 0:
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
        if counter == self._rules._adj[current_state].size():
            is_endpoint = True

        return is_endpoint


    cpdef list check_df(self, node_id_t start, bint verbose = False):
        cdef Crawler *crawler = new Crawler(start,
                                             self._states[start],
                                        self._bounded_rational,
                                        verbose)
        crawler = self._check_df(crawler)
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
                results[-1].append((e, ev))
                post(jt)
            post(it)
        del crawler
        return results

    cdef Crawler* _check_df(self, Crawler *crawler) nogil:
        """
           # steps:
           # 1. check end points
           # 2. check neighbors
           # 3. check branch
           # 4. check merge

        """
        cdef EdgeColor *current_edge
        cdef EdgeColor *proposal_edge = new EdgeColor()
        cdef vector[EdgeColor] option
        cdef double edge_weight
        cdef size_t idx
        if crawler.queue.size():
            # pop the queue
            current_edge = &crawler.queue.back()
            crawler.queue.pop_back()
            if crawler.verbose:
                with gil:
                    print(f"{current_edge.current.name=}")
                    print(f"{current_edge.other.name=}")
                    print(f"{current_edge.current.state=}")
                    print(f"{current_edge.other.state=}")

            if current_edge.current.name != current_edge.other.name:
                crawler.path.push_back(deref(current_edge))

            # 1. check endpoints
            if self._check_endpoint(current_edge.current.state, crawler):
                option.push_back(deref(current_edge))
                crawler.options.push_back(option)

                # if crawler.verbose:
                #     with gil:
                #         print(f"At end point, pushing: ")
                #         print(f" {current_edge.current.name=}")
                #         print(f" {current_edge.other.name=}")
                #         print(f" {current_edge.current.state=}")
                #         print(f" {current_edge.other.state=}")


                # pop the path from current path
                if crawler.path.size():
                    crawler.path.pop_back()
                return crawler


            # create new proposal edge
            # proposal_edge.current.name = current_edge.current.name
            # proposal_edge.current.state = current_edge.current.state

            proposal_edge.current.name = current_edge.other.name
            proposal_edge.current.state = current_edge.other.state

            # 2. check neighbors
            it = self.adj._adj[current_edge.current.name].neighbors.begin()
            while it != self.adj._adj[current_edge.current.name].neighbors.end():

                proposal_edge.other.name = deref(it).first
                proposal_edge.other.state = self._states[deref(it).first]
                # proposal_edge.other.name = current_edge.current.name
                # proposal_edge.other.state = current_edge.current.state

                # if deref(it).first < current_edge.current.name:
                #     proposal_edge.current.name = deref(it).first
                #     proposal_edge.current.state = self._states[deref(it).first]

                #     proposal_edge.other.name = current_edge.current.name
                #     proposal_edge.other.state = current_edge.current.state

                # else:
                #     proposal_edge.other.name = deref(it).first
                #     proposal_edge.other.state = self._states[deref(it).first]

                #     proposal_edge.current.name = current_edge.current.name
                #     proposal_edge.current.state = current_edge.current.state

                if crawler.verbose:
                    with gil:
                        print(f"At {proposal_edge.current.name=}")
                        print(f"Checking {proposal_edge.other.name=}")
                        crawler.print()

                if deref(it).first == current_edge.other.name:
                    if crawler.verbose:
                        with gil:
                            print("Found node already in path (cycle)")

                # check if branch is valid
                edge_weight = self._rules._adj[current_edge.current.state][deref(it).first]
                # 3. step into brach
                if edge_weight > 0:
                    if not crawler.in_path(deref(proposal_edge)):
                        if crawler.verbose:
                            with gil:
                                print("Pushing")
                                print(f"{proposal_edge.current.name=}")
                                print(f"{proposal_edge.other.name=}")
                        crawler.queue.push_back(deref(proposal_edge))
                        self._check_df(crawler)

                post(it) # never forget :)

            # 4. merge options
            edge_weight = self._rules._adj[current_edge.current.state][current_edge.other.state]

            if edge_weight > 0:
                if not crawler.in_options(deref(current_edge)):

                    option.clear()
                    option.push_back(deref(current_edge))
                    crawler.options.push_back(option)

                    if crawler.verbose:
                        with gil:
                            print(f"{edge_weight=}")

            # merge options
            crawler.merge_options()
            if crawler.verbose:
                with gil:
                    print("done merging")
                    print(f"{crawler.results.size()=}")
                    print(f"{crawler.options.size()=}")

        # check if current path contains solution
        if crawler.verbose:
            with gil:
                print(f"{crawler.path.size()=} {self._bounded_rational=}")
                crawler.print()

        if crawler.path.size() == self._bounded_rational:
            crawler.add_result(crawler.path)

        # reduce path length
        if crawler.path.size():
            crawler.path.pop_back()
        return crawler



    cdef double _energy(self, node_id_t node) nogil:
        """
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

        cdef Crawler *crawler = new Crawler(node, self._states[node], self._bounded_rational)
        crawler = self._check_df(crawler)
        energy += crawler.results.size()



        cdef size_t mi
        # TODO: move to separate function
        for mi in range(self._memorySize):
            energy += exp(mi * self._memento) * self._hamiltonian(states[node], self._memory[mi, node])
        return energy
        # try-out match trees:
        # return energy * (1 + counter)
        #return energy + counter


    cdef double probability(self, state_t state, node_id_t node) nogil:
        cdef state_t tmp = self._states[node]
        self._states[node] = state
        cdef:
            double energy = self._energy(node)
            double p = exp(self._beta * energy)

        self._states[node] = tmp
        return p

    # default update TODO remove this
    cdef double _hamiltonian(self, state_t x, state_t  y) nogil:
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

