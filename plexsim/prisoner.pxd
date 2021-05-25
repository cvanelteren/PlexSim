from plexsim.types cimport *
from plexsim.models cimport *
from plexsim.potts cimport *

cdef class Prisoner(Potts):
    cdef:
        double _S, _T, _P, _R
        double _alpha
    cpdef  double probs(self, state_t state, node_id_t node)
