#distutils: language = c++
cimport cython
from Models.models cimport Model

cdef class Percolation(Model):
    cdef:
        double p

    cdef long[::1] _updateState(self, long[::1] nodesToUpdate) nogil
