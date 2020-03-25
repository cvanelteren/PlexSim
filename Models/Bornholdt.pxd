include "definitions.pxi"
from PlexSim.Models.FastIsing cimport Ising

cdef class Bernholdt(Ising):
    cdef:
        float _alpha
    cdef void _step(self, long node) nogil
