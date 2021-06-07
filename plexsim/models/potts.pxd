# distutils: language=c++
from plexsim.models.types cimport *
from plexsim.models.base cimport Model

cdef class Potts(Model):
    cdef:
        double[::1] _H
        double _beta   # temperature parameter
        double _delta # memory retention variable


    cdef void _step(self, node_id_t node) nogil

    cdef double  _energy(self, node_id_t  node) nogil
    # cdef double* _energy(self, node_id_t node, state_t x =*, state_t y=*) nogil

    cpdef np.ndarray node_energy(self, state_t[::1] states)
    cdef double magnetize_(self, Model mod, size_t n, double t)
    # update function
    cdef double _hamiltonian(self, state_t x, state_t  y) nogil

    cpdef np.ndarray magnetize(self, np.ndarray temps = *, size_t n = *, size_t
                               burninSamples  =  *,  size_t n_jobs  =*
                               )

    cpdef vector[double] siteEnergy(self, state_t[::1] states)

