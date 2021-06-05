from plexsim.models.potts cimport Potts
from plexsim.models.types cimport *

cdef class SimpleCopy(Potts):
    # cdef node_id_t _target # target for copying
    # overwrite function
    cdef void _step(self, node_id_t node) nogil
