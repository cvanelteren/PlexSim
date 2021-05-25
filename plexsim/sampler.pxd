#distutils: language=c++
from plexsim.types cimport *
from plexsim.models cimport *
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
