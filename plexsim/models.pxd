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
ctypedef size_t node_id_t
ctypedef double weight_t
ctypedef double nudge_t
ctypedef double state_t
ctypedef pair[bint, pair[state_t, double]] rule_t

# # TODO: move to structs?
# ctypedef vector[state_t] Neighbors
# ctypedef vector[weight_t] Weights

# nudges hash map
ctypedef unordered_map[node_id_t, state_t] Nudges

cdef struct NodeBackup:
    state_t state
    weight_t weight

# nudge temporaries
ctypedef unordered_map[node_id_t, NodeBackup] NudgesBackup

# container for parallel spawning model
ctypedef vector[PyObjectHolder] SpawnVec


ctypedef unordered_map[node_id_t, weight_t] Neighbors
cdef struct Connection:
    # unordered_map[node_id_t, weight_t] neighbors
    Neighbors neighbors
    # Weights  weights
ctypedef unordered_map[node_id_t, Connection] Connections


cdef extern from "<map>" namespace "std" nogil:
    cdef cppclass multimap[T, U]:
        cppclass iterator:
            pair[T, U]& operator*()
            iterator operator++() 
            iterator operator--()
            bint operator==(iterator)
            bint operator!=(iterator)

        multimap() except +
        U& operator[](T&)
        iterator begin()
        iterator end()
        pair[iterator, bint] insert(pair[T, U])# XXX pair[T,U]&
        iterator find(T&)
        
cdef extern from *:
    """
    struct pair_hash {
        template <class T1, class T2>
        std::size_t operator () (const std::pair<T1,T2> &p) const {
            auto h1 = std::hash<T1>{}(p.first);
            auto h2 = std::hash<T2>{}(p.second);
        return h1 ^ h2;  
        }
    };
    """
    cdef cppclass pair_hash[T, U]:
       pair[T, U]& operator()

    cdef cppclass hash_unordered_map[T, U, H]:
       hash_unordered_map() except+

# cdef extern from "<unordered_map>" using namespace "std":
#     cdef cppclass hash_map[T, U, V]:
#         ctypedef T key_type
#         ctypedef U mapped_type
#         ctypedef V hash_type


    

from libcpp.unordered_set cimport unordered_set
# ctypedef unordered_set[state_t] MemoizeUnit
ctypedef pair[state_t, state_t] MemoizeUnit
# ctypedef unordered_map[MemoizeUnit, double, pair_hash]  MemoizeMap



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



cdef class RandomGenerator:
    cdef:
        mt19937 _gen
        size_t _seed
        uniform_real_distribution[double] _dist

    cdef double _rand(self) nogil
    cpdef double rand(self)

    # Shuffle algorithm
    cdef void fisher_yates(self, node_id_t* nodes, \
                           size_t n, size_t stop) nogil

cdef class MCMC:
    # class vars
    cdef:
        double _p_recomb
        RandomGenerator rng
        dict __dict__

    # GO algorithm
    cdef void recombination(self, \
                    node_id_t[::1] nodeids,\
                    PyObject* ptr,\
                    ) nogil

    # Standard Gibbs
    cdef void gibbs(self,\
                    node_id_t[::1] nodeids,\
                    PyObject* ptr,\
                    ) nogil
   

    # Update function
    cdef void step(self, node_id_t[::1] nodeids,\
                   PyObject* ptr,\
                   ) nogil

    # Proposal state
    cdef state_t _sample_proposal(self, PyObject* ptr) nogil




cdef class Rules:
    """
Special type of overriding dynamics in a model.
Creates a layered-structure where part of the model is
    updated according to fixed rules.
    """
    cdef dict __dict__
    #properties
    cdef multimap[state_t, pair[state_t, double]] _rules

    # functions
    cdef rule_t _check_rules(self, state_t x, state_t y) nogil


cdef class Adjacency:
    """
    Converts networkx graph to unordered_map
    """
    cdef:
        Connections _adj
        node_id_t[::1]  _nodeids
        size_t _nNodes # number of nodes
        dict __dict__


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
        MCMC _mcmc

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



cdef class Logmap(Model):
    cdef double _r
    cdef double _alpha

cdef class Potts(Model):
    cdef:
        double[::1] _H
        double _beta   # temperature parameter
        double _delta # memory retention variable


    cdef void _step(self, node_id_t node) nogil

    cdef double  _energy(self, node_id_t  node) nogil
    # cdef double* _energy(self, node_id_t node, state_t x =*, state_t y=*) nogil

    cpdef np.ndarray node_energy(self, state_t[::1] states)
    cdef double magnetize_(self, Model mod, size_t n, double t)
    # update function
    cdef double _hamiltonian(self, state_t x, state_t  y) nogil

    cpdef  np.ndarray magnetize(self,\
                                np.ndarray temps  = *,\
                                size_t n             = *,\
                                size_t burninSamples = *,\
                                double  match =*)

    cpdef vector[double] siteEnergy(self, state_t[::1] states)


cdef class Prisoner(Potts):
    cdef:
        double _S, _T, _P, _R
        double _alpha

    cpdef  double probs(self, state_t state, node_id_t node)
cdef class AB(Model):
    cdef unordered_map[node_id_t, bint] _zealots
    cdef void _step(self, node_id_t node) nogil
    

cdef class Pottsis(Potts):
    cdef float _mu
    cdef float _eta
    cdef double _hamiltonian(self, state_t x, state_t y) nogil
    cdef double  _energy(self, node_id_t  node) nogil

cdef class Ising(Potts):
    cdef double _hamiltonian(self, state_t x, state_t y) nogil


cdef class Bornholdt(Potts):
     cdef:
         double _system_mag
         double* _system_mag_ptr
         double _newsystem_mag
         double* _newsystem_mag_ptr

         double _alpha

     cdef void _swap_buffers(self) nogil

     cdef void _step(self, node_id_t node) nogil
     cdef double _get_system_influence(self) nogil

cdef class SIRS(Model):
    cdef:
        float _beta
        float _mu
        float _nu
        float _kappa

    cdef void _step(self, node_id_t node) nogil

    cdef float _checkNeighbors(self,  node_id_t node) nogil

    cpdef void init_random(self, node =*)

cdef class Bonabeau(Model):
    cdef:
        float _eta
        double[::1] _weight
    cdef void _step(self, node_id_t node) nogil
    cdef double _hamiltonian(self, double x, double y) nogil

cdef class RBN(Model):
    """Random boolean network"""
    cdef:
        double _delta # memory retention variable

        unordered_map[node_id_t, vector[state_t]] _evolve_rules

    # overload the parent functions
    cdef void _step(self, node_id_t node) nogil

cdef class Percolation(Model):
    cdef:
        double _p

    cdef void _step(self, node_id_t node) nogil

cdef class CCA(Model):
    cdef:
        double _threshold

    cdef void _step(self, node_id_t node) nogil

cdef class ValueNetwork(Potts):
    # pivate props
    cdef:
       size_t _bounded_rational
       # holds nodes to consider
       unordered_map[node_id_t, unordered_map[size_t, vector[node_id_t]]] paths
       #unordered_map[node_id_t, vector[vector[node_id_t]]] paths
       #unordered_map[node_id_t, unordered_map[state_t, vector[node_id_t]]] paths
       #unordered_map[node_id_t, Connections] paths
       # holds distance to range to be mapped
       unordered_map[state_t, size_t] distance_converter

    cdef double _match_trees(self, node_id_t node) nogil
    cpdef void compute_node_path(self, node_id_t node)
    cpdef state_t[::1] check_vn(self, state_t[::1] state)
    cpdef void setup_values(self, int bounded_rational=*)
    cdef void _step(self, node_id_t node) nogil
    cdef double _energy(self, node_id_t node) nogil
    cdef double probability(self, state_t state, node_id_t node) nogil
    cdef double _hamiltonian(self, state_t x, state_t  y) nogil
   

cdef class Cycledelic(Model):
    cdef:
        double predation
        double competition
        double diffusion
    cdef state_t[:, ::1] coloring
    cdef vector[state_t] update_coloring(self, state_t[::1] colors, node_id_t node) nogil

cdef class CycledelicAgent(Model):
    cdef:
        double predation
        double mobility
        double reproduction
