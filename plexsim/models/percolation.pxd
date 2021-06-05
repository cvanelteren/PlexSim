from plexsim.models.types cimport *
from plexsim.models.base cimport *

cdef class Percolation(Model):
    cdef:
        double _p
    cdef void _step(self, node_id_t node) nogil
