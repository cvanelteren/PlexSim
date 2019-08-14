# -*- coding: utf-8 -*-
"""
Created on Sun Apr  1 18:59:12 2018

@author: Cas
"""
import networkx as nx
#from models import Model
from FastIsing import Ising
from numpy import *
class XOR(Ising):
    # TODO: this class is presenteed as is; the target in updateState needs to be considered
    def __init__(self, updateType= 'serial'):
        graph = nx.DiGraph()
        [graph.add_node(i) for i in range(3)]
        graph.add_edge(0, 2, weight = 1)
        graph.add_edge(1, 2, weight = 1)
#        print(graph.nodes())
        agentStates = [-1, 1]
        super(XOR, self).__init__(graph = graph, agentStates = agentStates, updateType= mode, temperature = 1)

    def updateState(self):
        nodesToUpdate = self.sampleNodes[self.mode](self.nodeIDs) # use updateTypewhen the model was defines
        states        = self.states.copy() if self.updateType== 'sync' else self.states # only copy if sync else alias
        for node in nodesToUpdate:
            if self.rmapping[node] != 2:
                energy, flipEnergy = self.energy(node)
                betaDeltaEnergy = -self.beta*(flipEnergy - energy)
                betaDeltaEnergy = 0 if isnan(betaDeltaEnergy) else betaDeltaEnergy
                p = float_power(1 + exp(betaDeltaEnergy), -1) # temp -> 0 beta -> inf exp (-beta) -> 0
                # if the new energy energy is more only keep with prob p
    #            p = 1/2 if isnan(p) else p # inf * 0 = nan, should be 1/2 using l'hopital (exp(0)))
    #            print(node, p, flipEnergy - energy, self.beta)
                self.states[node] = states[node] if random.rand() <= p  else -states[node]
            else:
                neighbors = self.edgeData[node][:, 0]
                z = (self.states[int32(neighbors)] + 1) /  2
#                print(z)
                # 11 00 = 0
                if z[0] and z[1]:
                    self.states[node] = -1
                # 10 01 = 1
                elif any(z):
                    self.states[node] = 1
        return self.states # maybe aliasing again

class AND(XOR):
    '''
    Same properties as XOR; however small change in the state of 2
    '''
    def __init__(self, updateType= 'serial'):
        super(AND, self).__init__(mode)
    def updateState(self):
        nodesToUpdate = self.sampleNodes[self.mode](self.nodeIDs) # use updateTypewhen the model was defines
        states        = self.states.copy() if self.updateType== 'sync' else self.states # only copy if sync else alias
        for node in nodesToUpdate:
            if self.rmapping[node] != 2:
                energy, flipEnergy = self.energy(node)
                betaDeltaEnergy = -self.beta*(flipEnergy - energy)
                betaDeltaEnergy = 0 if isnan(betaDeltaEnergy) else betaDeltaEnergy
                p = float_power(1 + exp(betaDeltaEnergy), -1) # temp -> 0 beta -> inf exp (-beta) -> 0
                # if the new energy energy is more only keep with prob p
    #            p = 1/2 if isnan(p) else p # inf * 0 = nan, should be 1/2 using l'hopital (exp(0)))
    #            print(node, p, flipEnergy - energy, self.beta)
                self.states[node] = states[node] if random.rand() <= p  else -states[node]
            else:
                neighbors = self.edgeData[node][:, 0]
                z = (self.states[int32(neighbors)] + 1) /  2
#                print(z)
                # 11 00 = 0
                if z[0] and z[1]:
                    self.states[node] = 1
                # 10 01 = 1
                else :
                    self.states[node] = -1
        return self.states # maybe aliasing again

if __name__ == '__main__':
    # g = XOR()
    g = AND()
    # from simulate import simulate
    e = simulate(g, 100, 1)
    print(unique(e, axis = 0))
