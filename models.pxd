# cython: infer_types=True
# distutils: language=c++
# __author__ = 'Casper van Elteren'
cimport numpy as np
from libcpp.vector cimport vector
from libcpp.map cimport map
from libcpp.unordered_map cimport unordered_map
import cython
cdef extern from "<random>" namespace "std" nogil:
    cdef cppclass mt19937:
        mt19937() # we need to define this constructor to stack allocate classes in Cython
        mt19937(unsigned int seed) # not worrying about matching the exact int type for seed

    cdef cppclass uniform_real_distribution[T]:
        uniform_real_distribution()
        uniform_real_distribution(T a, T b)
        T operator()(mt19937 gen) # ignore the possibility of using other classes for "gen"

cdef struct Connection:
    vector[int] neighbors
    vector[double] weights

cdef class Model:
    cdef:
        # public
        # np.ndarray _states
        # np.ndarray _newstates

        # np.ndarray  _nodeids
        # np.ndarray  agentStates

        long[::1] _states
        long[::1] _newstates # alias

        long[::1]  _nodeids
        long[::1]  _agentStates

        long[:, ::1] _memory # for memory dynamics

        int _memorySize # memory size

        # random sampler
        mt19937 gen
        unsigned long _seed
        uniform_real_distribution[double] dist

        int _nNodes # number of nodes
        str _updateType # update type
        str _nudgeType  # nudge type
        double[::1] _nudges # array containing external inputs
        # np.ndarray _nudges

        
        unordered_map[long, Connection] _adj # adjacency lists
        int _nStates

        #private
        dict __dict__ # allow dynamic python objects
    cpdef void construct(self, object graph, \
                    list agentStates)

    cpdef long[::1] updateState(self, long[::1] nodesToUpdate)
    cdef long[::1]  _updateState(self, long[::1] nodesToUpdate) nogil
    # cdef long[::1]  _updateState(self, long[::1] nodesToUpdate)

    cdef  long[:, ::1] sampleNodes(self, long Samples) nogil
    # cdef  vector sampleNodes(self, long Samples) nogil
    # cdef  long[:, ::1] sampleNodes(self, long Samples)

    cdef double rand(self) nogil
    cpdef np.ndarray simulate(self, long long int  samples)

    # cpdef long[::1] updateState(self, long[::1] nodesToUpdate)


    cpdef void reset(self)
