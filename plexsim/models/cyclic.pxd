from plexsim.models.types cimport *
from plexsim.models.base cimport *

cdef class Cycledelic(Model):
    cdef:
        double predation
        double competition
        double diffusion
    cdef state_t[:, ::1] coloring
    cdef vector[state_t] update_coloring(self, state_t[::1] colors, node_id_t node) nogil

cdef class CycledelicAgent(Model):
    cdef:
        double predation
        double mobility
        double reproduction
