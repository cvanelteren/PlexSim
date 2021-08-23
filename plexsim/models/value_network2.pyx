import networkx as nx, numpy as np
cimport numpy as np, cython
from cython.parallel cimport parallel, prange, threadid
from cython.operator cimport dereference as deref, preincrement, postincrement as post
from libc.math cimport exp, cos, pi
from libcpp.set cimport set as cset

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
            assert 1 <= value <= self.rules.number_of_edges()
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

    cpdef void merge(self, list results, bint verbose = False):
        """
        Merge paths from branches inplace
        """
        # skip edge case
        if len(results[1]) < 2:
            return
        # attempt to merge branches
        # merged = [[], []]
        # merged = []
        merged = results[1].copy()
        # go through all the combinations in the options
        can_merge = True

        # set to false
        # will be set to true if a merge is found
        if verbose:
            print("staring merge")
        while can_merge:
            can_merge = False
            # print(f"Merging {merged}")
            for idx, opti in enumerate(merged):
                for jdx, optj in enumerate(merged):
                    if idx < jdx:
                        # prevent self-comparison and double comparison
                        # compare matched edges
                        idxs, vpi = opti; jdxs, vpj = optj
                        # if the overlap is zero then the branches are valid
                        # and should be merged
                        # (not sure if this is necessary)
                        J = True; a, b = vpi, vpj
                        if len(vpi) > len(vpj):
                            a, b = b, a
                        for i in a:
                            # if the rule edge already exists
                            # ignore the option
                            if i in b or i[::-1] in b:
                                J = False
                        # add if no overlap is found
                        if J:
                            # merging
                            # print(f"Merging {vpi} with {vpj}")
                            proposal = [idxs.copy(), vpi.copy()]
                            for x, y in zip(jdxs, vpj):
                                proposal[0].append(x)
                                proposal[1].append(y)

                            if proposal not in merged:
                                if len(proposal[0]) == self._bounded_rational:
                                    self.check_doubles(proposal[0], results)
                                else:
                                    merged.append(proposal.copy())
                                    can_merge = True

        if verbose:
            print("left merge")
        if merged:
            results[1] = merged

    cpdef bint check_endpoint(self, state_t s, list vp_path):
        """
        Check if an end point is reached
        """
        # update paths
        fail = True
        it = self._rules._adj[s].begin()
        while it != self._rules._adj[s].end():
            if deref(it).second > 0:
                if [s, deref(it).first] not in vp_path:
                        fail = False
            post(it)
               # print(f"Failing {fail} {s} {list(m.rules.neighbors(s))} {vp_path}")
        return fail

    cpdef bint _traverse(self, list proposal, list option):
        cdef dict seen = {}
        cdef list edge

        cdef bint traverse = True
        while traverse:
            traverse = False
            for edge in option:
                # traverse up
                if edge[0] in list(self.adj._adj[proposal[1]].neighbors):
                    if tuple(edge) not in seen:
                        seen[tuple(edge)] = 1
                        traverse = True
                        proposal = edge
            if traverse:
                return True
            else:
                return False


        if len(seen) == len(option):
            return True
        else:
            return False


    cpdef void check_traversal(self, list proposal, list options,
                               bint verbose = False):
        cdef list option
        cdef size_t idx
        for idx, option in enumerate(options):
            # print(proposal, option)
            if not self._traverse(proposal.copy()[0], option[0]):
                options.pop(idx)
                if verbose:
                    print(f"Popping option {option} with prop {proposal}")


    cpdef list check_df(self, node_id_t start, bint verbose = False):
        cdef list queue = [(start, start)]
        return self._check_df(queue, path = [], vp_path = [],
                              results = [[], []], verbose = verbose)[0]
    cpdef list _check_df(self, list queue, list path = [],
                        list vp_path = [],
                        list results = [],
                        bint verbose = False):
        """
        :param queue: edge queue, start with (node, node)
        :param n: number of edges in the rule graph
        :param m: model
        :param path: monitors edges visited in social network
        :param vp_path: monitors edges visited in value network
        :param results: output. List of 2. First index contained completed value networks, second index contains branch options
        :param verbose: print intermediate step for heavy debugging!
        """
        cdef str node
        cdef node_id_t from_node, current
        cdef state_t s, ss
        cdef list e, ev, option
        if queue:
            # get current node
            from_node, current = queue.pop()
            node = self.adj.rmapping[current]
            # empty local options
            # results[1] = []
            s = self.states[current]
            # check only if difference
            #
            e = [current, from_node]
            if current != from_node:
                path.append(e)
                vp_path.append([self.states[current], self.states[from_node]])

            if verbose:
                print(f"checking edge {e} path is {path}")

            # logging
            if verbose:
                print(f"At {current}")
                print(f"Path : {path}")
                print(f"Vp_path : {vp_path}")
                print(f"Options: {results[1]}")
                print(f"Results: {results[0]}")


            # check if no options left in rule graph
            if self.check_endpoint(s, vp_path):
                option = [
                    [ sorted([from_node, current]) ],
                    [ sorted([self.states[from_node], self.states[current]]) ]
                    ]
                results[1].append(option)
                if verbose:
                    print(f"At an end point, pushing {option}")

                # pop path
                if len(path):
                    path.pop()
                    vp_path.pop()

                return results

            # check neighbors
            for neigh in self.graph.neighbors(node):
                other = self.adj.mapping[neigh]
                ss = self.states[other]
                # prevent going back
                if other == from_node:
                    if verbose: print("found node already in path (cycle)")
                    continue
                # check if branch is valid
                if self._rules._adj[s][ss] <= 0:
                    if verbose: print('negative weight')
                    continue
                # construct proposals
                e = [current, other]
                ev = [s, ss]

                # step into branch
                if e not in path and e[::-1] not in path:
                    if ev not in vp_path and ev[::-1] not in vp_path:
                        queue.append(e)
                        # get branch options
                        self._check_df(queue, path,
                                                vp_path,
                                                results,
                                                verbose)

                        # for option in self.check_df(queue, path,
                        #                         vp_path,
                        #                         results,
                        #                         verbose)[1]:
                        #     results[1].append(option.copy())

                            # if verbose:
                                # print(f"Retrieved {option}")
                    # move to next
                    else:
                        continue
                # move to next
                else:
                    continue
            # attempt merge

            option = [
                    [ sorted([from_node, current]) ],
                    [ sorted([self.states[from_node], self.states[current]]) ]
                    ]

            if self._rules._adj[option[1][0][0]][option[1][0][1]] > 0:
                # self.check_traversal(option[0], results[1],
                                     # verbose)
                if option not in results[1]:
                    results[1].append(option)

            self.merge(results, verbose)
            # TODO self edges are ignored --> add check for negativity
            # no edge is checked after this point, all done above
            # this causes a fail on the start node that should have a negative weight
            for idx, option in enumerate(results[1]):
                if len(option[1]) == self._bounded_rational:
                    # remove from option list
                    results[1].pop(idx)
                    self.check_doubles(option[0].copy(), results, verbose)
                    if verbose:
                        print(f'adding results {option[0]} {self.bounded_rational} vp = {option[1]}')


            # for idx, merged in enumerate(results[1]):
            #     if verbose:
            #         print(f"{idx} Considering merging {this_option} with {merged} {vp_path}")
            #     # they cannot be in the already present path
            #     if this_option[1] not in merged[1] and this_option[1][::-1] not in merged[1]:
            #         # start point is a self edge
            #         # only add if the weight is actually positive
            #         if self.rules[this_option[1][0]][this_option[1][1]]['weight'] > 0:
            #             # construct proposals
            #             merged[0].append(this_option[0])
            #             merged[1].append(this_option[1])
            #             if verbose:
            #                 print(f"{idx} merged {this_option} yielding {merged}")
            #     if len(merged[1]) == self._bounded_rational:
            #         # remove from option list
            #         results[1].pop(idx)
            #         self.check_doubles(merged[0].copy(), results)
            #         if verbose:
            #             print(f'adding results {merged[0]} {self.bounded_rational} vp = {merged[1]}')

        # check if the solution is correct
        if len(vp_path) == self._bounded_rational:
            self.check_doubles(path.copy(), results)
            if verbose: print('added path', results)

        if len(path):
            path.pop()
            vp_path.pop()

        return results

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

        with gil:
            energy +=  len(self._check_df([[node, node]], path = [], vp_path = [],
                                        results= [[], []], verbose = False)[0])



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



# cdef class ValueNetworkNP(Potts):

#     def __init__(self, graph,
#                  rules,
#                  t = 1,
#                  bounded_rational = 1,
#                  agentStates = np.arange(0, 2, dtype = np.double),
#                  alpha = 1,
#                  **kwargs
#                  ):
#         super(ValueNetworkNP, self).__init__(graph = graph,
#                                      agentStates = agentStates,
#                                      rules = rules,
#                                      **kwargs)

#         self.bounded_rational = bounded_rational
#         self.alpha = alpha
#         self.setup_rule_paths()
#         self.setup_values()


#     @property
#     def test(self):
#         print(self.paths)
#         print(self.paths_rules)
#     #construct shortest path among nodes
#     cpdef void compute_node_path(self, node_id_t node):
#         cdef str node_label = self.adj.rmapping[node]
#         cdef size_t path_counter = 0
#         # idx acts as dummy merely counting the seperate unique paths
#         sp = nx.single_source_shortest_path_length(self.graph, node_label, cutoff = self._bounded_rational)
#         for other, distance in sp.items():
#             # add the non-local influences
#             # note the node_label is the start node here; ignore that in future reference
#             node_other = self.adj.mapping[str(other)]
#             distance = float(distance)
#             self.paths[node][distance].push_back(node_other)
#             path_counter += 1
#         return

#     cpdef void setup_values(self, int bounded_rational = 1):
#         #pr = ProgBar(len(self.graph))
#         # store the paths
#         self.paths.clear()
#         import pyprind as pr
#         cdef object pb = pr.ProgBar(len(self.graph))
#         cdef size_t i, n = self.adj._nNodes
#         for i in prange(0, n, nogil = 1):
#             with gil:
#                 self.compute_node_path(i)
#                 pb.update()
#         return
#     cpdef void setup_rule_paths(self):
#         self.paths_rules.clear()
#         # idx acts as dummy merely counting the seperate unique paths
#         for state in self._rules.rules:
#             paths = nx.single_source_shortest_path_length(self._rules.rules,
#                                 state, cutoff = self._bounded_rational)
#             # values hold the other states
#             for state_other, distance in paths.items():
#                 #state = <state_t>(state)
#                 # state_other = <state_t>(state_other)
#                 self.paths_rules[state][distance].push_back(state_other)
#         return

#     @property
#     def bounded_rational(self):
#         return self._bounded_rational
#     @bounded_rational.setter
#     def bounded_rational(self, value):
#         assert 1 <= value <= len(self.rules)
#         self._bounded_rational = int(value)
#     @property
#     def alpha (self):
#         return self._alpha
#     @alpha.setter
#     def alpha(self, value):
#         self._alpha = value

#     cdef double _energy(self, node_id_t node) nogil:
#         """
#         """
#         cdef:
#             size_t neighbors = self.adj._adj[node].neighbors.size()
#             state_t* states = self._states # alias
#             size_t  neighbor, neighboridx
#             double weight # TODO: remove delta

#             double energy  = self._H[node] * self._states[node]

#         if self._nudges.find(node) != self._nudges.end():
#             energy += self._nudges[node] * self._states[node]


#         # compute the energy
#         cdef:
#             pair[bint, pair[state_t, double]] rule;
#             double update
#             MemoizeUnit memop

#         cdef size_t idx

#         #TODO: cleanup
#         # get the distance to consider based on current state
#         #cdef size_t distance = self.distance_converter[proposal]
#         # only get nodes based on distance it can reach based on the value network
#         # current state as proposal
#         cdef state_t proposal = self._states[node]

#         cdef:
#             state_t start
#             rule_t rule_pair
#             size_t j

#         energy = self._match_trees(node)
#         # energy = +self._match_trees(node)

#         cdef size_t mi
#         # TODO: move to separate function
#         for mi in range(self._memorySize):
#             energy += exp(mi * self._memento) * self._hamiltonian(states[node], self._memory[mi, node])
#         return energy




#     # deprecated
#     cdef double _match_trees(self, node_id_t node) nogil:
#         """"
#         Performs tree matching
#         """

#         # loop vars
#         cdef state_t* states = self._states # alias
#         cdef unordered_map[double, vector[node_id_t]] consider_nodes = self.paths[node]

#         cdef:
#             rule_t rule_pair
#             size_t idx, r

#         # path to check
#         cdef vector[node_id_t] path
#         # holds bottom-up value chain
#         cdef vector[node_id_t] nodes_to_consider
#         cdef vector[state_t] possible_states_at_distance
#         cdef double tmp, update

#         # acquire current node state
#         cdef state_t neighbor_state, state_at_distance, node_state = states[node]

#         cdef double counter = 0
#         for r in range(1, self._bounded_rational + 1):
#             nodes_to_consider = self.paths[node][r]
#             # set energy addition
#             tmp = 0
#             possible_states_at_distance = self.paths_rules[node_state][r]
#             for idx in range(nodes_to_consider.size()):
#                 neighbor = nodes_to_consider[idx]
#                 neighbor_state = states[neighbor]
#                 # check the possible states at distance x
#                 #
#                 update = -1
#                 for jdx in range(possible_states_at_distance.size()):
#                     # obtain state
#                     state_at_distance = possible_states_at_distance[jdx]
#                     if neighbor_state == state_at_distance:
#                         update = 1
#             # add weighted effect of neighbors of neighbors
#             counter += update * exp(-self._alpha * r)
#         return counter

#     cdef double  magnetize_(self, Model mod, size_t n, double t):
#         # setup simulation
#         cdef double Z = 1 / <double> self._nStates
#         mod.t         =  t
#         # calculate phase and susceptibility
#         #mod.reset()
#         mod.states[:] = mod.agentStates[0]
#         res = mod.simulate(n)
#         res = np.array([mod.check_vn(i) for i in res]).mean()
#         #res = np.array([mod.siteEnergy(i) for i in res]).mean()
#         return res
#         #return np.array([self.siteEnergy(i) for i in res]).mean()
#         #return np.abs(np.real(np.exp(2 * np.pi * np.complex(0, 1) * res)).mean())

# cdef class ValueNetworkR(Potts):
#     def __init__(self, graph,
#                  rules,
#                  t = 1,
#                  bounded_rational = 1,
#                  agentStates = np.arange(0, 2, dtype = np.double),
#                  **kwargs
#                  ):
#         super(ValueNetwork, self).__init__(graph = graph,
#                                      agentStates = agentStates,
#                                      rules = rules,
#                                      **kwargs)

#         #e = [(u, v) for u, v, d in rules.edges(data = True) if dict(d).get('weight', 1) > 0]
#         #r = nx.from_edgelist(e)
#         #
#         self.bounded_rational = bounded_rational

#     cdef vector[vector[node_id_t[2]]] _find_vc(self,
#                 vector[node_id_t] queue, vector[node_id_t[2]] path,
#                  vector[state_t[2]] vp, vector[vector[node_id_t[2]]] results) nogil:

#         # branch parameters
#         cdef:
#             node_id_t current # current node
#             state_t s # current state
#             node_id_t other # neighbor node
#             state_t ss # state of other
#             Neighbors *neighbors  # neighbors current node
#             node_id_t[2] edge
#             state_t[2] edge_state
#             bint continue_branch # step into new branch
#             rule_t rule
#         # continue with queue
#         if queue.size():
#             current = queue.back()
#             queue.pop_back()
#             s =  self._states[current]
#             neighbors = &self.adj._adj[current].neighbors

#             # continue in side branch
#             it = neighbors.begin()
#             while it != neighbors.end():
#                 other = deref(it).first
#                 ss = self._states[other]
#                 # remain order
#                 # prevents duplicates, i.e. (1, 2) == (2, 1)
#                 # for undirected graphs only(!)
#                 if s > ss:
#                     swap(s, ss)
#                 if current > other:
#                     swap(current, other)
#                 # create proposal edge
#                 edge = (current, other)
#                 edge_state = (s, ss)

#                 # check if edge exists
#                 # if path[edge] == False:
#                     # queue.push_back(other)

#                 # check for loops
#                 if path.size():
#                     # loop found
#                     if edge == path.back():
#                         # move to next neghbor
#                         continue
#                 # value network not being completed
#                 # move on to neighbor
#                 rule = self._rules._check_rules(s,ss)
#                 if rule.first:
#                     if rule.second.second <= 0:
#                         # move to next neighbor
#                         continue
#                 # if state edge not in state path
#                 # and edge not in path
#                 # continue in branch
#                 continue_branch = True
#                 for i in range(path.size()):
#                     if vp[i] == edge_state:
#                         continue_branch =  False
#                         break
#                     if path[i] == edge:
#                         continue_branch = False
#                         break

#                 if continue_branch:
#                     queue.push_back(other)
#                     # TODO: make this cleaner
#                     # move it to top of enter function?

#                     # step into branch
#                     path.push_back(edge)
#                     vp.push_back(edge_state)
#                     # result found or not
#                     self._find_vc(queue, path, vp, results)
#                     # remove option
#                     path.pop_back()
#                     vp.pop_back()
#                 post(it)


#         cdef bint add = False
#         if path.size() == self._bounded_rational:
#             # check for duplicate paths
#             if results.size():
#                 add = False
#                 for i in range(results.size()):
#                     continue
#                     # get set
#             # if results are empty push path
#             else:
#                 add = True
#         if add:
#             results.push_back(path)
#         return results



#     cdef double _check_vn(self, node_id_t node) nogil:
#         cdef vector[vector[node_id_t[2]]] results
#         cdef vector[node_id_t[2]] path
#         cdef vector[state_t[2]] vp
#         cdef vector[node_id_t] queue
#         queue.push_back(node)
#         results = self._find_vc(queue, path, vp, results)
#         return results.size()

#     def check_vn(self, node_id_t node):
#         return self._check_vn(node)
