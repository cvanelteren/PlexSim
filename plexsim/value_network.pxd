from plexsim.types cimport *
from plexsim.models cimport *
from plexsim.potts cimport *

cdef class ValueNetwork(Potts):
    # pivate props
    cdef:
       size_t _bounded_rational
       # holds nodes to consider
       unordered_map[node_id_t, unordered_map[size_t, vector[node_id_t]]] paths
       #unordered_map[node_id_t, vector[vector[node_id_t]]] paths
       #unordered_map[node_id_t, unordered_map[state_t, vector[node_id_t]]] paths
       #unordered_map[node_id_t, Connections] paths
       # holds distance to range to be mapped
       unordered_map[state_t, size_t] distance_converter

    cpdef void setup_values(self, int bounded_rational=*)
    cpdef void compute_node_path(self, node_id_t node)
    cpdef state_t[::1] check_vn(self, state_t[::1] state)

    cdef double _match_trees(self, node_id_t node) nogil
    cdef void _step(self, node_id_t node) nogil
    cdef double _energy(self, node_id_t node) nogil
    cdef double probability(self, state_t state, node_id_t node) nogil
    cdef double _hamiltonian(self, state_t x, state_t  y) nogil

    # logic for checking completed vn
    cpdef bint check_endpoint(self, state_t s, list vp_path)
    cpdef list check_df(self, list queue, list path = *,
                        list vp_path = *,
                        list results = *, 
                        bint verbose = *)
    # merge branches
    cpdef void merge(self, list results)
    cpdef void check_doubles(self, list path, list results)

# cdef class ValueNetworkNP(Potts):
#     # hold states at some distance in the rule graph
#     cdef:
#         unordered_map[state_t, unordered_map[size_t, vector[state_t]]] paths_rules
#         unordered_map[node_id_t, unordered_map[double, vector[node_id_t]]] paths
#         double _alpha
#         size_t _bounded_rational

#     cpdef void setup_values(self, int bounded_rational=*)
#     cpdef void compute_node_path(self, node_id_t node)
#     cpdef void setup_rule_paths(self)

#     cdef double _match_trees(self, node_id_t node) nogil
#     cdef void _step(self, node_id_t node) nogil
#     cdef double _energy(self, node_id_t node) nogil
#     cdef double probability(self, state_t state, node_id_t node) nogil
#     cdef double _hamiltonian(self, state_t x, state_t  y) nogil
