# cython: infer_types=True
# distutils: language=c++
from Models.models cimport Model
from libcpp.vector cimport vector

import numpy as np
cimport numpy as np

cdef class Potts(Model):
    cdef:
        double[::1] _H
        double _beta   # temperature parameter
        double _delta # memory retention variable
    cdef vector[double] energy(self,\
                                                int node,\
                                                long[::1] states) nogil
    # overload the parent functions
    cpdef long[::1] updateState(self, long[::1] nodesToUpdate)
    # cdef long[::1] _updateState(self, long[::1] nodesToUpdate)
    cdef long[::1] _updateState(self, long[::1] nodesToUpdate) nogil



    cpdef  np.ndarray matchMagnetization(self,\
                              np.ndarray temps  = *,\
                              int n             = *,\
                              int burninSamples = *)
    cpdef vector[double] siteEnergy(self, long[::1] states)
