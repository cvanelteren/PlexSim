# distutils: language=c++
from Models.models cimport Model
from libcpp.vector cimport vector

# from models cimport Model
import numpy  as np
cimport numpy as np

from libc.math cimport exp

cdef class Potts(Model):
    def __init__(self, \
                graph,\
                 temperature = 1,\
                 agentStates = [-1 ,1, 0],\
                 nudgeType   = 'constant',\
                 updateType  = 'async', \
                 ):
        super(Potts, self).__init__(\
                  graph           = graph, \
                  agentStates  = agentStates, \
                  updateType  = updateType, \
                  nudgeType   = nudgeType)


        cdef np.ndarray H  = np.zeros(self.graph.number_of_nodes(), float)
        for node, nodeID in self.mapping.items():
            H[nodeID] = graph.nodes()[node].get('H', 0)
        # for some reason deepcopy works with this enabled...
        self.states           = np.asarray(self.states.base).copy()
        self.nudges         = np.asarray(self.nudges.base).copy()
        # specific model parameters
        self._H               = H
        # self._beta             = np.inf if temperature == 0 else 1 / temperature
        self.t                  = temperature

    cpdef long[::1] updateState(self, long[::1] nodesToUpdate):
        return self._updateState(nodesToUpdate)

    @property
    def magSide(self):
        for k, v in self.magSideOptions.items():
            if v == self._magSide:
                return k
    @magSide.setter
    def magSide(self, value):
        idx = self.magSideOptions.get(value,\
              f'Option not recognized. Options {self.magSideOptions.keys()}')
        if isinstance(idx, int):
            self._magSide = idx
        else:
            print(idx)
    @property
    def H(self): return self._H

    @property
    def beta(self): return self._beta

    @beta.setter
    def beta(self, value):
        self._beta = value

    @property
    def t(self):
        return self._t

    @t.setter
    def t(self, value):
        self._t   = value
        self.beta = 1 / value if value != 0 else np.inf


    cdef double[::1] energy(self, int node, long[::1] states) nogil:
        cdef:
            long neighbors = self._adj[node].neighbors.size()
            long neighbor, neighboridx
            double weight
            long possibleState
            vector[double] energy
        # count the neighbors in the different possible states
        for neighboridx in range(neighbors):
            neighbor  =  self._adj[node].neighbors[neighboridx]
            weight     = self._adj[node].weights[neighboridx]
            for possibleState in range(self._nStates):
                # assume the node is in some state
                if states[neighbor] == self.agentStates[possibleState]:
                    energy[possibleState]  *= exp(-self._beta * weight)
        return energy
    cdef long[::1] _updateState(self, long[::1] nodesToUpdate) nogil:

        """
        Generate conditional distribution based on a change in state
        For all agent states compute the likelihood of staying in that state
        """

        cdef:
            int nodes = nodesToUpdate.shape[0]
            long node
            double[::1] probs
            int agentState
            double previous = 0, randomNumber, Z
        for node in range(nodes):
            node = nodesToUpdate[node]
            probs = self.energy(node, self._states)
            Z       = 0
            for agentState in range(self._nStates):
                Z += probs[agentState]

            randomNumber = self.rand()
            previous      = 0

            # check all possible agent states
            for agentState in range(self._nStates):
                # update probability to cumulative
                probs[agentState] = probs[agentState] /  Z + previous
                # check whether to swap state,  at most check all states
                if probs[agentState] <= randomNumber:
                    self._newstates[node] = self.agentStates[agentState]
                    break
                previous += probs[agentState]
        # repopulate buffer
        for node in range(self._nNodes):
            self._states[node] = self._newstates[node]
        return self._states
