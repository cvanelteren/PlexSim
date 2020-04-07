#distutils: language=c++
#cython: language_level=3

cdef extern from *:
    ctypedef struct PyObject
import numpy as np
cimport numpy as np
from libcpp.vector cimport vector
from libcpp.pair cimport  pair
from cython.operator cimport dereference as deref
cdef extern from "<algorithm>" namespace "std" nogil:
    void swap[T] (T &a, T &b)


cdef struct Test:
    pair[long, double] neighbor

cdef Test a

a.neighbor = (0, 1)


