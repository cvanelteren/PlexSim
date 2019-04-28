# cython: infer_types=True
# distutils: language=c++
# __author__ = 'Casper van Elteren'


import numpy as np
cimport numpy as np
import networkx as nx, functools, time
from tqdm import tqdm
import copy

cimport cython
from cython.parallel cimport parallel, prange
from cython.operator cimport dereference, preincrement
from libc.stdlib cimport malloc, free
# from libc.stdlib cimport rand
from libc.string cimport strcmp
from libc.stdio cimport printf
from libcpp.vector cimport vector
from libcpp.map cimport map
from libcpp.unordered_map cimport unordered_map
from libc.math cimport lround
# cdef extern from "limits.h":
#     int INT_MAX
#     int RAND_MAX

__VERSION__ = 1.2 # added version number
# SEED SETUP
from posix.time cimport clock_gettime,\
timespec, CLOCK_REALTIME

# from sampler cimport Sampler # mersenne sampler
cdef class Model: # see pxd
    def __init__(self,\
                 **kwargs,\
                 ):
        '''
        General class for the models
        It defines the expected methods for the model; this can be expanded
        to suite your personal needs but the methods defined here need are relied on
        by the rest of the package.

        It translates the networkx graph into c++ unordered_map map for speed

        kwargs should at least have:
        :graph: a networkx graph

        optional:
            :agentStates: the states that the agents can assume [default = [0,1]]
            :updateType: how to sample the state space (default async)
            :nudgeType: the type of nudge used (default: constant)
            :memorySize: use memory dynamics (default 0)
        '''
        # print('Init model')
        # use current time as seed for rng
        cdef timespec ts
        clock_gettime(CLOCK_REALTIME, &ts)
        cdef unsigned int seed = ts.tv_sec
        # define rng sampler
        self.dist = uniform_real_distribution[double](0.0, 1.0)
        self.seed = seed
        self.gen  = mt19937(self.seed)

        # create adj list
        self.construct(kwargs.get('graph'), kwargs.get('agentStates', [0, 1]))
        self.nudgeType  = copy.copy(kwargs.get('nudgeType', 'constant'))
        self.updateType = kwargs.get('updateType', 'async')
        # self.memory = np.ones((memorySize, self._nNodes), dtype = long) * np.NaN   # note keep the memory first not in state space, i.e start without any form memory
        
        # create memory
        self.memorySize   = kwargs.get('memorySize', 0)
        self._memory      = np.random.choice(self.agentStates, size = (self.memorySize, self._nNodes))



    cpdef void construct(self, object graph, list agentStates):
        """
        Constructs adj matrix using structs
        """
        # print('Constructing')
        # check if graph has weights or states assigned and or nudges
        # note does not check all combinations
        # input validation / construct adj lists
        # defaults
        DEFAULTWEIGHT = 1.
        DEFAULTNUDGE  = 0.
        # DEFAULTSTATE  = random # don't use; just for clarity

        # forward declaration and init
        cdef:
            dict mapping = {} # made nodelabe to internal
            dict rmapping= {} # reverse
            # str delim = '\t'
            np.ndarray states = np.zeros(graph.number_of_nodes(), int, 'C')
            int counter = 0
            # double[::1] nudges = np.zeros(graph.number_of_nodes(), dtype = float)
            np.ndarray nudges = np.zeros(graph.number_of_nodes(), dtype = float)
            unordered_map[long, Connection] adj # see .pxd

        # new data format
        if getattr(graph, '__version__', __VERSION__ ) > 1.0:
            # generate graph in json format
            nodelink = nx.node_link_data(graph)

            for nodeidx, node in enumerate(nodelink['nodes']):
                id                = node.get('id')
                if type(id) is not str and type(id) is not tuple:
                    # print(type(id))
                    id = float(id)

                mapping[id]       = nodeidx
                rmapping[nodeidx] = id
                states[nodeidx]   = <long>   node.get('state', np.random.choice(agentStates))
                nudges[nodeidx]   = <double> node.get('nudge', DEFAULTNUDGE)
            directed  = nodelink.get('directed')
            for link in nodelink['links']:
                source = mapping[link.get('source')]
                target = mapping[link.get('target')]
                weight = <double> link.get('weight', DEFAULTWEIGHT)
                # reverse direction for inputs
                if directed:
                    # get link as input
                    adj[target].neighbors.push_back(source)
                    adj[target].weights.push_back(weight)
                else:
                    # add neighbors
                    adj[source].neighbors.push_back(target)
                    adj[target].neighbors.push_back(source)

                    # add weights
                    adj[source].weights.push_back(weight)
                    adj[target].weights.push_back(weight)
        # version <= 1.0
        else:
            print("Using legacy loader")
            from ast import literal_eval
            for line in nx.generate_multiline_adjlist(graph, ','):
                add = False # tmp for not overwriting doubles
                # input validation
                lineData = []
                # if second is not dict then it must be source
                for prop in line.split(','):
                    try:
                        i = literal_eval(prop) # throws error if only string
                        lineData.append(i)
                    except:
                        lineData.append(prop) # for strings
                node, info = lineData
                # check properties, assign defaults
                if 'state' not in graph.node[node]:
                    idx = np.random.choice(agentStates)
                    # print(idx, agentStates)
                    graph.node[node]['state'] = idx
                if 'nudge' not in graph.node[node]:
                    graph.node[node]['nudge'] =  DEFAULTNUDGE

                # if not dict then it is a source
                if isinstance(info, dict) is False:
                    # add node to seen
                    if node not in mapping:
                        # append to stack
                        counter             = len(mapping)
                        mapping[node]       = counter
                        rmapping[counter]   = node

                    # set source
                    source   = node
                    sourceID = mapping[node]

                    states[sourceID] = <long> graph.node[node]['state']
                    nudges[sourceID] = <double> graph.node[node]['nudge']
                # check neighbors
                else:
                    if 'weight' not in info:
                        graph[source][node]['weight'] = DEFAULTWEIGHT
                    if node not in mapping:
                        counter           = len(mapping)
                        mapping[node]     = counter
                        rmapping[counter] = node

                    # check if it has a reverse edge
                    if graph.has_edge(node, source):
                        sincID = mapping[node]
                        weight = graph[node][source]['weight']
                        # check if t he node is already in stack
                        if sourceID in set(adj[sincID]) :
                            add = True
                        # not found so we should add
                        else:
                            add = True
                    # add source > node
                    sincID = <long> mapping[node]
                    adj[sourceID].neighbors.push_back(<long> mapping[node])
                    adj[sourceID].weights.push_back(<double> graph[source][node]['weight'])
                    # add reverse
                    if add:
                        adj[sincID].neighbors.push_back( <long> sourceID)
                        adj[sincID].weights.push_back( <double> graph[node][source]['weight'])

        # public and python accessible
        self.graph       = graph
        self.mapping     = mapping
        self.rmapping    = rmapping
        self._adj        = adj

        self._agentStates = np.asarray(agentStates, dtype = int).copy()
        # print(states, agentStates)

        self._nudges     = nudges.copy()
        self._nStates    = len(agentStates)


        #private
        # note nodeids will be shuffled and cannot be trusted for mapping
        # use mapping to get the correct state for the nodes

        _nodeids        = np.arange(graph.number_of_nodes(), dtype = long)
        np.random.shuffle(_nodeids) # prevent initial scan-lines in grid
        self._nodeids   = _nodeids.copy()
        self._states    = states.copy()
        self._newstates = states.copy()
        self._nNodes    = graph.number_of_nodes()
        # print(f'Done {id(self)}')

    # cdef long[::1]  _updateState(self, long[::1] nodesToUpdate) :
    cdef long[::1]  _updateState(self, long[::1] nodesToUpdate) nogil:
        return self._nodeids


    cpdef long[::1] updateState(self, long[::1] nodesToUpdate):
        return self._nodeids


    cdef double rand(self) nogil:
        return self.dist(self.gen)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cdef long[:, ::1] sampleNodes(self, long  nSamples) nogil:
    # cdef long [:, ::1] sampleNodes(self, long  nSamples):
        """
        Shuffles nodeids only when the current sample is larger
        than the shuffled array
        N.B. nodeids are mutable
        """
        # check the amount of samples to get
        cdef int sampleSize
        if self._updateType == 'single':
            sampleSize = 1
        # elif self._updateType == 'serial':
        #     return self._nodeids[None, :]
        else:
            sampleSize = self._nNodes
        cdef:
            # TODO replace this with a nogil version
            # long _samples[nSamples][sampleSize]
            long [:, ::1] samples
            # long sample
            long start
            long i, j, k
            long samplei

            # vector[vector[int][sampleSize]] samples

        # replace with nogil variant
        with gil:
            samples = np.ndarray((nSamples, sampleSize), dtype = int)

        for samplei in range(nSamples):
            # shuffle if the current tracker is larger than the array
            start  = (samplei * sampleSize) % self._nNodes
            if self._updateType != 'serial' and (start + sampleSize >= self._nNodes or sampleSize == 1):
                for i in range(self._nNodes):
                    # shuffle the array without replacement
                    j                = lround(self.rand() * (self._nNodes - 1))
                    k                = self._nodeids[j]
                    self._nodeids[j] = self._nodeids[i]
                    self._nodeids[i] = k
                    # enforce atleast one shuffle in single updates; otherwise same picked
                    if sampleSize == 1 : break
            # assign the samples; will be sorted in case of serial
            for j in range(sampleSize):
                samples[samplei][j]    = self._nodeids[start + j]
        return samples

    cpdef void reset(self):
        self.states = np.random.choice(\
                self.agentStates, size = self._nNodes)


    def removeAllNudges(self):
        """
        Sets all nudges to zero
        """
        self.nudges[:] = 0

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cpdef np.ndarray simulate(self, long long int  samples):
        cdef:
            long[:, ::1] results = np.zeros((samples, self._nNodes), int)
            int sampleSize = 1 if self._updateType == 'single' else self._nNodes
            long[:, ::1] r = self.sampleNodes(samples)
            # vector[vector[int][sampleSize]] r = self.sampleNodes(samples)
            int i
        results[0] = self._states
        for i in range(samples - 1):
            results[i + 1] = self.updateState(r[i])
        return results.base # convert back to normal array

    # TODO: make class pickable
    # hence the wrappers
    @property
    def memorySize(self): return self._memorySize
    @memorySize.setter
    def memorySize(self, value):
        self._memorySize = value

    @property
    def memory(self): return self._memory
    @memory.setter
    def memory(self, value):
        if isinstance(value, np.ndarray):
            self._memory = value

    @property
    def agentStates(self): return list(self._agentStates) # warning has no setter!
    @property
    def adj(self)       : return self._adj
    @property
    def states(self)    : return self._states
    @property
    def updateType(self): return self._updateType
    @property
    def nudgeType(self) : return self._nudgeType
    @property #return mem view of states
    def states(self)    : return self._states
    @property
    def nodeids(self)   : return self._nodeids
    @property
    def nudges(self)    : return self._nudges
    @property
    def nNodes(self)    : return self._nNodes
    @property
    def nStates(self)   : return self._nStates
    @property
    def nodeids(self)   : return self._nodeids
    @property
    def seed(self)      : return self._seed
    @ memorySize.setter
    def memorySize(self, value):
        self._memorySize = value

    @seed.setter
    def seed(self, value):
        if isinstance(value, int) and value >= 0:
            self._seed = value
            self.gen   = mt19937(self.seed)
        else:
            print("Value is not unsigned long")


    # TODO: reset all after new?
    @nudges.setter
    def nudges(self, vals):
        """
        Set nudge value based on dict using the node labels
        """
        self._nudges[:] =  0
        if isinstance(vals, dict):
            for k, v in vals.items():
                idx = self.mapping[k]
                self._nudges[idx] = v

    @updateType.setter
    def updateType(self, value):
        """
        Input validation of the update of the model
        Options:
            - sync  : synchronous; update independently from t > t + 1
            - async : asynchronous; update n Nodes but with mutation possible
            - single: update 1 node random
            - serial: like crt scan
        """
        assert value in 'sync async single serial'
        self._updateType = value
        # allow for mutation if async else independent updates
        if value == 'async':
            self._newstates = self._states
        else:
            if value == 'serial':
                self._nodeids = np.sort(self._nodeids) # enforce  for sampler
            self._newstates = self._states.copy()

    @nudgeType.setter
    def nudgeType(self, value):
        assert value in 'constant pulse'
        self._nudgeType = value

    @states.setter # TODO: expand
    def states(self, value):
        if isinstance(value, int):
            self._newstates[:] = value
            self._states   [:] = value
        # TODO: change this to iterable check
        elif isinstance(value, np.ndarray) or isinstance(value, list):
            assert len(value) == self.nNodes
            value = np.asarray(value) # enforce
            self._newstates = value
            self._states    = value
    # TODOL move this back ^
    # cdef long[::1] updateState(self, int[:] nodesToUpdate):
    #     ""
    #     Implement this method
    #     """
    #     assert False
    # @cython.wraparound(False)
    # @cython.boundscheck(False)
    # @cython.nonecheck(False)
    # cpdef simulate(self, int nSamples, int step):
    #     # pre-define number of simulation steps
    #     cdef int N   = nSamples * step + 1
    #     cdef long[:, :] nodesToUpdate = self.sampleNodes(N)
    #     # nodesToUpdate = np.array([self.sampleNodes[self.mode](self.nodeIDs) for i in range(nSamples * step + 1)])
    #     # init storage vector
    #     cdef simulationResults = np.zeros( (nSamples + 1, self.nNodes), dtype = self.statesDtype) # TODO: this should be a generator as well
    #     cdef long[:] states               = self.states
    #
    #     simulationResults[0, :]   = states # always store current state
    #
    #     # loop declaration
    #     cdef double nudge
    #     cdef int sampleCounter = 1
    #     cdef int stepCounter   = 1 # zero step is already done?
    #
    #     cdef dict mapping     = self.mapping
    #     cdef double[:] nudges = self.nudges
    #     cdef updateState      = self.updateState
    #     cdef str nudgeType    = self.nudgeType
    #     for sampleCounter in range(N):
    #         if pulse: # run pulse; remove nudges after sim step
    #             copyNudge = nudges.copy() # make deep copy  #TODO: think this will cause slowdowns for very large networks
    #             for node, nudge in pulse.items():
    #                 if isinstance(node, tuple):
    #                     for i in node:
    #                         nudges[mapping[i]] = nudge
    #                 else:
    #                     # inject overwhelming pulse for 1 delta
    #                     if nudgeType == 'pulse':
    #                         state = states[mapping[node]]
    #                         nudges[mapping[node]] =  nudge
    #                     # constant pulse add
    #                     else:
    #                         nudges[mapping[node]] = nudge
    #
    #         # self.updateState(next(nodesToUpdate))
    #         updateState(nodesToUpdate[stepCounter])
    #         # self.updateState(nodesToUpdate.__next__()) # update generator
    #         # twice swap cuz otherway was annoying
    #         if pulse:
    #             nudges = copyNudge # reset the copy
    #             if nudgeType == 'pulse':
    #               pulse = {}
    #             elif nudgeType == 'constant' and sampleCounter >= nSamples // 2:
    #               pulse = {}
    #         if stepCounter % step == 0: # if stepCounter starts at zero 1 step is already made
    #             simulationResults[sampleCounter] = states
    #             sampleCounter += 1 # update sample counter
    #         stepCounter += 1  # update step counter
    #     # out of while
    #     else:
    #         return simulationResults
