# distutils: language=c++
# cython: language_level=3
# cython:
# cython: boundscheck=False
# cython: wraparound=False

import time
import sys

from cpython.array cimport array, clone
from cpython.mem cimport PyMem_Malloc as pmalloc, PyMem_Free as pfree
from libcpp.vector cimport vector
from cython.view cimport array as cvarray
from libc.stdlib cimport malloc, free
import numpy as numpy
cimport numpy as numpy

cdef int loops

def timefunc(name):
    def timedecorator(f):
        cdef int L, i

        print("Running", name)
        for L in [1, 10, 20, 100, 1000, 10_000, 100_000 ]:
            start = time.time()
            f(L)
            end = time.time()
            print(format((end-start) / loops * 1e6, "2f"), end=" ")
            sys.stdout.flush()

        print("μs")
    return timedecorator

print()
print("INITIALISATIONS")
loops = 100000

@timefunc("cpython.array buffer")
def _(int L):
    cdef int i
    cdef array[double] arr, template = array('d')

    for i in range(loops):
        arr = clone(template, L, False)

    # Prevents dead code elimination
    str(arr[0])

@timefunc("cpython.array memoryview")
def _(int L):
    cdef int i
    cdef double[::1] arr
    cdef array template = array('d')

    for i in range(loops):
        arr = clone(template, L, False)

    # Prevents dead code elimination
    str(arr[0])

@timefunc("cpython malloc")
def _(int L):
    cdef int i
    cdef double * pv
    for i in range(loops):
        pv = <double *> pmalloc(L * sizeof(double))
        pfree(pv)
    str(pv[0])
@timefunc("cpython.array raw C type")
def _(int L):
    cdef int i
    cdef array arr, template = array('d')

    for i in range(loops):
        arr = clone(template, L, False)

    # Prevents dead code elimination
    str(arr[0])

@timefunc("numpy.empty_like memoryview")
def _(int L):
    cdef int i
    cdef double[::1] arr
    template = numpy.empty((L,), dtype='double')

    for i in range(loops):
        arr = numpy.empty_like(template)

    # Prevents dead code elimination
    str(arr[0])


@timefunc("c++ vector")
def _(int L):
    cdef int i
    cdef vector[double] v
    for i in range(loops):
        v = vector[double](L)

    str(v[0])
@timefunc("malloc")
def _(int L):
    cdef int i
    cdef double* arrptr

    for i in range(loops):
        arrptr = <double*> malloc(sizeof(double) * L)
        free(arrptr)

    # Prevents dead code elimination
    str(arrptr[0])

@timefunc("malloc memoryview")
def _(int L):
    cdef int i
    cdef double* arrptr
    cdef double[::1] arr

    for i in range(loops):
        arrptr = <double*> malloc(sizeof(double) * L)
        arr = <double[:L]>arrptr
        free(arrptr)

    # Prevents dead code elimination
    str(arr[0])

@timefunc("cvarray memoryview")
def _(int L):
    cdef int i
    cdef double[::1] arr

    for i in range(loops):
        arr = cvarray((L,),sizeof(double),'d')

    # Prevents dead code elimination
    str(arr[0])



print()
print("ITERATING")
loops = 1000

@timefunc("cpython.array buffer")
def _(int L):
    cdef int i
    cdef array[double] arr = clone(array('d'), L, False)

    cdef double d
    for i in range(loops):
        for i in range(L):
            d = arr[i]

    # Prevents dead-code elimination
    str(d)

@timefunc("cpython.array memoryview")
def _(int L):
    cdef int i
    cdef double[::1] arr = clone(array('d'), L, False)

    cdef double d
    for i in range(loops):
        for i in range(L):
            d = arr[i]

    # Prevents dead-code elimination
    str(d)

@timefunc("Python malloc")
def _ (int L):
    cdef int i
    cdef double* pv = <double*> pmalloc(L * sizeof(double))
    cdef double d
    for i in range(loops):
        for i in range(L):
            d = pv[i]
    pfree(pv)
    str(d)



from cython.operator cimport dereference as derf
@timefunc("c++ vector")
def _ (int L):
    cdef int i
    cdef vector[double]* v = new vector[double](L)
    cdef double d
    for i in range(loops):
        for i in range(L):
            d = derf(v)[i]
    v.clear()
    str(d)

@timefunc("cpython.array raw C type")
def _(int L):
    cdef int i
    cdef array arr = clone(array('d'), L, False)

    cdef double d
    for i in range(loops):
        for i in range(L):
            d = arr[i]

    # Prevents dead-code elimination
    str(d)

@timefunc("numpy.empty_like memoryview")
def _(int L):
    cdef int i
    cdef double[::1] arr = numpy.empty((L,), dtype='double')

    cdef double d
    for i in range(loops):
        for i in range(L):
            d = arr[i]

    # Prevents dead-code elimination
    str(d)

@timefunc("malloc")
def _(int L):
    cdef int i
    cdef double* arrptr = <double*> malloc(sizeof(double) * L)

    cdef double d
    for i in range(loops):
        for i in range(L):
            d = arrptr[i]

    free(arrptr)

    # Prevents dead-code elimination
    str(d)

@timefunc("malloc memoryview")
def _(int L):
    cdef int i
    cdef double* arrptr = <double*> malloc(sizeof(double) * L)
    cdef double[::1] arr = <double[:L]>arrptr

    cdef double d
    for i in range(loops):
        for i in range(L):
            d = arr[i]

    free(arrptr)

    # Prevents dead-code elimination
    str(d)

@timefunc("cvarray memoryview")
def _(int L):
    cdef int i
    cdef double[::1] arr = cvarray((L,),sizeof(double),'d')

    cdef double d
    for i in range(loops):
        for i in range(L):
            d = arr[i]

    # Prevents dead-code elimination
    str(d)
