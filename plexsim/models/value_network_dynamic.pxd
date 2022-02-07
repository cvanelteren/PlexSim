from plexsim.models.value_network cimport *

cdef class ValueDynamic(ValueNetwork):
    # override
    cdef void _step(self, node_id_t node) nogil
