from plexsim.types cimport *
from plexsim.models cimport *
from plexsim.potts cimport *

cdef class Ising(Potts):
    cdef double _hamiltonian(self, state_t x, state_t y) nogil
