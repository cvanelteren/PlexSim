#distutils: language=c++
cimport cython, numpy as np
import numpy as np
from cython.operator cimport dereference as deref
from cython.operator cimport preincrement as prei
from cython.operator cimport postincrement as post
from libc.math cimport fabs, cos

cdef class Logmap(Model):
    def __init__(self,\
                 graph,\
                 double r = 1,\
                 double alpha = 0,\
                 agentStates = np.arange(2, dtype = np.double),\
                 **kwargs,\
                 ):
        """Logistic map
        :graph: test
        """
        super(Logmap, self).__init__(**locals())
        self.r = r
        self.alpha = alpha

    cdef void  _step(self, node_id_t node) nogil:
        # determine local state
        it = self.adj._adj[node].neighbors.begin()
        cdef:
            weight_t weight
            node_id_t neighbor
            long double x_n = 0

        while it != self.adj._adj[node].neighbors.end():
            neighbor = deref(it).first
            weight   = deref(it).second
            x_n      += weight *  self._states[neighbor]
            post(it)

        x_n = self._r * self._states[node] * (1 - self._states[node]) +\
            self._alpha * fabs(cos(x_n - self._states[node]) )
        self._newstates[node] = x_n
        return

    @property
    def r(self):
        return self._r
    @r.setter
    def r(self, value):
        self._r = value

    @property
    def alpha(self):
        return self._alpha
    @alpha.setter
    def alpha(self, value):
        self._alpha = value
