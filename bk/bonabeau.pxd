# distutils: language=c++
from plexsim.types cimport *
from plexsim.models cimport *

cdef class Bonabeau(Model):
    cdef:
        float _eta
        double[::1] _weight
    cdef void _step(self, node_id_t node) nogil
    cdef double _hamiltonian(self, double x, double y) nogil
