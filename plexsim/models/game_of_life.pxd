from plexsim.models.types cimport *
from plexsim.models.base cimport *

cdef class Conway(Model):
    cdef size_t _threshold
