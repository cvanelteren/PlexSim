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

ctypedef fused STATEDTYPE:
    int
    long
    float
    double
ctypedef long NODE_STATE
ctypedef double WEIGHT_TYPE
ctypedef vector[NODE_STATE] Neighbors
ctypedef vector[WEIGHT_TYPE] Weights

cdef struct Connection:
    vector[NODE_STATE] neighbors
    vector[double] weights

cdef class Model:
    cdef:
        # public

        long[::1] _states
        long* _states_ptr

        long[::1] _newstates
        long* _newstates_ptr

        long[::1]  _nodeids
        long[::1]  _agentStates

        long[:, ::1] _memory # for memory dynamics

        int _memorySize # memory size

        # random sampler
        mt19937 _gen
        unsigned long _seed
        uniform_real_distribution[double] _dist

        int _zeta 
        int _nNodes # number of nodes
        str _updateType # update type
        str _nudgeType  # nudge type

        int _sampleSize # counter for how large a sample should -> random samples
        unordered_map [long, double] _nudges
        #double[::1] _nudges # array containing external inputs
        # np.ndarray _nudges


        unordered_map[long, Connection] _adj # adjacency lists
        int _nStates

        #private
        dict __dict__ # allow dynamic python objects
    cpdef void construct(self, object graph, \
                    list agentStates)

    # Update functions
    cpdef  long[::1] updateState(self, long[::1] nodesToUpdate)
    cdef long[::1]  _updateState(self, long[::1] nodesToUpdate) nogil
    cdef void _step(self, long node) nogil #needs to be implemented per mode

    # TODO: spatial learning
    cdef void _hebbianUpdate(self)
    cdef double _learningFunction(self, int xi, int xj)

    # Sampler functions
    cdef  long[:, ::1] _sampleNodes(self, int nSamples) nogil
    cpdef long[:, ::1] sampleNodes(self, int nSamples)

    # Random Number generator 
    cdef double _rand(self) nogil

    # Py wrapper simulation
    cpdef np.ndarray simulate(self, int samples)


    cpdef void reset(self)


cdef class Potts(Model):
    cdef:
        double[::1] _H
        double _beta   # temperature parameter
        double _delta # memory retention variable
    cdef vector[double] _energy(self,\
                               long node) nogil
    cdef void _step(self, long node) nogil
    # update function
    cdef double _hamiltonian(self, long x, long y) nogil

    cpdef  np.ndarray matchMagnetization(self,\
                                         np.ndarray temps  = *,\
                                         int n             = *,\
                                         int burninSamples = *,\
                                         double  match =*)
    cpdef vector[double] siteEnergy(self, long[::1] states)

cdef class Ising(Potts):
    cdef double _hamiltonian(self, long x, long y) nogil

cdef class Bornholdt(Ising):
     cdef:
         double _system_mag
         double _alpha
     cdef void _step(self, long  node) nogil

cdef class SIRS(Model):
    cdef:
        float _beta
        float _mu
        float _nu
        float _kappa

    cdef void _step(self, long node) nogil

    cdef float _checkNeighbors(self, long node) nogil

    cpdef void init_random(self, node =*)

cdef class RBN(Model):
    """Random boolean network"""
    cdef:
        double _delta # memory retention variable

        unordered_map[long, vector[int]] _rules

    # overload the parent functions
    cdef void _step(self, long node) nogil

cdef class Percolation(Model):
    cdef:
        double _p

    cdef void _step(self, long node) nogil

cdef class CCA(Model):
    cdef:
        double _threshold

    cdef void  _evolve(self, long node) nogil
    cdef void _step(self, long node) nogil
