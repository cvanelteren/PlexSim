#distutils: language=c++
#distutils: include_dirs = "plexsim/include/"
#distutils: sources = "plexsim/include/pyobjectholder.cpp"

# container for parallel spawning model
from cpython cimport PyObject

cdef extern from "plexsim/include/pyobjectholder.cpp":
    pass

cdef extern from "plexsim/include/pyobjectholder.hpp":
    cdef cppclass PyObjectHolder:
        PyObjectHolder() except +
        PyObjectHolder(PyObject *o) nogil
        PyObject *ptr


# cdef extern from "/home/casper/projects/PlexSim/plexsim/lib/pyobjectholder.cpp":
#     pass

# cdef extern from "/home/casper/projects/PlexSim/plexsim/lib/pyobjectholder.hpp"
#     cdef cppclass PyObjectHolder:
#         PyObjectHolder() except +
#         PyObjectHolder(PyObject *o) nogil
#         PyObject *ptr
