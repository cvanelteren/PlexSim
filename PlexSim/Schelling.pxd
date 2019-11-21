from Models.Models cimport Model
cimport cython
from libcpp.vector cimport vector

cdef class Schelling(Model):
    cdef:
        double _threshold # agreeablenss
        double _radius     # what range to consider

        # states
        double [:, ::1] _coordinates

        # directions
        vector[double] _directions


    cpdef double[:, ::1] updateState(self, long[::1] nodesToUpdate)

    cdef double[:, ::1] _updateState(self, long[::1] nodesToUpdate) nogil

    cdef double[::1] _move(self, int node, int[::1] neighbors)
    cdef long[::1] _getNeighbors(self, int node)
    cdef double _dinstance(self, long x, long y)
