# distutils: language=c++
# __author__ = 'Casper van Elteren'

from plexsim.types cimport *
#distutils: language=c++
## cython: profile = True
## cython: linetrace = True
## distutils: define_macros=CYTHON_TRACE_NOGIL=1
## cython: np_pythran=True
# SEED SETUP
from plexsim.adjacency cimport Adjacency
from plexsim.sampler cimport RandomGenerator
from plexsim.mcmc cimport MCMC
from plexsim.rules cimport Rules

cdef extern from "<algorithm>" namespace "std" nogil:
    void swap[T] (T &a, T &b)


cdef public class Model [object PyModel, type PyModel_t]:
    """
    Interface for the models and serves a top of the hierarchy in the
    class structure
    """
    cdef:
        # public
        PyObject* ptr
        state_t[::1] __states
        state_t* _states

        state_t[::1] __newstates
        state_t* _newstates

        bint  _last_written
        bint _use_mcmc

        state_t[::1]  _agentStates

        state_t[:, ::1] _memory # for memory dynamics

        size_t _memorySize #memory size
        # MemoizeMap _memoize
        size_t _memento
        str _updateType # update type
        str _nudgeType  # nudge type

        size_t  _sampleSize # counter for how large a sample should -> random samples

        # define nudges
        Nudges _nudges
        double   _kNudges

        size_t _nStates

        #unordered_map[char, long] mapping
        #unordered_map[long, char] rmapping
        #private
        double _z

        # rule object
        Rules _rules
        # graph
        Adjacency adj
        RandomGenerator _rng
        # MCMC _mcmc

        dict __dict__ # allow dynamic python objects

    # Update functions
    cpdef  state_t[::1] updateState(self, node_id_t[::1] nodesToUpdate)
    cdef state_t[::1]  _updateState(self, node_id_t[::1] nodesToUpdate) nogil

    cpdef double rand(self, size_t n)


    cdef void _apply_nudge(self, node_id_t node,\
                            NudgesBackup* backup) nogil

    cdef void _remove_nudge(self, node_id_t node, NudgesBackup* backup) nogil

    cdef void _swap_buffers(self) nogil
    cdef void _step(self, node_id_t node) nogil #needs to be implemented per mode

    # TODO: spatial learning
    cdef void _hebbianUpdate(self)
    cdef double _learningFunction(self, node_id_t xi, node_id_t xj)

    # Sampler functions
    cdef  node_id_t[:, ::1]  _sampleNodes(self, size_t nSamples) nogil
    cpdef node_id_t[:, ::1] sampleNodes(self, size_t nSamples)

    # Py wrapper simulation
    cpdef np.ndarray simulate(self, size_t samples)
    cpdef np.ndarray simulate_mean(self, size_t samples)

    cdef SpawnVec _spawn(self, size_t nThreads=*)

    cpdef void reset(self, p =*)

    cdef vector[double] _nudgeShift(self, node_id_t node, \
                         vector[double] p) nogil

    cdef void _swap_memory(self) nogil

    cdef state_t _sample_proposal(self) nogil

    cdef double probability(self, state_t state, node_id_t node) nogil


