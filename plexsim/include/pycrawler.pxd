from plexsim.models.types cimport *
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

        bint verbose
        size_t bounded_rational

        void merge_options(vector[vector[EdgeColor]] &options) nogil

        void merge_options(vector[vector[EdgeColor]] &options,
                           vector[vector[EdgeColor]] &other_options) nogil
        # void check_options() nogil
        bint in_path(EdgeColor option) nogil
        bint in_path(EdgeColor option, vector[EdgeColor] path) nogil

        bint in_options(EdgeColor &option, vector[vector[EdgeColor]] &options) nogil
        bint in_options(vector[EdgeColor] &option, vector[vector[EdgeColor]] &options) nogil
        void add_result(vector[EdgeColor]) nogil
        void print(vector[vector[EdgeColor]] options) nogil
        void print(vector[EdgeColor]) nogil

cdef extern from "plexsim/include/crawler.cpp":
    pass

cdef class PyCrawler:
    cdef:
        Crawler * _crawler
    cpdef list merge_options(self, list, list)
