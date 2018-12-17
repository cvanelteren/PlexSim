# from Models.models cimport Model
from Models.models cimport Model
from libcpp.vector cimport vector
from libcpp.map cimport map
from libcpp.unordered_map cimport unordered_map
cimport numpy as np

cdef struct Connection:
    vector[int] neighbors
    vector[double] weights

cdef class Ising(Model):
    cdef:
        # public
        long _magSide   # which side to sample on
        # np.ndarray _H # external magnetic field
        double[::1]  _H # external magnetic field
        double beta

    # computes the energy
    cdef double energy(self, \
                       int  node, \
                       long[::1] states) nogil
    # cdef double energy(self, \
    #                    int  node, \
    #                    long[::1] states)


    # overload the parent functions
    cpdef long[::1] updateState(self, long[::1] nodesToUpdate)
    # cdef long[::1] _updateState(self, long[::1] nodesToUpdate)
    cdef long[::1] _updateState(self, long[::1] nodesToUpdate) nogil
    # # python wrapper

    # computes state probability; kinda not used atm
    cpdef np.ndarray[double] computeProb(self)

    # does burnin of the model; matches the magnetizatin until it levels
    cpdef np.ndarray[double] burnin(self,\
                 int samples=*,\
                 double threshold =*)

    # compute mag for different temps
    cpdef np.ndarray matchMagnetization(self,\
                           np.ndarray temps =*,\
                           int n =*,\
                           int burninSamples =*)
