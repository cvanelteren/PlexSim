# distutils: language=c++
from plexsim.models.types cimport *
from plexsim.models.base cimport Model
cdef class AB(Model):
    cdef unordered_map[node_id_t, bint] _zealots
    cdef void _step(self, node_id_t node) nogil
    
