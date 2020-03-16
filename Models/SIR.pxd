include "definitions.pxi"


cdef class SIR(Model):
    cdef:
        float _beta
        float _mu

    cpdef long[::1] updateState(self, \
                                long[::1] nodesToUpdate)
    cdef long[::1] _updateState(self, long[::1]) nogil

    cdef float _checkNeighbors(self, long node) nogil

    cpdef void init_random(self, node =*)
