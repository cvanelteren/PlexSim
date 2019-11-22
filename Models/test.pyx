#distutils: language = c++
from cython cimport numeric

ctypedef fused DTYPE:
    long
    int 
    float
    double

cdef DTYPE[::1] _test( DTYPE[::1] idx ):
  return idx

cpdef DTYPE[::1] test( DTYPE[::1] idx , int length ):
    cdef int i
    cdef long j = 0
    cdef bint h
    h = j > idx[0]

    idx[0] = j
    for i in range(length):
        idx[i] = -idx[i]
    return _test( idx )
