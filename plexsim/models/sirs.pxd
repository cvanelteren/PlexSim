from plexsim.models.base cimport *
cdef class SIRS(Model):
    cdef:
        float _beta
        float _mu
        float _nu
        float _kappa

    cdef void _step(self, node_id_t node) nogil

    cdef float _checkNeighbors(self,  node_id_t node) nogil

    cpdef void init_random(self, node =*)

