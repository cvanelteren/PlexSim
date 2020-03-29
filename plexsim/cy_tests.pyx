#distutils: language = c++
#cython: language_level=3

cimport numpy as np
import numpy as np
from libcpp.vector cimport vector
cdef extern from "<algorithm>" namespace "std" nogil:
    void swap[T] (T &a, T &b)
cdef:
    long[::1] a1 = np.zeros(10, dtype = long, order = 'C')
    long* p1 = &a1[0] 

    long[::1] a2 = np.zeros(10, dtype = long, order = 'C') 
    long* p2 = &a2[0]


from cython.operator cimport dereference as deref

from cython cimport numeric, floating
cimport cython
cdef fused t_t:
    float
    double
cdef struct D:
   void* var
cdef vector[D] test = vector[D](10)
cdef D j
cdef double h
cdef double *ptr

