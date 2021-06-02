from plexsim.models.types cimport *
from plexsim.models.base cimport *

cdef class CCA(Model):
    cdef:
        double _threshold

    cdef void _step(self, node_id_t node) nogil
