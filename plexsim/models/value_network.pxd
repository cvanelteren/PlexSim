from plexsim.models.potts cimport *
from libcpp.set cimport set as cset

cdef extern from "<algorithm>" namespace "std":
    Iter find_if[Iter, Func](Iter first, Iter last, Func pred)
    Iter find[Iter, T](Iter first, Iter last, T &value)

    Iter set_union[Iter, T](Iter first1, Iter last1,
                            Iter first2, Iter last2,
                            Iter result)

cdef extern from "plexsim/include/crawler.hpp":
    # holds vertex color and id
    cdef cppclass ColorNode:
        ColorNode() except+
        ColorNode(size_t name, double state) except+
        size_t name
        state_t state

    # holds edge of colored vertices
    cdef cppclass EdgeColor:
        EdgeColor() except+
        EdgeColor(ColorNode current, ColorNode other) except+
        ColorNode current
        ColorNode Other

    # crawls accros and finds patterns
    cdef cppclass Crawler:
        Crawler() except+
        Crawler(size_t start, size_t bounded_rational) except+
        Crawler(size_t start, size_t bounded_rational, bint verbose) except+

        vector[EdgeColor] queue
        cset[EdgeColor] path
        vector[cset[EdgeColor]] results
        vector[cset[EdgeColor]] options

        bint verbose
        size_t bounded_rational

        void merge_options()
        void add_result(cset[EdgeColor])



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

    cdef void _step(self, node_id_t node) nogil
    cdef double _energy(self, node_id_t node) nogil
    cdef double probability(self, state_t state, node_id_t node) nogil
    cdef double _hamiltonian(self, state_t x, state_t  y) nogil

    # logic for checking completed vn
    # cpdef bint check_endpoint(self, state_t s, list vp_path)
    cpdef list check_df(self, node_id_t start, bint verbose =*)

    cdef Crawler _check_df(self, Crawler crawler) nogil
    # merge branches
    cpdef bint check_doubles(self, list path, list results,
                             bint verbose =*)

    cdef bint _check_endpoint(self, state_t current_state, Crawler crawler)

    # cpdef bint _traverse(self, list proposal, list option)
    # cpdef void check_traversal(self, list proposal, list options, bint verbose =*)


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
