#distutils: language=c++
#distutils: sources = "plexsim/include/crawler.cpp"
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
        ColorNode() nogil except+
        ColorNode(state_t name, double state) nogil except+
        size_t name
        state_t state

    # holds edge of colored vertices
    cdef cppclass EdgeColor:
        EdgeColor() nogil except+
        EdgeColor(ColorNode current, ColorNode other) nogil except+
        ColorNode current
        ColorNode other

        EdgeColor sort() nogil
        void print() nogil

    # crawls accros and finds patterns
    cdef cppclass Crawler:
        Crawler() nogil except+
        Crawler(node_id_t start, state_t state, size_t bounded_rational) nogil except+
        Crawler(node_id_t  start, state_t state, size_t bounded_rational, bint verbose) nogil except+

        vector[EdgeColor] queue
        vector[EdgeColor] path
        # cset[cset[EdgeColor]] results
        vector[vector[EdgeColor]] results
        vector[vector[EdgeColor]] options

        bint verbose
        size_t bounded_rational

        void merge_options() nogil
        void check_options() nogil
        bint in_path(EdgeColor option) nogil
        # bint in_path(EdgeColor option, vector[EdgeColor] path) nogil

        bint in_options(EdgeColor option) nogil
        void add_result(vector[EdgeColor]) nogil
        void print() nogil
        void print(vector[EdgeColor]) nogil

cdef extern from "plexsim/include/crawler.cpp":
    pass


cdef class ValueNetwork(Potts):
    # pivate props
    cdef:
       size_t _bounded_rational

    cdef void _step(self, node_id_t node) nogil
    cdef double _energy(self, node_id_t node) nogil
    cdef double probability(self, state_t state, node_id_t node) nogil
    cdef double _hamiltonian(self, state_t x, state_t  y) nogil

    # logic for checking completed vn
    # cpdef bint check_endpoint(self, state_t s, list vp_path)
    cpdef list check_df(self, node_id_t start, bint verbose =*)

    cdef Crawler* _check_df(self, Crawler *crawler) nogil
    # merge branches
    # cpdef bint check_doubles(self, list path, list results,
                             # bint verbose =*)

    cdef bint _check_endpoint(self, state_t current_state, Crawler *crawler) nogil
