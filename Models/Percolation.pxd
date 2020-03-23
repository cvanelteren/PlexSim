#distutils: language = c++
cimport cython
from PlexSim.Models.Models cimport Model

cdef class Percolation(Model):
    cdef:
        double _p

    cdef void _step(self, long node) nogil
