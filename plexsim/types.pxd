import numpy as np
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
