# distutils: language=c++
from cython.operator cimport dereference as deref, preincrement as inc

from libc.stdlib cimport malloc, free
from cpython cimport PyObject
import numpy as np
cimport numpy as np
cdef double[::1] a = np.zeros(10)
a.__getitem__((0,0))

