# distutils: language=c++
from plexsim.models.base cimport *

cdef class Bonabeau(Model):
    cdef:
        float _eta
        double[::1] _weight
    cdef void _step(self, node_id_t node) nogil
    cdef double _hamiltonian(self, double x, double y) nogil
