# distutils: language = c++
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Jun  7 10:37:33 2019

@author: casper
"""

import matplotlib.pyplot as plt, numpy as np
from vispy import app, scene, visuals
from Models.Models cimport Model
import networkx as nx

cdef class Percolation(Model):
    def __init__(self, graph, p = 1, agentStates = [0, 1], updateType = 'single'):
        super(Percolation, self).__init__(**locals())
        self.p = p
    cdef long[::1] _updateState(self, long[::1] nodesToUpdate) nogil:
        cdef:
            int node, neighbor, N = nodesToUpdate.shape[0]
        for node in range(N):
            node = nodesToUpdate[node]
            if self._states[node]:
                for neighbor in range(self._adj[node].neighbors.size()):
                    neighbor = self._adj[node].neighbors[neighbor]
                    if self.rand() < self.p:
                        self._states[neighbor] = 1
        return self._states
    cpdef long[::1] updateState(self, long[::1] nodesToUpdate):
        return self._updateState(nodesToUpdate)
    cpdef void reset(self):
        self.states = np.random.choice(self.agentStates, p = [1 - self.p, self.p], size = self.nNodes)
