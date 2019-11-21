#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Jun 26 13:41:13 2018

@author: casper
"""
from models import Model
import numpy as np
class RBN(Model):
    def __init__(self, graph, agentStates = [0, 1], updateType= 'async'):
        super(RBN, self).__init__(graph = graph, agentStates = agentStates, \
             updateType= mode)
        ''' For each node we need to setup a random rule; this rule is generated from its inputs
        '''
        
        # store the random rule for each node
        self.rules = {}
        for node, idx in self.mapping.items():
            n    = 2 ** len(self.interaction[idx])
            rule = np.random.randint(0, 2 ** n)
            rule = format(rule, f'0{n}b')
            self.rules[idx] = rule
    def updateState(self, nodesToUpdate):
        states = self.states.copy() if self.updateType== 'sync' else self.states # only copy on sync else alias
        n = len(nodesToUpdate)

        for i in range(n):
            node      = nodesToUpdate[i]
            rule      = self.rules[node]
            neighbors = self.interaction[node]
            number = 0
            for idx, neighbor in enumerate(neighbors):
                number += 2**idx * states[int(neighbor)]
            self.states[node] = int(rule[number])
        
        return self.states

            


if __name__ == '__main__':
    import networkx as nx
    graph = nx.random_graphs.erdos_renyi_graph(3, .3)
    rbn = RBN(graph)
    states = rbn.simulate(nSamples = 100)
    print(states)
    