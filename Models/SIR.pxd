include "definitions.pxi"


cdef class SIR(Model):
    cdef:
        float _beta
        float _mu


    cdef void _step(self, long node) nogil

    cdef float _checkNeighbors(self, long node) nogil

    cpdef void init_random(self, node =*)
