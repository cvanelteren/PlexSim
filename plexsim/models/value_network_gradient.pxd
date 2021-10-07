from plexsim.models.value_network cimport *
cimport numpy as np
import numpy as np
from libcpp.unordered_map cimport *
# from libcpp.iterator cimport *
from libcpp.set cimport set as cset

cdef extern from "<set>" namespace "std" nogil:
    # templated
    OutputIter set_intersection[Iter1, Iter2, OutputIter](Iter1 first1, Iter1 last1,
                          Iter2 first2, Iter2 last2,
                          OutputIter result)

cdef extern from "<iterator>" namespace "std" nogil:
    cdef cppclass insert_iterator[T]:
        cppclass iterator[T]:
            pass
        insert_iterator(T & c, iterator[T] i)

cdef class VNG(ValueNetwork):
   cdef double[::1] _completed_vns
   cdef void _check_sufficient_connected(self, node_id_t node,
                                         cset[node_id_t] &suff_connected) nogil

   cdef unordered_map[node_id_t, double] _check_gradient(self, bint verbose =*)

   cpdef dict check_gradient(self, bint verbose =*)

   cpdef object cut_components(self, cset[node_id_t] suff_connected)

   cdef void _step(self, node_id_t node) nogil # override

   cpdef double fractional_count(self, cset[node_id_t] nodes, size_t threshold, bint verbose =*)

   cpdef double check_gradient_node(self, node_id_t node)
