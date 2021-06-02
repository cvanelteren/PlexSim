import numpy as np
cimport numpy as np
cimport cython
from cython.operator cimport dereference as deref
from cython.operator cimport preincrement as prei
from cython.operator cimport postincrement as post
cdef class SIRS(Model):
    """
        SIR model inspired by Youssef & Scolio (2011)
        The article describes an individual approach to SIR modeling which canonically uses a mean-field approximation.
        In mean-field approximations nodes are assumed to have 'homogeneous mixing', i.e. a node is able to receive information
        from the entire network. The individual approach emphasizes the importance of local connectivity motifs in
        spreading dynamics of any process.


        The dynamics are as follows

        S ----> I ----> R
          beta     mu
               The update deself.mapping.find(k) != tmp.end()pends on the state a individual is in.

        S_i: beta A_{i}.dot(states[A[i]])  beta         |  infected neighbors / total neighbors
        I_i: \mu                                        | prop of just getting cured

        TODO: no spontaneous infections possible
        (my addition)
        S ----> I ----> R ----> S
          beta     mu     kappa
                I ----> S
                   nu


        Todo: the sir model currently describes a final end-state. We can model it that we just assume distributions
    """
    def __init__(self, graph, \
                 agentStates = np.array([0, 1, 2], dtype = np.double),\
                 beta = 1,\
                 mu = 1,\
                 nu = 0,\
                 kappa = 0,\
                 **kwargs):
        super(SIRS, self).__init__(**locals())
        self.beta  = beta
        self.mu    = mu
        self.nu    = nu
        self.kappa = kappa
        self.init_random()
      

    cdef float _checkNeighbors(self, node_id_t node) nogil:
        """
        Check neighbors for infection
        """
        cdef:
            node_id_t  neighbor
            float neighborWeight
            float infectionRate = 0
            float ZZ = 1
        it = self.adj._adj[node].neighbors.begin()
        while it != self.adj._adj[node].neighbors.end():
            neighbor = deref(it).first
            neighborWeight = deref(it).second
            post(it)
            # sick
            if self._states[neighbor] == 1:
                infectionRate += neighborWeight * self._states[neighbor]
            # NOTE: abs weights?
            ZZ += neighborWeight
        return infectionRate * self._beta / ZZ

    cdef void _step(self, node_id_t node) nogil:
        cdef:
            float rng = self._rng._rand()
        # HEALTHY state 
        if self._states[node] == 0:
            # infect
            if rng  < self._checkNeighbors(node):
                self._newstates[node] = 1
        # SICK state
        elif self._states[node] == 1:
            if self._rng._rand() < .5:
                if rng < self._mu:
                    self._newstates[node] = 2
            else:
                if rng < self._nu:
                    self._newstates[node] = 0
        # SIRS motive
        elif self._states[node] == 2:
            if rng < self._kappa:
                self._newstates[node] = 0
        else:
            self._newstates[node] = self._states[node]
        # add SIRS dynamic?
        return

    cpdef void init_random(self, node = None):
       self.states = 0
       if node:
           idx = self.adj.mapping[node]
       else:
           idx = <size_t> (self._rng._rand() * self.adj._nNodes)
       self._states[idx] = 1

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
    @property
    def nu(self):
        return self._nu
    @nu.setter
    def nu(self, value):
        assert 0 <= value <= 1
        self._nu = value
    @property
    def kappa(self):
        return self._kappa
    @kappa.setter
    def kappa(self, value):
        assert 0<=value<= 1
        self._kappa = value

