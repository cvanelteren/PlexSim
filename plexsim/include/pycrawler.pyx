from libcpp.vector cimport vector
cdef class PyCrawler:
    def __cinit__(self, size_t start, double state, size_t br):
        self._crawler = new Crawler(start, state, br)
    def __dealloc__(self):
        del self._crawler

    def __init__(self, size_t start, double state, size_t br):
        self._crawler = new Crawler(start, state, br)

    cpdef list merge_options(self, list x, list y):
        return []

        # cdef vector[vector[EdgeColor]] x1, x2


        # cdef vector[vector[EdgeColor]] res =  self._crawler.merge_options(x, y)
        # cdef EdgeColor tmp
        # cdef list out = []
        # for idx in range(res.size()):
        #     out.append([])
        #     for jdx in range(res[idx].size()):
        #         tmp = res[idx][jdx]
        #         e = (tmp.current.name, tmp.other.name)
        #         ev = (tmp.current.state, tmp.other.state)
        #         out[-1].append((e, ev))
        # return out
