##distutils: language=c++
## cython: profile = True
## cython: linetrace = True
## distutils: define_macros=CYTHON_TRACE_NOGIL=1
## cython: np_pythran=True
import numpy as np
cimport numpy as np; np.import_array()
cdef class Ising(Potts):
    """Kinetic Ising model

    Implements kinetic Ising model on arbitrary graph.

    Parameters
    ----------
    graph : nx.Graph or nx.DiGraph
        Interaction structure for the spins.
    \ **kwargs : dict
        General settings (see Model).

    Examples
    --------
    FIXME: Add docs.
    """
    def __init__(self, graph,\
                 **kwargs):
        # default override
        kwargs['agentStates'] = np.array([-1, 1], dtype = np.double)
        super(Ising, self).__init__(\
                                    graph = graph,\
                                    **kwargs)

