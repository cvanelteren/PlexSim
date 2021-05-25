#distutils: language=c++
## cython: profile = True
## cython: linetrace = True
## distutils: define_macros=CYTHON_TRACE_NOGIL=1
## cython: np_pythran=True
from plexsim.sampler cimport RandomGenerator
cdef class MCMC:
    """
    Random number generator class
        :param \
                         RandomGenerator rng:
        :param \
                         double p_recomb:  genetic algorithm recombination probability\
                        :type: float
    """
    def __init__(self, \
                 RandomGenerator rng,\
                 double p_recomb = 1,\
                 ):

        self.rng = rng
        self.p_recomb = p_recomb

    cdef void step(self, node_id_t[::1] nodeids,\
                   PyObject* ptr,\
                   ) nogil:


        cdef double rng = self.rng._rand()
        if rng < self._p_recomb:
        # if self.rng._rand() < self._p_recomb:
            self.recombination(nodeids, \
                               ptr
                               )
        else :
            self.gibbs(nodeids, ptr)
        return

    cdef void gibbs(self, \
                    node_id_t[::1] nodeids,\
                    PyObject* ptr,\
                    ) nogil:

        cdef double p, p_prop, p_cur
        cdef state_t currentState, proposalState
        for idx in range(len(nodeids)):
            currentState  = (<Model> ptr)._states[nodeids[idx]]
            proposalState = self._sample_proposal(ptr)

            p_prop = (<Model> ptr).probability(proposalState, nodeids[idx])

            p_cur  = (<Model> ptr).probability(currentState, nodeids[idx])
            p = p_prop / p_cur
            # p = p_prop / (p_prop + p_cur)
            if self.rng._rand() < p:
                (<Model> ptr)._newstates[nodeids[idx]] = proposalState
        return

    cdef state_t _sample_proposal(self, PyObject* ptr) nogil:
        return (<Model> ptr)._agentStates[ \
                <size_t> (self.rng._rand() * (<Model> ptr)._nStates ) ]

    cdef void recombination(self,\
                    node_id_t[::1] nodeids,\
                    PyObject* ptr,\
                    ) nogil:
        """
            Return shuffled state to generate a proposal
        """
        cdef size_t n = len(nodeids)

        cdef double den, nom
        # check all pairs of proposals
        cdef size_t jdx, idx
        cdef state_t state1, state2

        cdef state_t[::1] backup   = (<Model> ptr).__states
        cdef state_t[::1] modified = (<Model> ptr).__states
        with gil:
            np.random.shuffle((<Model> ptr).__states)
        for idx in range(1, n, 2):
            # obtain random pair
            idx = nodeids[idx - 1]
            jdx = nodeids[idx]

            (<Model> ptr)._states = &modified[0]
            state1 = (<Model> ptr)._states[idx]
            state2 = (<Model> ptr)._states[jdx]

            # normal state
            den = (<Model> ptr).probability(state1, idx) *\
              (<Model> ptr).probability(state2, jdx)

            (<Model> ptr)._states = &backup[0]
            # swapped state
            nom = (<Model> ptr).probability(state2, idx) *\
              (<Model> ptr).probability(state1, jdx)

            # accept
            if self.rng._rand() < nom / den:
                (<Model> ptr)._newstates[idx] = state2
                (<Model> ptr)._newstates[jdx] = state1
            else:
                (<Model> ptr)._newstates[idx] = backup[idx]
                (<Model> ptr)._newstates[jdx] = backup[jdx]
        return



    @property
    def p_recomb(self): return self._p_recomb

    @p_recomb.setter
    def p_recomb(self, value):
        assert 0 <= value <= 1
        self._p_recomb = value
        # print(f"recomb set to {value}")
