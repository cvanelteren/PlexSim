# cython: infer_types=True
# distutils: language=c++
from PlexSim.Models.Models cimport Model
from libcpp.vector cimport vector

import numpy as np
cimport numpy as np

cdef class Potts(Model):
    cdef:
        double[::1] _H
        double _beta   # temperature parameter
        double _delta # memory retention variable
    cdef vector[double] _energy(self,\
                               int node) nogil
    cdef void _step(self, long node) nogil
    # update function
    cdef double _hamiltonian(self, long x, long y) nogil

    cpdef  np.ndarray matchMagnetization(self,\
                              np.ndarray temps  = *,\
                              int n             = *,\
                              int burninSamples = *)
    cpdef vector[double] siteEnergy(self, long[::1] states)
