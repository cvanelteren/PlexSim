from plexsim.models.potts cimport *
cdef class Pottsis(Potts):
    cdef float _mu
    cdef float _eta
    cdef double _hamiltonian(self, state_t x, state_t y) nogil
    cdef double  _energy(self, node_id_t  node) nogil
