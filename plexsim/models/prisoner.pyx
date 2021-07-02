import numpy as np
cimport numpy as np
from libcpp.vector cimport vector
cimport cython
from cython.parallel cimport parallel, prange, threadid
from cython.operator cimport dereference as deref, preincrement, postincrement as post
from libc.math cimport exp, cos, pi, fabs

#TODO: bug in the alpha coupler...doesnt differ from original code but doesn't
#work the same way?
cdef class Prisoner(Potts):
    """
    Prisoner dilemma model on a graph

    :param graph: Structure of the graph see Model\
    :param \
                        agentStates: 
    :param \
                        t: level of noise in the system (Gibbs distribution)
    :param \
                        T: level of temptation to defect [0, 1], defaults to 1
    :param \
                        R: level of reward to defect [0, 1], defaults to 1
    :param \
                        P: level of punishment to defect [0, 1], defaults to 0
    :param \
                        S: level of suckers' payout to defect [0, 1], defaults to 0
    :param \
                        hierarchy:  external magnetic field that would enforce hierarchy
    :param \
                        p_recomb: see model 
    :param \
                        alpha: discounting factor of how much to listen to a neighbor, default to 0
    """
    def __init__(self, graph,\
                 agentStates = np.arange(2),\
                 t = 1.0,\
                 T = 1,\
                 R = 1.,\
                 P = 0.,\
                 S = 0.,\
                 hierarchy = None,
                 p_recomb = None,
                 alpha = 0., **kwargs):
        """
        Prisoner dilemma model on a graph

        :param graph: Structure of the graph see Model\
        :param \
                            agentStates: 
        :param \
                            t: level of noise in the system (Gibbs distribution)
        :param \
                            T: level of temptation to defect [0, 1], defaults to 1
        :param \
                            R: level of reward to defect [0, 1], defaults to 1
        :param \
                            P: level of punishment to defect [0, 1], defaults to 0
        :param \
                            S: level of suckers' payout to defect [0, 1], defaults to 0
        :param \
                            hierarchy:  external magnetic field that would enforce hierarchy
        :param \
                            p_recomb: see model 
        :param \
                            alpha: discounting factor of how much to listen to a neighbor, default to 0
        """
        super(Prisoner, self).__init__(**locals(), **kwargs)

        self.T = T # temptation
        self.R = R # reward
        self.P = P # punishment
        self.S = S # suckers' payout

        self.alpha = alpha

        # overwrite magnetization
        if hierarchy:
            for idx, hi in enumerate(hierarchy):
                self.H[idx] = hi



    cdef double _energy(self, node_id_t node) nogil:

        it = self.adj._adj[node].neighbors.begin()
        cdef:
            size_t neighbors = self.adj._adj[node].neighbors.size()
            state_t* states = self._states # alias
            size_t  neighbor, neighboridx
            double weight # TODO: remove delta

            double energy  = 0


        # compute the energy
        cdef:
            pair[bint, pair[state_t, double]] rule;
            double update

        cdef size_t idx

        # current state as proposal
        cdef state_t proposal = self._states[node]
        while it != self.adj._adj[node].neighbors.end():
            weight   = deref(it).second
            neighbor = deref(it).first
            # check rules
            # update using rule
            if fabs(self._rules._adj[proposal][states[neighbor]]):
                update = self._rules._adj[proposal][states[neighbor]]
            # normal potts
            else:
                update = weight * self._hamiltonian(proposal, states[neighbor])
            energy += update
            post(it)

        cdef size_t mi
        # TODO: move to separate function
        return energy

    cdef double _hamiltonian(self, state_t x, state_t y) nogil:
        """
        Play the prisoner game
        """
        # x, y
        # 0, 1  = (D, C) -> T
        # 1, 1  = (C, C) -> R
        # 1, 0  = (C, D) -> S
        # 0, 0  = (D, D) -> P


        cdef double tmp = 0
        if x == 0. and y == 0.:
            tmp = self._P
        elif x == 1. and y == 0.:
            tmp = self._S
        elif x == 0. and y == 1.:
            tmp = self._T
        elif x == 1. and y == 1.:
            tmp = self._R
        return tmp

        #if self._rng._rand() < tmp:
            # return 1.
        # return 0.

        # return self._R * x * y + self._S * fabs(1 - y) * x + \
        #     self._T * x * fabs(1 - y)  + self._P * fabs( 1 - x ) * fabs( 1 - y )



    cdef void _step(self, node_id_t node) nogil:
        self.probability(self._states[node], node)


    cpdef double probs(self, state_t state, node_id_t node):
        return self.probability(state, node)
    cdef double probability(self, state_t state, node_id_t node) nogil:

        # get random neighbor
        cdef size_t idx = <size_t> (self._rng._rand() * self.adj._adj[node].neighbors.size())
        # get iterator and advance
        it = self.adj._adj[node].neighbors.begin()
        for c in range(idx):
            post(it)
        # assign neighbor
        cdef node_id_t neighbor = deref(it).first

        cdef double energy, energy_neighbor, delta, p
        energy          = self._energy(node)
        energy_neighbor = self._energy(neighbor)
        delta           = self._H[neighbor] - self._H[node]
        delta = -delta
        p = 1 / (1. + exp(self._beta  * (energy - energy_neighbor * (1 + self._delta * self._alpha))))

            # adopt strategy
        if self._rng._rand() < p:
            self._newstates[node] = self._states[neighbor]

        # else:
        #     idx = <size_t> (self._rng._rand() * self._nStates)
        #     self._newstates[node] = self._agentStates[idx]

        # with gil:
        #     print(energy, energy_neighbor, 1/p, self._newstates[node], self._states[node],
        #             self._states[neighbor], node, neighbor)
        return p

    def _setter(self, value, start = 0, end = 1):
        if start >= 0:
            return value


    # boiler-plate...
    @property
    def alpha(self):
        """
        Coupling coefficient property
        """
        return self._alpha

    @alpha.setter
    def alpha(self, value):
        self._alpha = self._setter(value)

    @property
    def P(self):
        """
        Punishment property (double)
        """
        return self._P

    @P.setter
    def P(self, value):
        self._P = self._setter(value)

    @property
    def R(self):
        """
        Reward property
        """
        return self._R

    @R.setter
    def R(self, value):
     
        self._R = self._setter(value)

    @property
    def S(self):
        """
        Suckers' payout property
        """
        return self._S

    @S.setter
    def S(self, value):
        self._S = self._setter(value)

    @property
    def T(self) :
        """
        Temptation property
        """
        return self._T

    @T.setter
    def T(self, value):
        self._T = self._setter(value)

