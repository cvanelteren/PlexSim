#distutils: language=c++
#cython: language_level=3

cdef extern from *:
    ctypedef struct PyObject
from libcpp.vector cimport vector
from libcpp.unordered_map cimport unordered_map
from libcpp.pair cimport  pair
from cython.operator cimport dereference as deref
from libc.stdlib cimport malloc, free
cdef extern from "<algorithm>" namespace "std" nogil:
    void swap[T] (T &a, T &b)


cimport numpy as np
import numpy as np



cdef long[::1] a = np.zeros(10, dtype = int)
