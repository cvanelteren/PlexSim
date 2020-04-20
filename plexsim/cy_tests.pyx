#distutils: language=c++
#cython: language_level=3

cdef extern from *:
    ctypedef struct PyObject
from libcpp.vector cimport vector
from libcpp.pair cimport  pair
from cython.operator cimport dereference as deref
from libc.stdlib cimport malloc, free
cdef extern from "<algorithm>" namespace "std" nogil:
    void swap[T] (T &a, T &b)

cdef struct Test:
    pair[long, double] neighbor

cimport numpy as np
import numpy as np


cdef struct Test:
    int x
    int y

cdef vector[Test] b
cdef Test tmp
