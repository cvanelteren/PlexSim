#distutils: language=c++
cimport cython
from plexsim.models.base cimport *

cdef class RBN(Model):
    """Random boolean network"""
    cdef:
        double _delta # memory retention variable

        unordered_map[node_id_t, vector[state_t]] _evolve_rules

    # overload the parent functions
    cdef void _step(self, node_id_t node) nogil
