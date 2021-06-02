import numpy as np
cimport numpy as np, cython
from cython.operator cimport dereference as deref
from cython.operator cimport preincrement as prei
from cython.operator cimport postincrement as post

cdef class Cycledelic(Model):
    """ From Dirk Brockmann"""
    def __init__(self, graph, double predation = 2,
                 double competition = 1.5,
                 double diffusion = 0.05,
                 **kwargs):
        cdef np.ndarray agentStates = np.arange(0, 3)
        super(Cycledelic, self).__init__(graph = graph, agentStates = agentStates)

        self.predation = predation
        self.competition = competition
        self.diffusion = diffusion

        #self.coloring = np.ones((self.nNodes, self.nStates)) *1/<float>(self.nStates)
        self.coloring = np.random.rand(self.nNodes, self.nStates)

    @property
    def colors(self):
        return self.coloring.base
    @colors.setter
    def colors(self, val):
        self.coloring = self.coloring * val

    cdef vector[state_t] update_coloring(self, state_t[::1] colors, node_id_t node) nogil:
        cdef double change
        cdef vector[state_t] tmp = vector[state_t](self._nStates, 0)
        cdef double dt = 0.1
        tmp[0] = colors[0] * dt * (self.predation * (colors[1] - colors[2]) + colors[0]  - self.competition * (colors[1] + colors[2]) - colors[0]**2)
        tmp[1] = colors[1] * dt * (self.predation * (colors[2] - colors[0]) + colors[1]  - self.competition * (colors[0] + colors[2]) - colors[1]**2)
        tmp[2] = colors[2] * dt * (self.predation * (colors[0] - colors[1]) + colors[2]  - self.competition * (colors[0] + colors[1]) - colors[2]**2)

        it = self.adj._adj[node].neighbors.begin()
        cdef float N = <float>(self.adj._adj[node].neighbors.size())
        cdef node_id_t neighbor
        cdef size_t state
        while it != self.adj._adj[node].neighbors.end():
            neighbor = deref(it).first
            for state in range(self._nStates):
                tmp[state] += dt * self.diffusion / N * (self.coloring[neighbor, state] - colors[state])
            post(it)
        return tmp
    cdef void _step(self, node_id_t node) nogil:

        cdef size_t idx = self.adj._adj[node].neighbors.size()

        cdef node_id_t neighbor = <node_id_t> (self._rng._rand() * idx)
        cdef state_t neighbor_state = self._states[neighbor] 
        cdef state_t node_state = self._states[node]

        it = self.adj._adj[node].neighbors.begin()
        #while it != self._adj[node].neighbors.end():
        
        cdef vector[state_t] change = self.update_coloring(self.coloring[node], node)
        cdef size_t state
        cdef double dt = 0.1
        for state in range(self._nStates):
            #if change[state] < 0:
            #    change[state] = 0
            self.coloring[node, state] += change[state] 
            if self.coloring[node, state] < 0:
                self.coloring[node, state] = 0

        ## A + B -> 2A
        #if node_state == 0 and neighbor_state == 1:
        #    self._newstates[neighbor] = 0
        #    self._newstates[node] = 0
        #elif node_state == 1 and neighbor_state == 0:
        #    self._newstates[neighbor] = 0
        #    self._newstates[node] = 0

        ## B + C -> 2B
        #elif node_state == 2 and neighbor_state == 1:
        #    self._newstates[neighbor] = 1
        #    self._newstates[node] = 1
        #elif node_state == 1 and neighbor_state == 2:
        #    self._newstates[neighbor] = 1
        #    self._newstates[node] = 1
        ## C + A -> 2C
        #elif node_state == 2 and neighbor_state == 0:
        #    self._newstates[neighbor] = 1
        #    self._newstates[node] = 1
        #elif node_state == 0 and neighbor_state == 2:
        #    self._newstates[neighbor] = 2
        #    self._newstates[node] = 2
        ## just copy
        #else:
        #    self._newstates[neighbor] = self._states[neighbor]
        #    self._newstates[node] = self._states[node]
        return


    cpdef np.ndarray simulate(self, size_t samples):
        """"
        :param samples: number of samples to simulate
        :type: int 
        returns:
            np.ndarray containing the system states to simulate 
        """
        cdef:
            state_t[:, :, ::1] results = np.zeros((samples, self.adj._nNodes, self._nStates), dtype = np.double)
            # int sampleSize = 1 if self._updateType == 'single' else self.adj._nNodes
            node_id_t[:, ::1] r = self.sampleNodes(samples)
            # vector[vector[int][sampleSize]] r = self.sampleNodes(samples)
            int i

        results[0] = self.coloring
        for i in range(1, samples):
            self._updateState(r[i])
            results[i] = self.coloring
        return results.base # convert back to normal array

cdef class CycledelicAgent(Model):
    """
    Agent-based inspired implementation of rock-paper-scissor dynamics    
    """
    def __init__(self, graph, double predation = 2, reproduction = 1.5,  mobility = .05):
       
        # states:
        # 0 = dead
        # 1 = rock
        # 2 = paper
        # 3 = scissor
        cdef np.ndarray agentStates = np.arange(4) 
        super(CycledelicAgent, self).__init__(graph = graph, agentStates = agentStates)
        self.predation = predation
        self.reproduction = reproduction
        self.mobility = mobility
    cdef void _step(self, node_id_t node) nogil:
        cdef:
            node_id_t neighbor

        # pick random neighbor
        cdef size_t idx = <size_t> (self._rng._rand() * self.adj._adj[node].neighbors.size())

        it  = self.adj._adj[node].neighbors.begin()

        #double rng 
        while it != self.adj._adj[node].neighbors.end():
            neighbor =  deref(it).first


            rng = self._rng._rand()
            if self._states[neighbor] == 0:
                if self._rng._rand() < self.reproduction:
                    self._states[neighbor] = self._states[node]
            else:
                # kill
                if self._rng._rand() < self.predation:
                    # paper kills rock
                    if self._states[node] == 1 and self._states[neighbor] == 2:
                        self._newstates[node] = 0
                    # rock kills paper
                    elif self._states[node] == 1 and self._states[neighbor] == 3:
                        self._newstates[neighbor] = 0
                    # paper kills rock
                    elif self._states[node] == 2 and self._states[neighbor] == 1:
                        self._newstates[neighbor] = 0
                    # scissor kills paper
                    elif self._states[node] == 2 and self._states[neighbor] == 3:
                        self._newstates[node] = 0
                    # rock kills scisssor
                    elif self._states[node] == 3 and self._states[neighbor] == 1:
                        self._newstates[node] = 0
                    # scissor kills rock
                    elif self._states[node] == 3 and self._states[neighbor] == 2:
                        self._newstates[neighbor] = 0
                    # nothing happens
                    else:
                        self._newstates[node] = self._states[node]
                # move with mobility: swap states 
                if self._rng._rand() < self.mobility:
                    swap(self._states[node], self._states[neighbor])
            post(it)
        return
                
        
        
