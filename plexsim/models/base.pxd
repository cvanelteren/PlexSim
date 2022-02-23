# distutils: language=c++
# __author__ = 'Casper van Elteren'
from plexsim.models.types cimport *
from plexsim.models.adjacency cimport Adjacency
from plexsim.models.sampler cimport RandomGenerator, MCMC
from plexsim.models.rules cimport Rules

cdef extern from "<algorithm>" namespace "std" nogil:
    void swap[T] (T &a, T &b)
# cdef public class Model [object PyModel, type PyModel_t]:
cdef class Model:
    cdef:
        # public
        PyObject* ptr
        vector[state_t] __states
        state_t* _states

        vector[state_t] __newstates
        state_t* _newstates

        bint  _last_written
        bint _use_mcmc

        vector[state_t]  _agentStates

        vector[vector[state_t]] _memory # for memory dynamics

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
        MCMC _mcmc

        dict __dict__ # allow dynamic python objects

    # Update functions
    cpdef vector[state_t] updateState(
        self, vector[node_id_t] &nodesToUpdate)

    cdef  vector[state_t]  _updateState(
        self, vector[node_id_t] &nodesToUpdate) nogil

    cdef void _set_state(self, node_id_t node, state_t state) nogil
    cdef void _reset(self, double[::1] p) nogil



    # TODO: move nudges to a separate class
    cdef void _apply_nudge(self, node_id_t node,\
                            NudgesBackup* backup) nogil

    cdef void _remove_nudge(self, node_id_t node, NudgesBackup* backup) nogil

    cdef void _swap_buffers(self) nogil
    cdef void _step(self, node_id_t node) nogil #needs to be implemented per mode

    # TODO: spatial learning
    # TODO: move spatial learning into adjacency class
    cdef void _hebbianUpdate(self)
    cdef double _learningFunction(self, node_id_t xi, node_id_t xj)

    # Sampler functions
    cdef  vector[vector[node_id_t]] _sampleNodes(
        self, size_t nSamples) nogil

    cpdef vector[vector[node_id_t]] sampleNodes(
        self, size_t nSamples)

    # Py wrapper simulation
    cpdef np.ndarray simulate(self, size_t samples)
    cdef vector[vector[state_t]] _simulate(self, size_t samples) nogil

    cpdef np.ndarray simulate_mean(self, size_t samples)


    cpdef list spawn(self, size_t n_jobs =*)

    #TODO: move this into a separate function?
    cdef SpawnVec _spawn(self, size_t nThreads=*)

    cpdef void reset(self, p =*)

    cdef vector[double] _nudgeShift(self, node_id_t node, \
                         vector[double] p) nogil

    cdef void _swap_memory(self) nogil

    cdef state_t _sample_proposal(self) nogil

    cdef double probability(self, state_t state, node_id_t node) nogil

    cpdef add_edge(self, node_id_t x, node_id_t y, double weight=*)

cpdef Model rebuild(cls, kwargs)
