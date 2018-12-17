#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Jun 27 13:54:09 2018

@author: casper
"""

from models import Model
import numpy as np

class Net(Model):
    def __init__(self, graph, threshold = .5):
        super(Net, self).__init__(graph = graph, agentStates = [0, 1])
        self.threshold = threshold # threshold of neuron
        # non-linear transfer function
    # note: can't pickle lambdas
    def func(self, x):
        return 1 / (1 + np.exp(-x))
    def updateState(self, nodesToUpdate):
        states = self.states.copy() if self.updateType== 'sync' else self.states
        for node in nodesToUpdate:
            weights = self.interaction[node]
            nStates = states[self.edgeData[node]] # neighbor states
            input   = weights.dot(nStates)
            if self.func(input) > self.threshold:
                states[node] = 1
#            else:
#                states[node] = 0
        return self.states
