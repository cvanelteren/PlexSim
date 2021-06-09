#distutils: language=c++
from plexsim.models.types cimport *
from cpython cimport PyObject
from plexsim.models.base cimport Model

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
        RandomGenerator _rng
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
