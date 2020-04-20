# cython: infer_types=True
# distutils: language=c++
# __author__ = 'Casper van Elteren'

cimport numpy as np
from libcpp.vector cimport vector
from libcpp.pair cimport pair
from libcpp.map cimport map
from libcpp.unordered_map cimport unordered_map
import cython

# PARALLEL DEFINITION
from cpython cimport PyObject, Py_XINCREF, Py_XDECREF

# TYPE DEFINITIONS
ctypedef long node_state_t
ctypedef long node_id_t
ctypedef double weight_t
ctypedef double nudge_t

# TODO: move to structs?
ctypedef vector[node_state_t] Neighbors
ctypedef vector[weight_t] Weights

# nudges hash map
ctypedef unordered_map[node_id_t, nudge_t] Nudges

cdef struct NodeBackup:
    node_state_t state
    weight_t weight

# nudge temporaries
ctypedef unordered_map[node_id_t, NodeBackup] NudgesBackup

# container for parallel spawning model
ctypedef vector[PyObjectHolder] SpawnVec


cdef struct Connection:
    unordered_map[node_id_t, weight_t] neighbors
    # Neighbors neighbors
    # Weights  weights

ctypedef unordered_map[node_id_t, Connection] Connections


cdef extern from *:
    """
    #include <Python.h>
    #include <mutex>

    std::mutex ref_mutex;

    class PyObjectHolder{
    public:
        PyObject *ptr;
        PyObjectHolder():ptr(nullptr){}
        PyObjectHolder(PyObject *o):ptr(o){
            std::lock_guard<std::mutex> guard(ref_mutex);
            Py_XINCREF(ptr);
        }
        //rule of 3
        ~PyObjectHolder(){
            std::lock_guard<std::mutex> guard(ref_mutex);
            Py_XDECREF(ptr);
        }
        PyObjectHolder(const PyObjectHolder &h):
            PyObjectHolder(h.ptr){}
        PyObjectHolder& operator=(const PyObjectHolder &other){
            {
                std::lock_guard<std::mutex> guard(ref_mutex);
                Py_XDECREF(ptr);
                ptr=other.ptr;
                Py_XINCREF(ptr);
            }
            return *this;

        }
    };
    """
    cdef cppclass PyObjectHolder:
        PyObject *ptr
        PyObjectHolder(PyObject *o) nogil


cdef extern from "<random>" namespace "std" nogil:
    cdef cppclass mt19937:
        mt19937() # we need to define this constructor to stack allocate classes in Cython
        mt19937(unsigned int seed) # not worrying about matching the exact int type for seed

    cdef cppclass uniform_real_distribution[T]:
        uniform_real_distribution()
        uniform_real_distribution(T a, T b)
        T operator()(mt19937 gen) # ignore the possibility of using other classes for "gen"


cdef class Model:
    cdef:
        # public

        node_state_t[::1] _states
        node_state_t* _states_ptr

        node_state_t[::1] _newstates
        node_state_t* _newstates_ptr

        bint  _last_written

        node_id_t[::1]  _nodeids
        node_state_t[::1]  _agentStates

        node_state_t[:, ::1] _memory # for memory dynamics

        int _memorySize #memory size

        # random sampler
        mt19937 _gen
        unsigned long _seed
        uniform_real_distribution[double] _dist

        int _zeta
        int _nNodes # number of nodes
        str _updateType # update type
        str _nudgeType  # nudge type

        int _sampleSize # counter for how large a sample should -> random samples

        # define nudges
        Nudges _nudges
        double   _kNudges

        Connections _adj # adjacency lists
        int _nStates

        #unordered_map[char, long] mapping
        #unordered_map[long, char] rmapping
        #private
        dict __dict__ # allow dynamic python objects
    cpdef void construct(self, object graph, \
                    list agentStates)

    # Update functions
    cpdef  node_state_t[::1] updateState(self, node_id_t[::1] nodesToUpdate)
    cdef node_state_t[::1]  _updateState(self, node_id_t[::1] nodesToUpdate) nogil

    cdef void _apply_nudge(self, node_state_t node,\
                            NudgesBackup* backup) nogil

    cdef void _remove_nudge(self, node_id_t node, NudgesBackup* backup) nogil

    cdef void _swap_buffers(self) nogil
    cdef void _step(self, node_id_t node) nogil #needs to be implemented per mode

    # TODO: spatial learning
    cdef void _hebbianUpdate(self)
    cdef double _learningFunction(self, node_id_t xi, node_id_t xj)

    # Sampler functions
    cdef  node_id_t[:, ::1]  _sampleNodes(self, long nSamples) nogil
    cpdef node_id_t[:, ::1] sampleNodes(self, long nSamples)

    # Random Number generator 
    cdef double _rand(self) nogil

    # Py wrapper simulation
    cpdef np.ndarray simulate(self, int samples)

    cdef SpawnVec _spawn(self, int nThreads=*)

    cpdef void reset(self, p =*)


cdef class Potts(Model):
    cdef:
        double[::1] _H
        double _beta   # temperature parameter
        double _delta # memory retention variable

    # cdef vector[double] _energy(self,\
                               # node_id_t  node) nogil
    
    cdef double*  _energy(self,node_id_t  node) nogil
    cdef void _step(self, long node_id_t) nogil
    cdef void _step(self, long node_id_t) nogil
    # update function
    cdef double _hamiltonian(self, node_state_t x, node_state_t  y) nogil

    cpdef  np.ndarray magnetize(self,\
                                np.ndarray temps  = *,\
                                int n             = *,\
                                int burninSamples = *,\
                                double  match =*)

    cpdef vector[double] siteEnergy(self, node_state_t[::1] states)

cdef class Ising(Potts):
    cdef double _hamiltonian(self, node_state_t x, node_state_t y) nogil

cdef class Bornholdt(Ising):
     cdef:
         double _system_mag
         double* _system_mag_ptr
         double _newsystem_mag
         double* _newsystem_mag_ptr

         double _alpha
     cdef void _step(self, long  node) nogil

     cdef void _swap_buffers(self) nogil

cdef class SIRS(Model):
    cdef:
        float _beta
        float _mu
        float _nu
        float _kappa

    cdef void _step(self, long node_id_t) nogil

    cdef float _checkNeighbors(self, long node_id_t) nogil

    cpdef void init_random(self, node =*)

cdef class RBN(Model):
    """Random boolean network"""
    cdef:
        double _delta # memory retention variable

        unordered_map[node_id_t, vector[node_state_t]] _rules

    # overload the parent functions
    cdef void _step(self, node_id_t node) nogil

cdef class Percolation(Model):
    cdef:
        double _p

    cdef void _step(self, node_id_t node) nogil

cdef class CCA(Model):
    cdef:
        double _threshold

    cdef void  _evolve(self, node_id_t node) nogil
    cdef void _step(self, node_id_t node) nogil
