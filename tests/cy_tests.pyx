#distutils: language=c++
#cython: language_level=3


cimport cython
from libcpp.unordered_map cimport unordered_map
from libcpp.vector cimport vector
from cython.operator cimport dereference as deref, preincrement, postincrement as post
cimport numpy as np; import numpy as np
cdef struct Agent:
    long id
    long state

cdef unordered_map[long, Agent] Agents



cdef Agent agent

cdef vector[long*] test  

for i in range(10):
    agent.id = i
    agent.state = 1
    Agents[i] = agent
    test.push_back(&Agents[i].state)


Agents[1].state = 3






