from plexsim.models.base cimport Model
from plexsim.models.types cimport *
from cython.operator cimport dereference as deref, postincrement as post
from libcpp.vector cimport vector
cdef class Sandpile(Model):
    cdef:
        size_t _threshold
    cdef void _step(self, node_id_t node) nogil
    cdef size_t _check_avalanche(self, vector[node_id_t] queue, size_t counter) nogil
