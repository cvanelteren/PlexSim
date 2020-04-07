# distutils: language=c++
# __author__ = 'Casper van Elteren'
cimport cython

import numpy as np
cimport numpy as np
import networkx as nx, functools, time
from tqdm import tqdm
import copy

cimport cython
from cython.parallel cimport parallel, prange, threadid
from cython.operator cimport dereference as deref, preincrement, postincrement
from libc.stdlib cimport malloc, free
from libc.string cimport strcmp
from libc.stdio cimport printf
from libcpp.vector cimport vector
from libcpp.map cimport map
from libcpp.unordered_map cimport unordered_map

from libc.math cimport exp, log, cos, pi, lround, fabs 

from pyprind import ProgBar
import multiprocessing as mp

cdef extern from "<algorithm>" namespace "std" nogil:
    void swap[T] (T &a, T &b)
cdef extern from "math.h":
    bint isnan(double x) nogil

include "parallel.pxd"
include "definitions.pxi"

__VERSION__ = 1.2 # added version number
# SEED SETUP
from posix.time cimport clock_gettime,\
timespec, CLOCK_REALTIME

# from sampler cimport Sampler # mersenne sampler
cdef class Model: # see pxd 
    def __init__(self,\
                 graph,\
                 agentStates = [0],\
                 nudgeType = "constant",\
                 updateType = "async",\
                 nudges = {},\
                 seed = None,\
                 memorySize = 0,\
                 **kwargs,\
                 ):
        """
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
       """
        # use current time as seed for rng
        cdef:
            timespec ts
            unsigned int _seed
        if seed is None:
            clock_gettime(CLOCK_REALTIME, &ts)
            seed = ts.tv_sec
        elif seed >= 0:
            _seed = seed
        else:
            assert False, "seed needs uint"
        # define rng sampler
        self._dist = uniform_real_distribution[double](0.0, 1.0)
        self.seed = _seed
        self._gen  = mt19937(self.seed)
        # create adj list


        # DEFAULTS
        self.construct(graph, agentStates)

        # create properties
        self.nudgeType  = nudgeType

        # self.memory = np.ones((memorySize, self._nNodes), dtype = long) * np.NaN   # note keep the memory first not in state space, i.e start without any form memory

        # create memory
        self.memorySize   = memorySize
        self._memory      = np.random.choice(self.agentStates, size = (self.memorySize, self._nNodes))
        self.nudges = nudges
        # n.b. sampleSize has to be set from no on
        self.updateType = updateType
        self.sampleSize = kwargs.get("sampleSize", self.nNodes)
        if "states" in kwargs:
            self.states = kwargs.get("states").copy()
        self.last_written = kwargs.get("last_written", 0)

    cpdef void construct(self, object graph, list agentStates):
        """
        Constructs adj matrix using structs

        intput:
            :nx.Graph or nx.DiGraph: graph
        """
        # check if graph has weights or states assigned and or nudges
        # note does not check all combinations
        # input validation / construct adj lists
        # defaults
        DEFAULTWEIGHT = 1.
        DEFAULTNUDGE  = 0.
        # DEFAULTSTATE  = random # don't use; just for clarity
        # enforce strings
        version =  getattr(graph, '__version__', __VERSION__)


        # relabel all nodes as strings in order to prevent networkx relabelling
        graph = nx.relabel_nodes(graph, {node : str(node) for node in graph.nodes()})
        graph.__version__ = version
        # forward declaration
        cdef:
            dict mapping = {} # made nodelabel to internal
            dict rmapping= {} # reverse
            # str delim = '\t'
            NODE[::1] states = np.zeros(graph.number_of_nodes(), dtype = long)
            NODEID counter = 0
            NODEID source, target
            # double[::1] nudges = np.zeros(graph.number_of_nodes(), dtype = float)
            unordered_map[NODEID, NUDGE] nudges 
            # np.ndarray nudges = np.zeros(graph.number_of_nodes(), dtype = float)
            unordered_map[NODEID, Connection] adj # see .pxd



        # generate graph in json format
        nodelink = nx.node_link_data(graph)
        for nodeidx, node in enumerate(nodelink.get('nodes')):
            id                = node.get('id')
            mapping[id]       = nodeidx
            rmapping[nodeidx] = id
            states[nodeidx]   = <NODE>   node.get('state', np.random.choice(agentStates))
            nudges[nodeidx]   = <NUDGE> node.get('nudge', DEFAULTNUDGE)
        directed  = nodelink.get('directed')
        for link in nodelink['links']:
            source = mapping[link.get('source')]
            target = mapping[link.get('target')]
            weight = <WEIGHT> link.get('weight', DEFAULTWEIGHT)
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
        # public and python accessible
        self.graph       = graph
        self.mapping     = mapping
        self.rmapping    = rmapping
        self._adj        = adj

        self._agentStates = np.asarray(agentStates, dtype = long).copy()

        self._nudges     = nudges #nudges.copy()
        self._nStates    = len(agentStates)
        self._zeta = 0 

        #private
        # note nodeids will be shuffled and cannot be trusted for mapping
        # use mapping to get the correct state for the nodes

        _nodeids        = np.arange(graph.number_of_nodes(), dtype = long)
        np.random.shuffle(_nodeids) # prevent initial scan-lines in grid
        self._nodeids   = _nodeids
        self._states    = states
        self._states_ptr = &self._states[0]
        # self._newstates = states.copy()
        self._nNodes    = graph.number_of_nodes()

    cdef NODE[::1]  _updateState(self, NODEID[::1] nodesToUpdate) nogil:
        cdef:
            long node
            long idx
            long N =  nodesToUpdate.shape[0]
            long numNeighbors
            long backup
            long update = 0
            unordered_map[NODEID, NUDGE].iterator _nudge

        # init loop
        for node in range(N):
            node = nodesToUpdate[node]

            # update
            _nudge = self._nudges.find(node)
            update = 0
            if _nudge != self._nudges.end():
                if self._rand() < fabs( deref(_nudge).second):
                    # positive nudge is switch
                    if deref(_nudge).second > 0 and self._adj[node].neighbors.size():
                        # set update
                        update = 1
                        numNeighbors = self._adj[node].neighbors.size() 
                        # get neighbor to swap state
                        idx = <long> (self._rand() * numNeighbors)
                        idx = self._adj[node].neighbors[idx]
                        backup = self._states_ptr[idx]
                        # uniform sample from possible states
                        self._states_ptr[idx] = self._agentStates[ <long> (self._rand() * self._nStates)]
            self._step(node)
            if update == 1:
                self._states_ptr[idx] = backup
        # swap pointers
        self._swap_buffers()
        self._last_written = (self._last_written + 1) % 2
        #return self._states
        if self._last_written == 0:
            return self._states
        else:
            return self._newstates

    cdef void _swap_buffers(self) nogil:
        """
        Update state buffers
        This function is intended to allow for custom buffers update
        """
        swap(self._states_ptr, self._newstates_ptr)
        return

    cpdef NODE[::1] updateState(self, NODEID[::1] nodesToUpdate):
        """
        General state updater wrapper
        I
        """
        return self._updateState(nodesToUpdate)

    cdef void _step(self, NODEID node) nogil:
        return

    cdef double _rand(self) nogil:
        return self._dist(self._gen)

    cpdef NODEID[:, ::1] sampleNodes(self, long nSamples):
        return self._sampleNodes(nSamples)

    cdef NODEID[:, ::1] _sampleNodes(self, long  nSamples) nogil:
        # cdef long [:, ::1] sampleNodes(self, long  nSamples):
        """
        Shuffles nodeids only when the current sample is larger
        than the shuffled array
        N.B. nodeids are mutable
        """
        # check the amount of samples to get
        cdef:
            long sampleSize = self._sampleSize
            # TODO replace this with a nogil version
            # long _samples[nSamples][sampleSize]
            # long sample
            long start
            long i, j, k
            long samplei

        # if serial move through space like CRT line-scan method
        cdef NODEID[:, ::1] samples
        if self._updateType == 'serial':
            for i in range(self._nNodes):
                samples[i] = self._nodeids[i]
            return samples

        # replace with nogil variant
        with gil:
            samples = np.zeros((nSamples, sampleSize), dtype = long)
        for samplei in range(nSamples):
            # shuffle if the current tracker is larger than the array
            start  = (samplei * sampleSize) % self._nNodes
            if start + sampleSize >= self._nNodes or sampleSize == 1:
                for i in range(self._nNodes):
                    # shuffle the array without replacement
                    j                 = <long> (self._rand() * self._nNodes)
                    swap(self._nodeids[i], self._nodeids[j])
                    # enforce atleast one shuffle in single updates; otherwise same picked
                    if sampleSize == 1:
                        break
            # assign the samples; will be sorted in case of serial
            for j in range(sampleSize):
                samples[samplei][j]    = self._nodeids[j]
        return samples
        
    cpdef void reset(self):
        self.states = np.random.choice(\
                self.agentStates, size = self._nNodes)


    def removeAllNudges(self):
        """
        Sets all nudges to zero
        """
        self._nudges.clear()

    cpdef np.ndarray simulate(self, int  samples):
        cdef:
            NODE[:, ::1] results = np.zeros((samples, self._nNodes), long)
            # int sampleSize = 1 if self._updateType == 'single' else self._nNodes
            NODEID[:, ::1] r = self.sampleNodes(samples)
            # vector[vector[int][sampleSize]] r = self.sampleNodes(samples)
            int i

        results[0] = self._states
        with nogil:
            for i in range(samples):
                results[i] = self._updateState(r[i])
        return results.base # convert back to normal array

    # TODO: make class pickable
    # hence the wrappers
    @property
    def memorySize(self): return self._memorySize

    @memorySize.setter
    def memorySize(self, value):
        if isinstance(value, int):
            self._memorySize = value
        else:
            self._memorysize = 0

    cdef void _hebbianUpdate(self):
        """
        Hebbian learning rule that will strengthen similar
        connections and weaken dissimilar connections

        """

        # TODO: add learning rate delta
        # TODO: use hamiltonian function -> how to make general
        cdef:
            int nodeI, nodeJ
            int neighbors, neighbor
            int stateI, stateJ
            double weightI, weightJ # weights
            double Z # normalization constant
            double tmp

            vector[double] hebbianWeights
        # get neighbors
        for nodeI in range(self._nNodes):
            # update connectivity weight
            stateI = self._states_ptr[nodeI]
            neighbors = self._adj[nodeI].neighbors.size()
            # init values
            Z = 0
            hebbianWeights = range(neighbors) 
            # construct weight vector
            for nodeJ in range(neighbors):
                neighbor = self._adj[nodeI].neighbors[nodeJ]
                stateJ = self._states_ptr[neighbor]
                weightJ = self._adj[nodeI].weights[nodeJ]
                tmp = 1 + .1 * weightJ * self._learningFunction(stateI, stateJ)
                hebbianWeights[nodeJ] =  tmp

                Z = Z + tmp

            # update the weights
            for nodeJ in range(neighbors):
                self._adj[nodeI].weights[nodeJ] = hebbianWeights[nodeJ] / Z
        return 

    cdef double _learningFunction(self, NODEID xi, NODEID xj):
        """
        From Ito & Kaneko 2002
        """
        return 1 - 2 * (xi - xj)

    @property
    def last_written(self):
        return self._last_written

    @last_written.setter
    def last_written(self, value):
        self._last_written = value

    @property
    def memory(self): return self._memory.base

    @memory.setter
    def memory(self, value):
        if isinstance(value, np.ndarray):
            self._memory = value
    @property
    def sampleSize(self): return self._sampleSize

    @property
    def agentStates(self): return list(self._agentStates) # warning has no setter!

    @property
    def adj(self)       : return self._adj

    @property
    def states(self)    : return self._states.base
    
    @property
    def updateType(self): return self._updateType

    @property
    def nudgeType(self) : return self._nudgeType

    @property
    def nodeids(self)   : return self._nodeids.base

    @property
    def nudges(self)    : return self._nudges

    @property
    def nNodes(self)    : return self._nNodes

    @property
    def nStates(self)   : return self._nStates

    @property
    def seed(self)      : return self._seed

    @property
    def sampleSize(self): return self._sampleSize

    @property
    def newstates(self) : return self._newstates.base

    @seed.setter
    def seed(self, value):
        if isinstance(value, int) and value >= 0:
            self._seed = value
        else:
            raise ValueError("Not an uint found")
        self._gen   = mt19937(self.seed)
    # TODO: reset all after new?
    @nudges.setter
    def nudges(self, vals):
        """
        Set nudge value based on dict using the node labels
        """
        self._nudges.clear()
        # nudges are copied
        # rebuild should account for this
        if isinstance(vals, dict):
            for k, v in vals.items():
                if k in self.mapping:
                    idx = self.mapping[k]
                    self._nudges[idx] = v
                elif k in self.rmapping:
                    self._nudges[k] = v
        else:
            raise TypeError("Nudge input not a dict!")
                    
    @updateType.setter
    def updateType(self, value):
        """
        Input validation of the update of the model
        Options:
            - sync  : synchronous; update independently from t > t + 1
            - async : asynchronous; update n Nodes but with mutation possible
            - single: update 1 node random
            - [float]: async but only x percentage of the total system
        """
        # TODO: do a better switch than this
        # not needed anymore since single is not a sampler kv
        import re
        # allowed patterns
        pattern = "(sync)?(async)?"
        if re.match(pattern, value):
            self._updateType = value
        else:
            raise ValueError("No possible setting found")
        # allow for mutation if async else independent updates
        if value == "async":
            # set pointers to the same thing
            self._newstates_ptr = self._states_ptr
            # assign  buffers to the same address
            self._newstates = self._states
            # sanity check
            assert self._states_ptr == self._newstates_ptr
            assert id(self._states.base) == id(self._newstates.base)
        # reset buffer pointers
        elif value == "sync":
            # obtain a new memory address
            self._newstates = self._states.base.copy()
            assert id(self._newstates.base) != id(self._states.base)
            # sanity check pointers (maybe swapped!)
            self._states_ptr   = &self._states[0]
            self._newstates_ptr = &self._newstates[0]
            # test memory addresses
            assert self._states_ptr != self._newstates_ptr
            assert id(self._newstates.base) != id(self._states.base)
        self.last_written = 0

    @sampleSize.setter
    def sampleSize(self, value):
        """
        Sample size setter for sample nodes
        """
        if isinstance(value, int):
            assert 0 < value <= self.nNodes, f"value {value} {self.nNodes}"
            self._sampleSize = value
        elif isinstance(value, float):
            assert 0 < value <= 1
            self._sampleSize = <long> (value * self._nNodes)
        # default

    @nudgeType.setter
    def nudgeType(self, value):
        DEFAULT = "constant"
        if value in "constant pulse":
            self._nudgeType = value
        else:
            raise ValueError("Setting not understood")

    @states.setter # TODO: expand
    def states(self, value):
        from collections import Iterable
        cdef int idx
        if isinstance(value, int):
            for node in range(self._nNodes):
                self._states_ptr[node] = value
        elif isinstance(value, dict):
            for k, v in value.items():
                idx = self.mapping[k]
                self._states_ptr[idx] = v
        # assume iterable
        else:
            for i in range(self._nNodes):
                self._states_ptr[i] = value[i]
                self._newstates_ptr[i] = value[i]


    def __reduce__(self):
        kwargs = {}
        for k in dir(self):
            atr = getattr(self, k)
            if not callable(atr) and not k.startswith('_'):
                kwargs[k] = atr

        tmp = {}
        for k, v in self.nudges.items():
            tmp[self.rmapping[k]] = v
        #for k in kwargs: print(k)
        return rebuild, (self.__class__, kwargs)
        #return rebuild, (self.__class__, kwargs)

    def __deepcopy__(self, memo):
        tmp = {i : getattr(self, i) for i in dir(self)}
        return self.__class__(**tmp)

def rebuild(cls, kwargs):
    return cls(**kwargs)

cdef class Potts(Model):
    def __init__(self, \
                 graph,\
                 t = 1,\
                 agentStates = [0, 1],\
                 delta       = 0, \
                 **kwargs):
        """
        Potts model

        default inputs see :Model:
        Additional inputs
        :delta: a modifier for how much the previous memory sizes influence the next state
        """
        #print(kwargs, locals())
        super(Potts, self).__init__(\
                                    graph = graph,\
                                    agentStates = agentStates,\
                                    **kwargs)

        self._H = kwargs.get("H", np.zeros(self._nNodes, dtype = float))
        self.t       = t
        self._delta  = delta

    @property
    def delta(self): return self._delta

    @property
    def H(self): return self._H.base

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



    cpdef vector[double] siteEnergy(self, NODE[::1] states):
        cdef:
            vector[double] siteEnergy = vector[double](self._nNodes)
            int node
            double Z, energy

            long* ptr = self._states_ptr
        # reset pointer to current state
        self._states_ptr = &states[0]
        for node in range(self._nNodes):
            Z = <double> self._adj[node].neighbors.size()
            energy = - self._energy(node)[0] / Z # just average
            siteEnergy[node] = energy
        # reset pointer to original buffer
        self._states_ptr = ptr
        return siteEnergy


    cdef vector[double] _energy(self, NODEID node) nogil:
        cdef:
            long neighbors = self._adj[node].neighbors.size()
            long* states = self._states_ptr # alias
            long neighbor, neighboridx
            double weight # TODO: remove delta
            vector[double] energy = vector[double](3)
            long  testState
        # fill buffer
        # keep track of:
        #   - energy of current state
        #   - energy of possible state
        #   - the possible state
        # count the neighbors in the different possible states

        # draw random new state
        testState = <long> (self._rand() * (self._nStates ))
        # get proposal 
        testState = self._agentStates[testState]

        energy[0] = self._H[node]
        energy[1] = self._H[node]
        energy[2] = <double> testState # keep track of possible new state

        # maybe check all states? now just random, in the limit this would
        # result in an awful fit
        for neighboridx in range(neighbors):
            neighbor   = self._adj[node].neighbors[neighboridx]
            weight     = self._adj[node].weights[neighboridx]
            energy[0]  -= weight * self._hamiltonian(states[node], states[neighbor])
            energy[1]  -= weight * self._hamiltonian(testState, states[neighbor])
        # retrieve memory
        cdef int memTime
        #for memTime in range(self._memorySize):
        #    # check for current state
        #    energy[0] -= self._hamiltonian(states[node], self._memory[memTime, node]) * exp(-memTime * self._delta)
        #    energy[1] -= self._hamiltonian(testState, self._memory[memTime, node]) * exp(-memTime * self._delta)
        # with gil: print(energy)
        return energy

    cdef double _hamiltonian(self, NODE x, NODE  y) nogil:
        # sanity checking
        return cos(2 * pi  * ( x - y ) / <double> self._nStates)

    cdef void _step(self, long node) nogil:
        cdef:
            vector[double] probs
            double p

        probs = self._energy(node)
        p = exp(- self._beta *( probs[1] - probs[0]))
        # edge case isnan when H = 0 or T = 0 and inf
        if self._rand() < p or isnan(p):
            self._newstates_ptr[node] = <long> probs[2]
        else:
            self._newstates_ptr[node] = self._states_ptr[node]

    cpdef  np.ndarray matchMagnetization(self,\
                              np.ndarray temps  = np.logspace(-3, 2, 20),\
                              int n             = int(1e3),\
                              int burninSamples = 0,\
                              double match = -1):
            """
            Computes the magnetization as a function of temperatures
            Input:
                  :temps: a range of temperatures
                  :n:     number of samples to simulate for
                  :burninSamples: number of samples to throw away before sampling
            Returns:
                  :temps: the temperature range as input
                  :sus:  the magnetic susceptibility
            """
            cdef:
                double tcopy   = self.t # store current temp
                np.ndarray results = np.zeros((2, temps.shape[0]))
                np.ndarray res, resi
                int N = len(temps)
                int i, j
                double t, avg, sus
                int threads = mp.cpu_count()
                vector[PyObjectHolder] tmpHolder
                Potts tmp
                np.ndarray magres
                list modelsPy = []


            print("Computing mag per t")
            #pbar = tqdm(total = N)
            pbar = ProgBar(N)
            # for i in prange(N, nogil = True, num_threads = threads, \
                            # schedule = 'static'):
                # with gil:
            cdef PyObject *tmptr
            cdef int tid
            for i in range(threads):
                tmp = copy.deepcopy(self)
                # tmp.reset()
                # tmp.burnin(burninSamples)
                # tmp.seed += sample # enforce different seeds
                modelsPy.append(tmp)
                tmpHolder.push_back(PyObjectHolder(<PyObject *> tmp))


            for i in prange(N, nogil = True, schedule = 'static',\
                            num_threads = threads):
                # m = copy.deepcopy(self)
                tid = threadid()
                tmptr = tmpHolder[tid].ptr
                avg = 0
                sus = 0
                with gil:
                    t                  = temps[i]
                    (<Potts> tmptr).t  = t
                    (<Potts> tmptr).states = self._agentStates[0]
                    res        = (<Potts> tmptr).simulate(n)
                    # mu = np.array([self.siteEnergy(resi) for resi in res])
                    results[0, i] = (res == self._agentStates[0]).mean() - 1/self._nStates
                    pbar.update(1)
            results[1, :] = np.abs(np.gradient(results[0], temps, edge_order = 1))
            if match > 0:
                # fit sigmoid
                from scipy import optimize
                params, cov = optimize.curve_fit(sigmoid, temps, results[0], maxfev = 10_000)
                # optimize
                # setting matched temperature
                critic = optimize.fmin(sigmoidOpt, \
                                       x0 = 0,\
                                       args = (params, match ),\
                                       )
                tcopy = critic
                print(f"Sigmoid fit params {params}\nAt T={critic}")
            # print(results[0])
            self.t = tcopy # reset temp
            return results
    cpdef NODE[::1] updateState(self, NODEID[::1] nodesToUpdate):
        return self._updateState(nodesToUpdate)


cdef class Ising(Potts):
    def __init__(self, graph,\
                 **kwargs):
        # default override
        agentStates = [-1, 1]
        if "agentStates" in kwargs:
            del kwargs["agentStates"]
        super(Ising, self).__init__(\
                                    graph = graph,\
                                    agentStates = agentStates,\
                                    **kwargs)

    cdef double _hamiltonian(self, NODE x , NODE y) nogil:
        return <double> (x * y)
# associated with potts for matching magnetic
@cython.binding(True)
def sigmoid(x, a, b, c, d):
    return  a / (1 + np.exp(b * x - c)) + d
@cython.binding(True)
def sigmoidOpt(x, params, match):
    return np.abs( sigmoid(x, *params) - match )

# TODO: system coupling is updated instantaneously which is in contradiction with the sync update rule
cdef class Bornholdt(Ising):
    def __init__(self,\
                 graph, \
                 double alpha = 1,\
                 **kwargs):
        """
        Implementation of Bornholdt model (2000)
        Ising-like dynamics with a global magnetiztion dynamic
        """
        self.alpha = alpha
        super(Bornholdt, self).__init__(graph = graph, **kwargs)

        self.system_mag     = np.mean(self.states)

    @property
    def system_mag(self):
        return self._system_mag
    @system_mag.setter
    def system_mag(self, value):
        self._system_mag = value
        self._newsystem_mag = value
        if self.updateType == "sync":
            self._system_mag_ptr    = &(self._system_mag)
            self._newsystem_mag_ptr = &(self._newsystem_mag)
        elif self.updateType == "async":
            self._system_mag_ptr    = &self._system_mag
            self._newsystem_mag_ptr = self._system_mag_ptr
        else:
            raise ValueError("Input not recognized")
    @property
    def alpha(self): return self._alpha
    @alpha.setter
    def alpha(self, value):
        """Global coupling"""
        #TODO: add checks?
        self._alpha = <double> value

    cdef void _step(self, NODEID node) nogil:
        cdef:
            vector[double] probs
            double p
            double systemInfluence = self._alpha * fabs(deref(self._system_mag_ptr))

        probs = self._energy(node)
        p = exp(- 2 * self._beta * ( probs[1] - systemInfluence))
        if self._rand() < p:
            self._newstates_ptr[node] = <long> probs[2]
            self._newsystem_mag_ptr[0]  += 2 * (probs[2] / <double> self._nNodes)
        else:
            self._newstates_ptr[node] = self._states_ptr[node]

    cdef void _swap_buffers(self) nogil:
         swap(self._states_ptr, self._newstates_ptr)
         swap(self._system_mag_ptr, self._newsystem_mag_ptr)
         return



cdef class SIRS(Model):
    def __init__(self, graph, \
                 agentStates = [0, 1, 2],\
                 beta = 1,\
                 mu = 1,\
                 nu = 0,\
                 kappa = 0,\
                 **kwargs):
        super(SIRS, self).__init__(**locals())
        self.beta  = beta
        self.mu    = mu
        self.nu    = nu
        self.kappa = kappa
        self.init_random()

        """
        SIR model inspired by Youssef & Scolio (2011)
        The article describes an individual approach to SIR modelling which canonically uses a mean-field approximation.
        In mean-field approximatinos nodes are assumed to have 'homogeneous mixing', i.e. a node is able to receive information
        from the entire network. The individual approach emphasizes the importance of local connectivity motifs in
        spreading dynamics of any process.


        The dynamics are as follows

        S ----> I ----> R
          beta     mu
               The update deself.mapping.find(k) != tmp.end()pends on the state a individual is in.

        S_i: beta A_{i}.dot(states[A[i]])  beta         |  infected neighbors / total neighbors
        I_i: \mu                                        | prop of just getting cured

        TODO: no spontaneous infections possible
        (my addition)
        S ----> I ----> R ----> S
          beta     mu     kappa
                I ----> S
                   nu


        Todo: the sir model currently describes a final end-state. We can model it that we just assume distributions
        """
    @property
    def beta(self):
        return self._beta

    @beta.setter
    def beta(self, value):
        assert 0 <= value <= 1, "beta \in (0,1)?"
        self._beta = value

    @property
    def mu(self):
        return self._mu
    @mu.setter
    def mu(self, value):
        assert 0 <= value <= 1, "mu \in (0,1)?"
        self._mu = value
    @property
    def nu(self):
        return self._nu
    @nu.setter
    def nu(self, value):
        assert 0 <= value <= 1
        self._nu = value
    @property
    def kappa(self):
        return self._kappa
    @kappa.setter
    def kappa(self, value):
        assert 0<=value<= 1
        self._kappa = value

    cdef float _checkNeighbors(self, NODEID node) nogil:
        """
        Check neighbors for infection
        """
        cdef:
            long neighbor, idx
            float neighborWeight
            float infectionRate = 0
            long Z = self._adj[node].neighbors.size()
            float ZZ = 1
        for idx in range(Z):
            neighbor = self._adj[node].neighbors[idx]
            neighborWeight = self._adj[node].weights[idx]
            # sick
            if self._states[neighbor] == 1:
                infectionRate += neighborWeight * self._states_ptr[neighbor]
            # NOTE: abs weights?
            ZZ += neighborWeight
        return infectionRate * self._beta / ZZ

    cdef void _step(self, NODEID node) nogil:

        cdef:
            float rng = self._rand()
        # HEALTHY state 
        if self._states_ptr[node] == 0:
            # infect
            if rng  < self._checkNeighbors(node):
                self._newstates_ptr[node] = 1
        # SICK state
        elif self._states_ptr[node] == 1:
            if rng < self._mu:
                self._newstates_ptr[node] = 2
            elif rng < self._nu:
                self._newstates_ptr[node] = 0
        # SIRS motive
        elif self._states_ptr[node] == 2:
            if rng < self._kappa:
                self._newstates_ptr[node] = 0
        # add SIRS dynamic?
        return

    cpdef void init_random(self, node = None):
       self.states = 0
       if node:
           idx = self.mapping[node]
       else:
           idx = <long> (self._rand() * self._nNodes)
       self._states[idx] = 1

cdef class RBN(Model):
    def __init__(self, graph, rule = None, \
                 updateType = "sync",\
                 **kwargs):

        agentStates = [0, 1]

        super(RBN, self).__init__(**locals())
        # self.states = np.asarray(self.states.base.copy())

        # init rules
        # draw random boolean function
        for node in range(self.nNodes):
            k = self._adj[node].neighbors.size()
            #rule = np.random.randint(0, 2**k, dtype = long)
            #rule = format(_rule, f"0{k}b")[::-1]
            rule = np.random.randint(0, 2**(2 ** k), dtype = int)
            rule = format(rule, f'0{2 ** k}b')[::-1]
            self._rules[node] = [int(i) for i in rule]

    @property
    def rules(self):
        return self._rules

    cdef void _step(self, long node) nogil:
       """
       Update step for Random Boolean networks
       Count all the 1s from the neighbors and index into fixed rule
       """
       cdef:
           long counter = 0
           long neighbor
           long N = self._adj[node].neighbors.size()
        # get neighbors
       for neighbor in range(N):
          # count if 1
          if self._states_ptr[self._states_ptr[neighbor]]:
              counter += 2 ** neighbor
        #update
       self._newstates_ptr[node] = self._rules[node][counter]
       return


cdef class Percolation(Model):
    def __init__(self, graph, p = 1, agentStates = [0, 1], \
                **kwargs):
        super(Percolation, self).__init__(**locals())
        self.p = p

    @property
    def p(self):
        return self._p
    
    @p.setter
    def p(self, value):
        self._p = value

    cdef void _step(self, NODEID node) nogil:
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

cdef class CCA(Model):
    def __init__(self, \
                 graph,\
                 threshold = 0.,\
                 agentStates = [0, 1, 2],\
                 **kwargs):
        """
        Circular cellular automaton
        """

        super(CCA, self).__init__(**locals())

        self.threshold = threshold

    # threshold for neighborhood decision
    @property
    def threshold(self):
        return self._threshold
    @threshold.setter
    def threshold(self, value):
        assert 0 <= value <= 1.
        self._threshold = value

    cdef void _evolve(self, NODEID node) nogil:
        """
        Rule : evolve if the state of the neigbhors exceed a threshold
        """

        cdef:
            long neighbor
            long nNeighbors = self._adj[node].neighbors.size()
            int i
            double fraction = 0
            long* states = self._states_ptr
        # check neighbors and see if they exceed threshold
        for neighbor in range(nNeighbors):
            neighbor = self._adj[node].neighbors[neighbor]
            if (states[neighbor] == (states[node] + 1) % self._nStates):
                fraction += 1 
        # consume cell
        if (fraction / <double> nNeighbors >= self._threshold):
            self._newstates_ptr[node] = ((states[node] + 1) % self._nStates)
        # remain unchanged
        else:
            if self._rand() <= self._threshold:
                i = <long> (self._rand() * self._nStates)
                self._newstates_ptr[node] = self._agentStates[i]
        return 
    cdef void _step(self, NODEID node) nogil:
        self._evolve(node)
        return


#def rebuild(graph, states, nudges, updateType):
#    cdef RBN tmp = RBN(graph, updateType = updateType)
#    tmp.states = states.copy()
#    tmp.nudges = nudges.copy()
#    return tmp


