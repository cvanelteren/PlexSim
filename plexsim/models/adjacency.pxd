# distutils: language=c++
from plexsim.models.types cimport *
cdef class Adjacency:
    """
    Converts networkx graph to unordered_map
    """
    cdef:
        Connections _adj
        node_id_t[::1]  _nodeids
        size_t _nNodes # number of nodes
        dict __dict__

