# cython: infer_types=True
# distutils: language=c++
# __author__ = 'Casper van Elteren'

cimport numpy as np
from libcpp.vector cimport vector
from libcpp.map cimport map
from libcpp.unordered_map cimport unordered_map
import cython

# PARALLEL DEFINITION
from cpython cimport PyObject, Py_XINCREF, Py_XDECREF

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

ctypedef fused STATEDTYPE:
    int
    long
    float
    double

ctypedef long NODE
ctypedef long NODEID
ctypedef double WEIGHT
ctypedef double NUDGE
ctypedef vector[NODE] Neighbors
ctypedef vector[WEIGHT] Weights

cdef struct Connection:
    #unordered_map[NODE, WEIGHT] neighbors
    #NUDGE nudge
    vector[NODE] neighbors
    vector[WEIGHT] weights

cdef class Model:
    cdef:
        # public

        NODE[::1] _states
        NODE* _states_ptr

        NODE[::1] _newstates
        NODE* _newstates_ptr

        bint  _last_written

        NODEID[::1]  _nodeids
        NODE[::1]  _agentStates

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
        unordered_map [NODEID, NUDGE] _nudges
        #double[::1] _nudges # array containing external inputs
        # np.ndarray _nudges


        unordered_map[long, Connection] _adj # adjacency lists
        int _nStates

        #unordered_map[char, long] mapping
        #unordered_map[long, char] rmapping
        #private
        dict __dict__ # allow dynamic python objects
    cpdef void construct(self, object graph, \
                    list agentStates)

    # Update functions
    cpdef  NODE[::1] updateState(self, NODEID[::1] nodesToUpdate)
    cdef NODE[::1]  _updateState(self, NODEID[::1] nodesToUpdate) nogil

    cdef void _swap_buffers(self) nogil
    cdef void _step(self, NODEID node) nogil #needs to be implemented per mode

    # TODO: spatial learning
    cdef void _hebbianUpdate(self)
    cdef double _learningFunction(self, NODEID xi, NODEID xj)

    # Sampler functions
    cdef  NODEID[:, ::1]  _sampleNodes(self, long nSamples) nogil
    cpdef NODEID[:, ::1] sampleNodes(self, long nSamples)

    # Random Number generator 
    cdef double _rand(self) nogil

    # Py wrapper simulation
    cpdef np.ndarray simulate(self, int samples)

    cdef vector[PyObjectHolder] _spawn(self, int nThreads=*)
    cpdef void reset(self)


cdef class Potts(Model):
    cdef:
        double[::1] _H
        double _beta   # temperature parameter
        double _delta # memory retention variable
    cdef vector[double] _energy(self,\
                               NODEID  node) nogil
    cdef void _step(self, long NODEID) nogil
    # update function
    cdef double _hamiltonian(self, NODE x, NODE  y) nogil

    cpdef  np.ndarray matchMagnetization(self,\
                                         np.ndarray temps  = *,\
                                         int n             = *,\
                                         int burninSamples = *,\
                                         double  match =*)
    cpdef vector[double] siteEnergy(self, NODE[::1] states)

cdef class Ising(Potts):
    cdef double _hamiltonian(self, NODE x, NODE y) nogil

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

    cdef void _step(self, long NODEID) nogil

    cdef float _checkNeighbors(self, long NODEID) nogil

    cpdef void init_random(self, node =*)

cdef class RBN(Model):
    """Random boolean network"""
    cdef:
        double _delta # memory retention variable

        unordered_map[NODEID, vector[NODE]] _rules

    # overload the parent functions
    cdef void _step(self, NODEID node) nogil

cdef class Percolation(Model):
    cdef:
        double _p

    cdef void _step(self, NODEID node) nogil

cdef class CCA(Model):
    cdef:
        double _threshold

    cdef void  _evolve(self, NODEID node) nogil
    cdef void _step(self, NODEID node) nogil
