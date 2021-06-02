##distutils: language=c++
## cython: profile = True
## cython: linetrace = True
## distutils: define_macros=CYTHON_TRACE_NOGIL=1
## cython: np_pythran=True

cimport numpy as np
import numpy as np
cdef class Ising(Potts):
    def __init__(self, graph,\
                 **kwargs):
        # default override
        kwargs['agentStates'] = np.array([0, 1], dtype = np.double)
        super(Ising, self).__init__(\
                                    graph = graph,\
                                    **kwargs)

