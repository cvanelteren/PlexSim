#distutils: language=c++
from posix.time cimport clock_gettime, timespec, CLOCK_REALTIME
import numpy as np
cimport numpy as np; np.import_array()
from plexsim.models.types cimport *
from cython.operator cimport dereference as deref

from libcpp.algorithm cimport swap
cdef class RandomGenerator:

    def __init__(self,\
                 object seed,\
                 ):
        """Init mersenne twister with some seed"""


        cdef timespec ts
        if seed is None:
            clock_gettime(CLOCK_REALTIME, &ts)
            _seed = ts.tv_sec
        elif seed >= 0 and isinstance(seed, int):
            _seed = seed
        else:
            raise  ValueError("seed needs uint")

        # define rng sampler
        self._dist = uniform_real_distribution[double](0.0, 1.0)
        self.seed = _seed
        self._gen  = mt19937(self.seed)

    cpdef double rand(self):
        return self._rand()

    cdef double _rand(self) nogil:
        """ Draws uniformly from 0, 1"""
        return self._dist(self._gen)

    @property
    def seed(self): return self._seed
    @seed.setter
    def seed(self, value):
        if isinstance(value, int) and value >= 0:
            self._seed = value
            self._gen   = mt19937(self.seed)
        else:
            raise ValueError("Not an uint found")

    cdef void fisher_yates(self, \
                           node_id_t* nodes,\
                           size_t n, \
                           size_t stop) nogil:
        cdef size_t idx, jdx
        for idx in range(n - 1):
            jdx = <size_t> (self._rand() * (n - idx))
            swap(nodes[idx], nodes[jdx])
            if stop == 1:
                break
        return
    def __eq__(self, other):
        if other.seed == self.seed:
            return True
        return False

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

        self._rng = rng
        self.p_recomb = p_recomb

    @property
    def rng(self):
        return self._rng


    cdef void step(self, vector[node_id_t] &nodeids,\
                   PyObject* ptr,\
                   ) nogil:


        cdef double rng = self._rng._rand()
        if rng < self._p_recomb:
        # if self.rng._rand() < self._p_recomb:
            self.recombination(nodeids, \
                               ptr
                               )
        else :
            self.gibbs(nodeids, ptr)
        return

    cdef void gibbs(self, \
                    vector[node_id_t] &nodeids,\
                    PyObject* ptr,\
                    ) nogil:

        cdef double p, p_prop, p_cur
        cdef state_t currentState, proposalState
        for idx in range(nodeids.size()):
            currentState  = deref((<Model> ptr)._states)[nodeids[idx]]
            proposalState = self._sample_proposal(ptr)

            p_prop = (<Model> ptr).probability(proposalState, nodeids[idx])

            p_cur  = (<Model> ptr).probability(currentState, nodeids[idx])
            p = p_prop / p_cur
            # p = p_prop / (p_prop + p_cur)
            if self._rng._rand() < p:
                deref((<Model> ptr)._newstates)[nodeids[idx]] = proposalState
        return

    cdef state_t _sample_proposal(self, PyObject* ptr) nogil:
        return (<Model> ptr)._agentStates[ \
                <size_t> (self._rng._rand() * (<Model> ptr)._nStates ) ]

    cdef void recombination(self,\
                    vector[node_id_t] &nodeids,\
                    PyObject* ptr,\
                    ) nogil:
        """
            Return shuffled state to generate a proposal
        """
        cdef size_t n = nodeids.size()

        cdef double den, nom
        # check all pairs of proposals
        cdef size_t jdx, idx
        cdef state_t state1, state2

        cdef vector[state_t] backup   = (<Model> ptr).__states
        cdef vector[state_t] modified = (<Model> ptr).__states
        with gil:
            np.random.shuffle((<Model> ptr).__states)
        for idx in range(1, n, 2):
            # obtain random pair
            idx = nodeids[idx - 1]
            jdx = nodeids[idx]

            (<Model> ptr)._states = &modified
            state1 = deref((<Model> ptr)._states)[idx]
            state2 = deref((<Model> ptr)._states)[jdx]

            # normal state
            den = (<Model> ptr).probability(state1, idx) *\
              (<Model> ptr).probability(state2, jdx)

            (<Model> ptr)._states = &backup
            # swapped state
            nom = (<Model> ptr).probability(state2, idx) *\
              (<Model> ptr).probability(state1, jdx)

            # accept
            if self._rng._rand() < nom / den:
                deref((<Model> ptr)._newstates)[idx] = state2
                deref((<Model> ptr)._newstates)[jdx] = state1
            else:
                deref((<Model> ptr)._newstates)[idx] = backup[idx]
                deref((<Model> ptr)._newstates)[jdx] = backup[jdx]
        return



    @property
    def p_recomb(self): return self._p_recomb

    @p_recomb.setter
    def p_recomb(self, value):
        assert 0 <= value <= 1
        self._p_recomb = value
        # print(f"recomb set to {value}")

    def __eq__(self, other):
        if self.rng != other.rng:
            return False
        if self.p_recomb != other.p_recomb:
            return False
        return True
