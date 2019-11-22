#distutils: language = c++
cimport cython
from Models.Models cimport Model

cdef class Percolation(Model):
    cdef:
        double p

    cpdef long[::1] updateState(self, long[::1] nodesToUpdate)
    cdef long[::1] _updateState(self, long[::1] nodesToUpdate) nogil
