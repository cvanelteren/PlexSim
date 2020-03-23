# distutils: language = c++
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Jun  7 10:37:33 2019

@author: casper
"""

import matplotlib.pyplot as plt, numpy as np
from vispy import app, scene, visuals
from PlexSim.Models.Models cimport Model
import networkx as nx

cdef class Percolation(Model):
    def __init__(self, graph, p = 1, agentStates = [0, 1], updateType = 'single'):
        super(Percolation, self).__init__(**locals())
        self.p = p
    @property
    def p(self):
        return self._p
    @p.setter
    def p(self, value):
        self._p = value
    cdef void _step(self, long node) nogil:
        cdef:
            long neighbor
        if self._states_ptr[node]:
            for neighbor in range(self._adj[node].neighbors.size()):
                neighbor = self._adj[node].neighbors[neighbor]
                if self._rand() < self._p:
                    self._newstates_ptr[neighbor] = 1
        return 
    cpdef void reset(self):
        self.states = np.random.choice(self.agentStates, p = [1 - self.p, self.p], size = self.nNodes)
        return 
