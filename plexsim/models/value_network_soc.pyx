from plexsim.models.value_network cimport ValueNetwork
cimport numpy as np
import numpy as np
from cython.operator cimport dereference as deref, postincrement as post


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
                 heuristic = 0,
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
                                            False)
        # search for completed vns
        self._check_df(crawler)
        return crawler.results.size()

    cdef void _step(self, node_id_t node) nogil:
        """
        Checks the number of completed value networks for @node.
        Adds edges if #vns < @heuristic
        Adds edges if #vns > @heuristic
        Does nothing if #vns = @heuristic
        """
        cdef:
            double completed_vn = self._energy(node)
            vector[node_id_t] remove_options
            node_id_t neighbor
            state_t node_state, neighbor_state
            size_t idx
            Neighbors.iterator it

        node_state = self._states[node]
        self._completed_vns[node] = completed_vn
        # add edge randomly
        if completed_vn < self._theta:
            neighbor = <node_id_t>(self._rng._rand() * self.adj._nNodes)
            # add edge with weight = 1 if not exists
            if not self.adj._adj[node].neighbors[neighbor] and node != neighbor:
                self.adj._add_edge(node, neighbor)

        # remove a negative edge
        elif completed_vn > self._theta:
            if self.adj._adj[node].neighbors.size():
                # find neighbors with negative state
                it = self.adj._adj[node].neighbors.begin()
                while it != self.adj._adj[node].neighbors.end():
                    neighbor = deref(it).first
                    neighbor_state = self._states[neighbor]
                    if self._rules._adj[node_state][neighbor_state] <= 0:
                        remove_options.push_back(neighbor)
                    post(it)

                # prefer negative weights
                if remove_options.size():
                    neighbor = <size_t>(self._rng._rand()  * remove_options.size())
                    neighbor = remove_options[neighbor]
                # otherwise its random
                else:
                    neighbor = <size_t>(self._rng._rand() * self.adj._adj[node].neighbors.size())
                    it = self.adj._adj[node].neighbors.begin()
                    idx = neighbor
                    while idx > 0:
                        idx -= 1
                        post(it)
                    neighbor = deref(it).first
                self.adj._remove_edge(node, neighbor)
        # satisfied node
        else:
            # find neighbors with negative state
            it = self.adj._adj[node].neighbors.begin()
            remove_options.clear()
            while it != self.adj._adj[node].neighbors.end():
                neighbor = deref(it).first
                neighbor_state = self._states[neighbor]
                if self._rules._adj[node_state][neighbor_state] <= 0:
                    remove_options.push_back(neighbor)
                post(it)

            # prefer negative weights
            if remove_options.size():
                neighbor = <size_t>(self._rng._rand()  * remove_options.size())
                neighbor = remove_options[neighbor]
            else:
                #FIXME: code repetition
                neighbor = <size_t>(self._rng._rand() * self.adj._adj[node].neighbors.size())
                it = self.adj._adj[node].neighbors.begin()
                idx = neighbor
                while idx > 0:
                    idx -= 1
                    post(it)
                neighbor = deref(it).first
            self.adj._remove_edge(node, neighbor)

            # # find neighbors with negative state
            # it = self.adj._adj[node].neighbors.begin()
            # while it != self.adj._adj[node].neighbors.end():
            #     neighbor = deref(it).first
            #     neighbor_state = self._states[neighbor]
            #     if self._rules._adj[node_state][neighbor_state] <= 0:
            #         remove_options.push_back(neighbor)
            #     post(it)
            # # prefer negative weights
            # if remove_options.size():
            #     neighbor = <size_t>(self._rng._rand()  * remove_options.size())
            #     self.adj._remove_edge(node, neighbor)
