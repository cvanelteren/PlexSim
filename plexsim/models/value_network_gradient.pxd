from plexsim.models.value_network cimport *
cimport numpy as np
import numpy as np
from libcpp.unordered_map cimport *
from libcpp.set cimport *
# from libcpp.iterator cimport *


cdef extern from "<iterator>" namespace "std" nogil:
    Container& inserter[Container, Iterator](Container &c, Iterator i)

cdef extern from "<set>" namespace "std" nogil:
    cppclass iterator[T]:
        T& operator*()
        iterator operator++()
        iterator operator--()
        bint operator==(iterator)
        bint operator!=(iterator)

    # templated
    OutputIter set_intersection[Iter1, Iter2, OutputIter](Iter1 first1, Iter1 last1,
                          Iter2 first2, Iter2 last2,
                          OutputIter result)



cdef class VNG(ValueNetwork):
   cdef double[::1] _completed_vns
   cdef void _check_sufficient_connected(self, node_id_t node, vector[node_id_t] &suff_connected) nogil

   cdef unordered_map[node_id_t, double] _check_gradient(self, bint verbose =*)
   cpdef dict check_gradient(self, bint verbose =*)

   cdef void _step(self, node_id_t node) nogil # override
