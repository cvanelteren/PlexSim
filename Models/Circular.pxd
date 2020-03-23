#distutils: language = c++
from PlexSim.Models.Models cimport Model


cdef class CCA(Model):
    cdef:
        double _threshold

    cdef long _evolve(self, long node) nogil
    cdef void _step(self, long node) nogil
