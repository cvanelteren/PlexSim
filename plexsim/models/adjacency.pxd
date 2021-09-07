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
        bint _directed

    cdef void _add_edge(self, node_id_t x, node_id_t y, double weight =*) nogil
    cpdef add_edge(self, node_id_t x, node_id_t y, double weight =*)

    cdef void _remove_edge(self, node_id_t x, node_id_t y) nogil

