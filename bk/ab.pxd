# distutils: language=c++
from plexsim.types cimport *
from plexsim.models cimport *

cdef class AB(Model):
    cdef unordered_map[node_id_t, bint] _zealots
    cdef void _step(self, node_id_t node) nogil
    
