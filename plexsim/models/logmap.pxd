from plexsim.models.types cimport *
from plexsim.models.base cimport *

cdef class Logmap(Model):
    cdef double _r
    cdef double _alpha
