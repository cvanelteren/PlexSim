from plexsim.types cimport *
from plexsim.models cimport *

cdef class Logmap(Model):
    cdef double _r
    cdef double _alpha
