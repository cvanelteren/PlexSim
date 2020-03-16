include "definitions.pxi"


from libc.math cimport abs as c_abs
cdef class SIR(Model):
    def __init__(self, graph, updateType = 'async',\
                 agentStates = [0, 1, 2],\
                 beta = 1, mu = 1):
        super(SIR, self).__init__(**locals())
        self.beta = beta
        self.mu   = mu
        self.init_random()

        """
        SIR model inspired by Youssef & Scolio (2011)
        The article describes an individual approach to SIR modelling which canonically uses a mean-field approximation.
        In mean-field approximatinos nodes are assumed to have 'homogeneous mixing', i.e. a node is able to receive information
        from the entire network. The individual approach emphasizes the importance of local connectivity motifs in
        spreading dynamics of any process.


        The dynamics are as follows

        S ----> I ----> R
          beta     mu

        The update depends on the state a individual is in.

        S_i: beta A_{i}.dot(states[A[i]])  beta         |  infected neighbors / total neighbors
        I_i: \mu                                        | prop of just getting cured

        Todo: the sir model currently describes a final end-state. We can model it that we just assume distributions
        """
    @property
    def beta(self):
        return self._beta

    @beta.setter
    def beta(self, value):
        assert 0 <= value <= 1, "beta \in (0,1)?"
        self._beta = value

    @property
    def mu(self):
        return self._mu
    @mu.setter
    def mu(self, value):
        assert 0 <= value <= 1, "mu \in (0,1)?"
        self._mu = value

    cdef float _checkNeighbors(self, long node) nogil:
        """
        Check neighbors for infection
        """
        cdef:
            long neighbor, idx
            float neighborWeight
            float infectionRate = 0
            long Z = self._adj[node].neighbors.size()
            float ZZ = 0
        for idx in range(Z):
            neighbor = self._adj[node].neighbors[idx]
            neighborWeight = self._adj[node].weights[idx]
            # sick
            if self._states[neighbor] == 1:
                infectionRate += neighborWeight * self._states[neighbor]
            # NOTE: abs weights?
            ZZ += neighborWeight
            #ZZ += c_abs(neighborWeight)
        return infectionRate * self._beta / ZZ


    cdef long[::1] _updateState(self, long[::1] nodesToUpdate) nogil:
        cdef:
            int node
            long nodeState
            float infectionRate
        # simulate disease spread
        for node in range(nodesToUpdate.shape[0]):
            node = nodesToUpdate[node]
            if self._states[node] == 0:
                infectionRate = self._checkNeighbors(node)
                # sample and update
                if self.rand() < infectionRate:
                    self._states[node] = 1
            # heal
            elif self._states[node] == 1:
                if self.rand() < self._mu:
                    self._states[node] = 2
            # recovered has no case
        return self._states

    cpdef void init_random(self, node = None):
       self.states = 0 
       if node:
           idx = self.mapping[node]
       else:
           idx = <long> (self.rand() * self._nNodes)
       self._states[idx] = 1
