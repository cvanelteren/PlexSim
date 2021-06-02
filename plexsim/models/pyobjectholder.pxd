# distutils: language=c++
# container for parallel spawning model
from cpython cimport PyObject

cdef extern from "plexsim/lib/pyobjectholder.cpp":
    pass

cdef extern from "plexsim/lib/pyobjectholder.hpp":
    cdef cppclass PyObjectHolder:
        PyObjectHolder() except +
        PyObjectHolder(PyObject *o) nogil
        PyObject *ptr
