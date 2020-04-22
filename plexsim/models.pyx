# distutils: language=c++
# __author__ = 'Casper van Elteren'
cimport cython

import numpy as np
cimport numpy as np
import networkx as nx, functools, time
from tqdm import tqdm
import copy

cimport cython, openmp
from cython.parallel cimport parallel, prange, threadid
from cython.operator cimport dereference as deref, preincrement, postincrement as post
from libc.stdlib cimport malloc, free
from libc.string cimport strcmp
from libc.stdio cimport printf
from libcpp.vector cimport vector
from libcpp.pair cimport pair
from libcpp.map cimport map
from libcpp.unordered_map cimport unordered_map


from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from libc.math cimport exp, log, cos, pi, lround, fabs, isnan

from pyprind import ProgBar
import multiprocessing as mp

cdef extern from "<algorithm>" namespace "std" nogil:
    void swap[T] (T &a, T &b)


cdef extern from "math.h":
    float INFINITY
# SEED SETUP
from posix.time cimport clock_gettime,\
timespec, CLOCK_REALTIME

# from sampler cimport Sampler # mersenne sampler


cdef class Model:
    def __init__(self,\
                 graph       = nx.path_graph(1),\
                 agentStates = [0],\
                 nudgeType   = "constant",\
                 updateType  = "async",\
                 nudges      = {},\
                 seed        = None,\
                 memorySize  = 0,\
                 kNudges     = 1,\
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

        optionalo
                    
            :agentStates: the states that the agents can assume [default = [0,1]]
            :updateType: how to sample the state space (default async)
            :nudgeType: the type of nudge used (default: constant)
            :memorySize: use memory dynamics (default 0)
       """
        # use current time as seed for rng
        cdef timespec ts
        if seed is None:
            clock_gettime(CLOCK_REALTIME, &ts)
            _seed = ts.tv_sec
        elif seed >= 0 and isinstance(seed, int):
            _seed = seed
        else:
            raise  ValueError("seed needs uint")
        # define rng sampler
        self._dist = uniform_real_distribution[double](0.0, 1.0)
        self.seed = _seed
        self._gen  = mt19937(self.seed)

        self.kNudges = kNudges

        # create adj list
        if graph:
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
        cdef double DEFAULTWEIGHT = 1.
        cdef double DEFAULTNUDGE  = 0.
        # DEFAULTSTATE  = random # don't use; just for clarity
        # enforce strings


        # relabel all nodes as strings in order to prevent networkx relabelling
        graph = nx.relabel_nodes(graph, {node : str(node) for node in graph.nodes()})
        # forward declaration
        cdef:
            dict mapping = {}
            dict rmapping= {}

            node_state_t[::1] states = np.zeros(graph.number_of_nodes(), dtype = long)

            node_id_t source, target

            # define nudges
            Nudges nudges

            # define adjecency
            Connections adj  #= Connections(graph.number_of_nodes(), Connection())# see .pxd

            weight_t weight

            # generate graph in json format
            dict nodelink = nx.node_link_data(graph)
            str nodeid
            int nodeidx

        for nodeidx, node in enumerate(nodelink.get("nodes")):
            nodeid            = node.get('id')
            mapping[nodeid]   = nodeidx
            rmapping[nodeidx] = nodeid
            states[nodeidx]   = <node_state_t> node.get("state", np.random.choice(agentStates))
            nudges[nodeidx]   = <nudge_t> node.get("nudge", DEFAULTNUDGE)
        # go through edges
        cdef bint directed  = nodelink.get('directed')
        cdef dict link
        for link in nodelink['links']:
            source = mapping[link.get('source')]
            target = mapping[link.get('target')]
            weight = <weight_t> link.get('weight', DEFAULTWEIGHT)
            # reverse direction for inputs
            if directed:
                # get link as input
                adj[target].neighbors[source] = weight
            else:
                # add neighbors
                adj[source].neighbors[target] = weight
                adj[target].neighbors[source] = weight
        # public and python accessible
        self.graph       = graph
        self.mapping     = mapping
        self.rmapping    = rmapping
        self._adj        = adj

        self._agentStates = np.asarray(agentStates, dtype = long).copy()

        self._nudges     = nudges
        self._nStates    = len(agentStates)
        self._zeta = 0

        # Private
        _nodeids        = np.arange(graph.number_of_nodes(), dtype = long)
        np.random.shuffle(_nodeids) # prevent initial scan-lines in grid
        self._nodeids   = _nodeids
        self._states    = states
        self._states_ptr = &self._states[0]
        self._nNodes    = graph.number_of_nodes()

    cdef node_state_t[::1]  _updateState(self, node_id_t[::1] nodesToUpdate) nogil:
        cdef NudgesBackup* backup = new NudgesBackup()
        #cdef NudgesBackup backup = NudgesBackup()
        cdef node_id_t node
        # updating nodes
        for node in range(nodesToUpdate.shape[0]):
            node = nodesToUpdate[node]
            self._apply_nudge(node, backup)
            self._step(node)
            self._remove_nudge(node, backup)
        # clean up
        else:
            free(backup)
            self._swap_buffers()
            self._last_written = (self._last_written + 1) % 2 

        # return buffers
        if self._last_written == 0:
            return self._states
        else:
            return self._newstates
    cdef void _apply_nudge(self, node_id_t node,\
                           NudgesBackup* backup) nogil:

        # check if it has neighbors
        if self._adj[node].neighbors.size() == 0:
            return
        # TODO: check struct inits; I think there is no copying done here
        cdef node_id_t idx
        cdef node_state_t state
        cdef NodeBackup tmp
        cdef weight_t weight
        cdef int jdx = 0
        # check if there is a nudge
        nudge = self._nudges.find(node)
        it = self._adj[node].neighbors.begin()
        if nudge != self._nudges.end():
            # start nudge
            if self._rand() < deref(nudge).second:
                # random sampling
                idx = <node_id_t> (self._rand() * self._adj[node].neighbors.size())
                # obtain bucket
                it = self._adj[node].neighbors.begin()
                while it != self._adj[node].neighbors.end():
                    if jdx == idx:
                        idx = deref(it).first
                        break
                    jdx +=1 
                    post(it)
                # obtain state
                state = self._states_ptr[idx]
                weight = self._adj[node].neighbors[idx]
                # store backup
                tmp.state  = state
                tmp.weight = weight
                deref(backup)[idx] = tmp 

                # adjust weight
                self._adj[node].neighbors[idx] *= self._kNudges
                # sample uniformly
                self._states_ptr[node] = self._agentStates[<int> self._rand() * self._nStates]
        return

    cdef void _remove_nudge(self, node_id_t node,\
                            NudgesBackup* backup) nogil:
        """
        Clear nudges and restore the states
        """
        cdef:
            node_id_t neighbor
            NodeBackup state
        it = deref(backup).begin()
        while it != deref(backup).end():
            neighbor  = deref(it).first
            self._states_ptr[neighbor] = deref(it).second.state
            self._adj[node].neighbors[neighbor] = deref(it).second.weight
            post(it)
        deref(backup).clear()
        return

    cdef void _swap_buffers(self) nogil:
        """
        Update state buffers
        This function is intended to allow for custom buffers update
        """
        swap(self._states_ptr, self._newstates_ptr)
        return

    cpdef node_state_t[::1] updateState(self, node_id_t[::1] nodesToUpdate):
        """
        General state updater wrapper
        I
        """
        return self._updateState(nodesToUpdate)

    cdef void _step(self, node_id_t node) nogil:
        return

    cdef double _rand(self) nogil:
        return self._dist(self._gen)

    cpdef node_id_t[:, ::1] sampleNodes(self, long nSamples):
        return self._sampleNodes(nSamples)

    cdef node_id_t[:, ::1] _sampleNodes(self, long  nSamples) nogil:
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
        cdef node_id_t[:, ::1] samples

        # replace with nogil variant
        with gil:
            samples = np.zeros((nSamples, sampleSize), dtype = long)
        # cdef vector[vector[node_id_t]] samples = vector[vector[node_id_t]](nSamples)
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
        
    cpdef void reset(self, p = None):
        if p is None:
            p = np.ones(self.nStates) / self.nStates
        self.states = np.random.choice(\
                                       self.agentStates, p = p, size = self._nNodes)


    def removeAllNudges(self):
        """
        Sets all nudges to zero
        """
        self._nudges.clear()

    cpdef np.ndarray simulate(self, int  samples):
        cdef:
            node_state_t[:, ::1] results = np.zeros((samples, self._nNodes), long)
            # int sampleSize = 1 if self._updateType == 'single' else self._nNodes
            node_id_t[:, ::1] r = self.sampleNodes(samples)
            # vector[vector[int][sampleSize]] r = self.sampleNodes(samples)
            int i

        if self.last_written:
            results[0] = self._states
        else:
            results[0] = self._newstates
        for i in range(1, samples):
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
        
        return 

    cdef double _learningFunction(self, node_id_t xi, node_id_t xj):
        """
        From Ito & Kaneko 2002
        """
        return 1 - 2 * (xi - xj)

    @property
    def kNudges(self):
        return self._kNudges
    @kNudges.setter
    def kNudges(self, value):
        self._kNudges = value
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
    def states(self)    :
        if self.last_written:
            return self._newstates.base
        else:
            return self._states.base
    
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
    def newstates(self) :
        if self.last_written:
            return self._newstates.base
        else:
            return self._states.base


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


                #TODO: edit or remove this
    def get_settings(self):
        kwargs = {}
        for k in dir(self):
            atr = getattr(self, k)
            if not callable(atr) and not k.startswith('_'):
                kwargs[k] = atr
        return kwargs

    def __reduce__(self):
        kwargs = self.get_settings()
        return rebuild, (self.__class__, self.get_settings())
        #return rebuild, (self.__class__, kwargs)

    def __deepcopy__(self, memo):
        return self.__class__(**self.get_settings())

    cdef SpawnVec _spawn(self, int nThreads = openmp.omp_get_num_threads()):
        """
        Spawn independent models
        """

        cdef:
            int tid
            SpawnVec spawn 
            Model m
        for tid in range(nThreads):
            # ref counter increase
            m =  self.__deepcopy__({})
            spawn.push_back( PyObjectHolder(\
                                        <PyObject*> m\
                                        )
                             )
        return spawn





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



    cpdef vector[double] siteEnergy(self, node_state_t[::1] states):
        cdef:
            vector[double] siteEnergy = vector[double](self._nNodes)
            int node
            double Z, energy
            long* ptr = self._states_ptr
        # reset pointer to current state
        self._states_ptr = &states[0]
        energy = 0
        for node in range(self._nNodes):
            Z = <double> self._adj[node].neighbors.size()
            energy = - self._energy(node)[0] / Z # just average
            siteEnergy[node] = energy
        # reset pointer to original buffer
        self._states_ptr = ptr
        return siteEnergy


    # cdef vector[double] _energy(self, node_id_t node) nogil:
    cdef double* _energy(self, node_id_t node) nogil:
        """
        """
        cdef:
            long neighbors = self._adj[node].neighbors.size()
            long* states = self._states_ptr # alias
            long neighbor, neighboridx
            double weight # TODO: remove delta
            # vector[double] energy = vector[double](3, self._H[node]) 
            double* energy = <double*> malloc(3 * sizeof(double)) 
            long  testState
        # draw random new state
        testState = <long> (self._rand() * (self._nStates ))

        energy[0] = self._H[node]
        energy[1] = self._H[node]

        energy[2] = self._agentStates[testState]
        # compute the energy
        it = self._adj[node].neighbors.begin()
        while it != self._adj[node].neighbors.end():
            weight   = deref(it).second
            neighbor = deref(it).first
                 # update energies
            energy[0]  -= weight * self._hamiltonian(states[node], states[neighbor])
            energy[1]  -= weight * self._hamiltonian(testState, states[neighbor])

            post(it)

        return energy

    cdef double _hamiltonian(self, node_state_t x, node_state_t  y) nogil:
        return cos(2 * pi  * ( x - y ) / <double> (self._nStates))

    cdef void _step(self, long node) nogil:
        cdef:
            # vector[double] energies = self._energy(node)
            double* energies = self._energy(node)
            double delta = self._beta * (energies[1] - energies[0])
            double p = exp(-delta)
            double rng = self._rand()
        if rng < p or isnan(p):
            self._newstates_ptr[node] = <node_state_t> energies[2]
        free(energies)
        return

    cpdef  np.ndarray magnetize(self,\
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
                int ni
                int threads = mp.cpu_count()
                np.ndarray magres
                list modelsPy = []

            # setup parallel models
            print("spawning threads")
            print("Magnetizing temperatures")
            cdef:
                int tid
                double Z = 1/ <double> self._nStates
                SpawnVec  tmpHolder = self._spawn(threads)
                PyObject* tmptr
            pbar = ProgBar(N)
            for ni in prange(N, nogil = 1,\
                             num_threads =  threads,\
                             schedule = 'static'):
            # for ni in range(N):
                tid = threadid()
                tmptr = tmpHolder[tid].ptr
                with gil:
                    (<Model> tmptr).t      =  temps[ni]
                    (<Model> tmptr).states = self._agentStates[0]
                    res = np.unique((<Model> tmptr).simulate(n).flat,\
                                    return_counts = True)[1]
                    xr = np.arange(0, res.size)
                    phase = np.exp(2 * np.pi * 1j * xr * Z)* \
                        res/ <double>(self._nNodes * n)
                    phase = np.real(phase).sum()
                    results[0, ni] = np.abs(phase)
                    pbar.update(1)
            results[1, :] = np.abs(np.gradient(results[0], temps, edge_order = 1))

            # fit sigmoid
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

            self.t = tcopy # reset temp
            return results



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

    cdef double _hamiltonian(self, node_state_t x , node_state_t y) nogil:
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

    cdef void _step(self, node_id_t node) nogil:
        cdef:
            # vector[double] probs
            double* energies
            double delta
            double p
            double systemInfluence = self._alpha * deref(self._system_mag_ptr)

        energies = self._energy(node)


        delta = energies[0] * self._states_ptr[node] - self._states_ptr[node] * systemInfluence
        p = 1 / ( 1. + exp( -2 * self._beta * delta))

        if self._rand() < p :
            self._newstates_ptr[node] = <long> energies[2]
            self._newsystem_mag_ptr[0] += 2 * (energies[2] / <double> self._nNodes)
        free(energies)
        return

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

    cdef float _checkNeighbors(self, node_id_t node) nogil:
        """
        Check neighbors for infection
        """
        cdef:
            long neighbor, idx
            float neighborWeight
            float infectionRate = 0
            float ZZ = 1
        it = self._adj[node].neighbors.begin()
        while it != self._adj[node].neighbors.end():
            neighbor = deref(it).first
            neighborWeight = deref(it).second
            post(it)
            # sick
            if self._states[neighbor] == 1:
                infectionRate += neighborWeight * self._states_ptr[neighbor]
            # NOTE: abs weights?
            ZZ += neighborWeight
        return infectionRate * self._beta / ZZ

    cdef void _step(self, node_id_t node) nogil:

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
        else:
            self._newstates_ptr[node] = self._states_ptr[node]
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
           long c = 0
           long counter = 0 
           long neighbor
           long N = self._adj[node].neighbors.size()
       it = self._adj[node].neighbors.begin()
       while it != self._adj[node].neighbors.end():
           if self._states_ptr[deref(it).first] == 1:
               counter += 2 ** c
           c += 1
           post(it)

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

    cdef void _step(self, node_id_t node) nogil:
        cdef:
            long neighbor
        if self._states_ptr[node]:
            it = self._adj[node].neighbors.begin()
            while it != self._adj[node].neighbors.end():
                if self._rand() < self._p:
                    neighbor = deref(it).first
                    self._newstates_ptr[neighbor] = 1
                post(it)
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

    cdef void _evolve(self, node_id_t node) nogil:
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
        it = self._adj[node].neighbors.begin()
        while it != self._adj[node].neighbors.end():
            neighbor = deref(it).first
            if (states[neighbor] == (states[node] + 1) % self._nStates):
                fraction += 1
            post(it)
        if (fraction / <double> nNeighbors >= self._threshold):
            self._newstates_ptr[node] = ((states[node] + 1 ) % self._nStates)
        else:
            if self._rand() <= self._threshold:
                i = <int> (self._rand() * self._nStates)
                self._newstates_ptr[node] = self._agentStates[i]
        return 
    cdef void _step(self, node_id_t node) nogil:
        self._evolve(node)
        return


#def rebuild(graph, states, nudges, updateType):
#    cdef RBN tmp = RBN(graph, updateType = updateType)
#    tmp.states = states.copy()
#    tmp.nudges = nudges.copy()
#    return tmp


