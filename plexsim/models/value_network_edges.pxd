from plexsim.models.value_network cimport *

cdef class VNE(ValueNetwork):
    cdef:
        double[::1] _completed_vns
        double _theta
        size_t _max_bounded_rational
    # override
    cdef void _step(self, node_id_t node) nogil
    # override
    cdef double _energy(self, node_id_t node) nogil
    cdef void _remove_node(self, node_id_t node,
                           vector[vector[EdgeColor]] value_members) nogil
