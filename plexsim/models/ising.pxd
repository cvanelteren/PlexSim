from plexsim.models.potts cimport *

cdef class Ising(Potts):
    cdef double _hamiltonian(self, state_t x, state_t y) nogil
