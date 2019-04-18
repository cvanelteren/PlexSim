from Models.models cimport Model
from libcpp.vector import vector
cimport numpy as np

cdef class Potts(Model):
    cdef:
        double[::1] _H
        double _beta

    cdef double[::1] energy(self,\
                                                int node,\
                                                long[::1] states) nogil
    # overload the parent functions
    cpdef long[::1] updateState(self, long[::1] nodesToUpdate)
    # cdef long[::1] _updateState(self, long[::1] nodesToUpdate)
    cdef long[::1] _updateState(self, long[::1] nodesToUpdate) nogil
