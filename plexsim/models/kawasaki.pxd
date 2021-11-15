from plexsim.models.potts cimport *

cdef class Kawasaki(Potts):
    cdef void _step(self, node_id_t node) nogil
