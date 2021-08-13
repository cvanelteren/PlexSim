from plexsim.models.value_network cimport *

cdef class VNSoc(ValueNetwork):
    cdef:
        double[::1] _completed_vns
        double _theta
    # override
    cdef void _step(self, node_id_t node) nogil
    # override
    cdef double _energy(self, node_id_t node) nogil
