cimport cython
from cython.operator cimport dereference as deref, preincrement, postincrement as post
cdef class Pottsis(Potts):
    """Novel implementation of SIS model using energy functions\
        :param \
                         graph: 
        :param \
                         beta: 
        :param \
                         eta: 
        :param \
                         mu: 
        :param \
                         **kwargs: 
        :returns: 

    """
    def __init__(self, \
                 graph, \
                 beta = 1, \
                 eta  = .2, \
                 mu   = .1, \
                 **kwargs):

        
        super(Pottsis, self).__init__(graph = graph,\
                                      **kwargs)
        self.mu = mu
        self.eta = eta
        self.beta = beta

  
    cdef double _energy(self, node_id_t node) nogil:
        """
        """
        cdef:
            size_t neighbors = self.adj._adj[node].neighbors.size()
            state_t* states = self._states # alias
            size_t  neighbor, neighboridx
            double weight # TODO: remove delta

            double energy = self._H[node]

        # compute the energy
        cdef:
            pair[bint, pair[state_t, double]] rule;
            double update
            MemoizeUnit memop

        it = self.adj._adj[node].neighbors.begin()
        cdef size_t idx
        cdef state_t proposal = self._sample_proposal()
        cdef state_t state    = states[node]
        while it != self.adj._adj[node].neighbors.end():
            weight   = deref(it).second
            neighbor = deref(it).first
            # check rules
            rule = self._rules._check_rules(proposal, states[neighbor])
            # update using rule
            if rule.first:
                update = rule.second.first
            # normal potts
            else:
                #update = weight * self._hamiltonian(proposal, states[neighbor])
                update = states[neighbor]
            energy += update

            post(it)
        # prob of staying the same
        cdef double fx = (1 - self._eta)**energy

        energy = \
            (state - 1) * ((proposal * 2 - 1) * fx - proposal) + \
            proposal * (- 2 * proposal * self._mu + proposal + self._mu)

        if energy:
            energy = log(energy)
        else:
            energy = -INFINITY
        cdef size_t mi

        # # TODO: move to separate function
        # for mi in range(self._memorySize):
        #     energy[0] -= exp(- mi * self._memento) * self._hamiltonian(states[node], self._memory[mi, node])
        #     energy[1] -= exp(-mi * self._memento ) * self._hamiltonian(self._agentStates[testState], self._memory[mi, node])

        return energy
    
    # this is currently not correct,
    # x, y here need to be the future and current state
    # This model is different from the traditional potts
    # The state being considered is not 1, 1 but in this case 2,2
    # Need a way to solve this problem
    # cdef double _hamiltonian(self, state_t x, state_t y, double sum) nogil
    cdef double _hamiltonian(self, state_t x, state_t y) nogil:
        return y

    @property
    def eta(self):
        return self._eta
    @eta.setter
    def eta(self,value):
        self._eta = value

    @property
    def mu(self):
        return self._mu
    @mu.setter
    def mu(self,value):
        self._mu = value

    @property
    def beta(self): return self._beta

    @beta.setter
    def beta(self, value):
        self._beta = value

