#distutils: language=c++
from cython.operator cimport dereference as deref, preincrement as inc

cdef y_t c = y_t(x_t(1))
print(c.a.x)

# works
cdef F(y_t &x):
   print(x.a.x)

f(c)
