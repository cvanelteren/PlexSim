include "definitions.pxi"
cdef class Ising(Model):
    cdef:
        # public
        long _magSide   # which side to sample on
        # np.ndarray _H # external magnetic field
        double[::1]  _H # external magnetic field
        double _beta
    # computes the energy
    cdef double _energy(self, \
                       long  node, \
                       ) nogil

    # Update method
    cdef void _step(self, long node) nogil
    # computes state probability; kinda not used atm
    cpdef np.ndarray[double] computeProb(self)

    # def equilibriate(self, dict settings,\
                        # np.ndarray magRatios)

    # does burnin of the model; matches the magnetizatin until it levels
    cpdef np.ndarray[double] burnin(self,\
                 int samples=*,\
                 double threshold =*)

    cpdef double hammy(self)
    # compute mag for different temps
    cpdef np.ndarray matchMagnetization(self,\
                           np.ndarray temperatures =*,\
                           int n =*,\
                           int burninSamples =*)
