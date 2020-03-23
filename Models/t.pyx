#distutils: language = c++
#cython: language_level=3

cimport numpy as np
import numpy as np
cdef extern from "<algorithm>" namespace "std" nogil:
    void swap[T] (T &a, T &b)
cdef:
    long[::1] a1 = np.zeros(10, dtype = long, order = 'C')
    long* p1 = &a1[0] 

    long[::1] a2 = np.zeros(10, dtype = long, order = 'C') 
    long* p2 = &a2[0]


from cython.operator cimport dereference as deref
with nogil:
    swap(p1, p2)
    a2[0] = 150
#a2[0] = 2000
    a1[0] = -1
    a1[1] = 3
assert p1[0] == 150
assert p2[1] == 3
for i in range(2):
    print(f'{i} a1: {a1[i]} p1: {p1[i]}\ta2: {a2[i]} p2: {p2[i]}')


from PlexSim.Models.FastIsing import Ising
import networkx as nx
g = nx.path_graph(3)
m = Ising(graph = g,\
          t = np.inf, \
          updateType='sync')

samples = m.sampleNodes(10000).base
from libcpp.vector cimport vector


for i in samples.flat:
    if i < 0:
        assert False, "wrong"
    

x = np.asarray([.1, 1, np.inf])
mag, sus = m.matchMagnetization(temperatures = x,\
                                n = 100)
print(mag)
m.t = np.inf
print(m.simulate(5))

