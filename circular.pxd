#distutils: language = c++
from Models.models cimport Model


cdef class CCA(Model):
    cdef:
        double _threshold

    cdef long _evolve(self, long node) nogil
    # overload the parent functions
    # cpdef long[::1] updateState(self, long[::1] nodesToUpdate)
    # cdef long[::1] _updateState(self, long[::1] nodesToUpdate) nogil
