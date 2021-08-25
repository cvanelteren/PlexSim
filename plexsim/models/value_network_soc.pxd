from plexsim.models.value_network cimport *

cdef class VNSoc(ValueNetwork):
    cdef:
        double[::1] _completed_vns
        double _theta
        double _explore_rate
        double _w0
    # override
    cdef void _step(self, node_id_t node) nogil

    # override
    cdef double _energy(self, node_id_t node) nogil

    cdef node_id_t _local_search(self, node_id_t node) nogil

    cdef node_id_t _get_random_neighbor(self, node_id_t node, bint use_weight =*) nogil

    cpdef node_id_t local_search(self, node_id_t node)
    cpdef node_id_t get_random_neighbor(self, node_id_t node, bint use_weight =*)
