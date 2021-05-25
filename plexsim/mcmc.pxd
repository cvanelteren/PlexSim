from plexsim.types cimport *
from plexsim.models cimport *
from plexsim.sampler cimport RandomGenerator
cdef class MCMC:
    # class vars
    cdef:
        double _p_recomb
        RandomGenerator rng
        dict __dict__

    # GO algorithm
    cdef void recombination(self, \
                    node_id_t[::1] nodeids,\
                    PyObject* ptr,\
                    ) nogil

    # Standard Gibbs
    cdef void gibbs(self,\
                    node_id_t[::1] nodeids,\
                    PyObject* ptr,\
                    ) nogil
   

    # Update function
    cdef void step(self, node_id_t[::1] nodeids,\
                   PyObject* ptr,\
                   ) nogil

    # Proposal state
    cdef state_t _sample_proposal(self, PyObject* ptr) nogil

