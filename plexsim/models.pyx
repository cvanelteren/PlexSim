# distutils: language=c++
## cython: profile = True
## cython: linetrace = True
## distutils: define_macros=CYTHON_TRACE_NOGIL=1
##  cython: np_pythran=True


# __author__ = 'Casper van Elteren'
cimport cython

import numpy as np
cimport numpy as np
import networkx as nx, functools, time
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
from libc.math cimport exp, log, cos, pi, lround, fabs, isnan, signbit

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

cdef class MCMC:
    def __init__(self, \
                 RandomGenerator rng,\
                 double p_recomb = 1,\
                 ):
        self.rng = rng
        self.p_recomb = p_recomb

    cdef void step(self, node_id_t[::1] nodeids,\
                   PyObject* ptr,\
                   ) nogil:

        
        cdef double rng = self.rng._rand()
        if rng < self._p_recomb:
        # if self.rng._rand() < self._p_recomb:
            self.recombination(nodeids, \
                               ptr
                               )
        else :
            self.gibbs(nodeids, ptr)
        return

    cdef void gibbs(self, \
                    node_id_t[::1] nodeids,\
                    PyObject* ptr,\
                    ) nogil:

        cdef double p, p_prop, p_cur
        cdef state_t currentState, proposalState
        for idx in range(len(nodeids)):
            currentState  = (<Model> ptr)._states[nodeids[idx]]
            proposalState = self._sample_proposal(ptr)

            p_prop = (<Model> ptr).probability(proposalState, nodeids[idx])

            p_cur  = (<Model> ptr).probability(currentState, nodeids[idx])
            p = p_prop / p_cur
            # p = p_prop / (p_prop + p_cur)
            if self.rng._rand() < p:
                (<Model> ptr)._newstates[nodeids[idx]] = proposalState
        return

    cdef state_t _sample_proposal(self, PyObject* ptr) nogil:
        return (<Model> ptr)._agentStates[ \
                <size_t> (self.rng._rand() * (<Model> ptr)._nStates ) ]

    cdef void recombination(self,\
                    node_id_t[::1] nodeids,\
                    PyObject* ptr,\
                    ) nogil:
        """
            Return shuffled state to generate a proposal
        """
        cdef size_t n = len(nodeids)

        cdef double den, nom
        # check all pairs of proposals
        cdef size_t jdx, idx
        cdef state_t state1, state2

        cdef state_t[::1] backup   = (<Model> ptr).__states
        cdef state_t[::1] modified = (<Model> ptr).__states
        with gil:
            np.random.shuffle((<Model> ptr).__states)
        for idx in range(1, n, 2):
            # obtain random pair
            idx = nodeids[idx - 1]
            jdx = nodeids[idx]

            (<Model> ptr)._states = &modified[0]
            state1 = (<Model> ptr)._states[idx]
            state2 = (<Model> ptr)._states[jdx]

            # normal state
            den = (<Model> ptr).probability(state1, idx) *\
              (<Model> ptr).probability(state2, jdx)

            (<Model> ptr)._states = &backup[0]
            # swapped state
            nom = (<Model> ptr).probability(state2, idx) *\
              (<Model> ptr).probability(state1, jdx)

            # accept
            if self.rng._rand() < nom / den:
                (<Model> ptr)._newstates[idx] = state2
                (<Model> ptr)._newstates[jdx] = state1
            else:
                (<Model> ptr)._newstates[idx] = backup[idx]
                (<Model> ptr)._newstates[jdx] = backup[jdx]
        return

   

    @property
    def p_recomb(self): return self._p_recomb

    @p_recomb.setter
    def p_recomb(self, value):
        assert 0 <= value <= 1
        self._p_recomb = value
        # print(f"recomb set to {value}")


cdef class RandomGenerator:
    def __init__(self,\
                 object seed,\
                 ):
        """Init mersenne twister with some seed"""


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

    cpdef double rand(self):
        return self._rand()

    cdef double _rand(self) nogil:
        """ Draws uniformly from 0, 1"""
        return self._dist(self._gen)

    @property
    def seed(self): return self._seed
    @seed.setter
    def seed(self, value):
        if isinstance(value, int) and value >= 0:
            self._seed = value
            self._gen   = mt19937(self.seed)
        else:
            raise ValueError("Not an uint found")

    cdef void fisher_yates(self, \
                           node_id_t* nodes,\
                           size_t n, \
                           size_t stop) nogil:
        cdef size_t idx, jdx
        for idx in range(n - 1, 1):
            jdx = <size_t> (self._rand() * idx)
            swap(nodes[idx], nodes[jdx])
            if stop == 1:
                break
        return


    


cdef class Adjacency:
   def __init__(self, object graph):
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

            node_id_t source, target

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

        # Private
        _nodeids         = np.arange(graph.number_of_nodes(), dtype = np.uintp)
        np.random.shuffle(_nodeids) # prevent initial scan-lines in grid
        self._nodeids    = _nodeids
        self._nNodes     = graph.number_of_nodes()
   def __repr__(self):
        return str(self._adj)

cdef class Rules:
    def __init__(self, object rules):
        self.rules = rules
        cdef:
             # output
             multimap[state_t, pair[ state_t, double ]] r
             # var decl.
             pair[state_t, pair[state_t, double]] tmp
             double weight
             dict nl = nx.node_link_data(rules)
             state_t source, target

        for link in nl['links']:
            weight = link.get('weight', 1)
            source = link.get('source')
            target = link.get('target')
            tmp.first = target
            tmp.second = pair[state_t, double](source, weight)
            r.insert(tmp)
            if not nl['directed'] and source != target:
                tmp.first  = source;
                tmp.second = pair[state_t, double](target, weight)
                r.insert(tmp)

        self._rules = r # cpp property
        # self.rules = rules # hide object

    cdef rule_t _check_rules(self, state_t x, state_t y) nogil:

        it = self._rules.find(x)
        cdef rule_t tmp
        while it != self._rules.end():
            if deref(it).second.first == y:
                tmp.first = True
                tmp.second = deref(it).second
                return tmp
            post(it)
        return tmp


cdef class Model:
    def __init__(self,\
                 graph       = nx.path_graph(1),\
                 agentStates = np.array([0], dtype = np.int),\
                 nudgeType   = "constant",\
                 updateType  = "async",\
                 nudges      = {},\
                 seed        = None,\
                 memorySize  = 0,\
                 kNudges     = 1,\
                 memento     = 0,
                 p_recomb    = None,\
                 rules       = nx.Graph(),\
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
            :agentStates: the states that the agents can assume [default = [0,1]]
            :updateType: how to sample the state space (default async)
            :nudgeType: the type of nudge used (default: constant)
            :memorySize: use memory dynamics (default 0)
       """
        # use current time as seed for rng
        self._rng = RandomGenerator(seed = seed)
         
        self._rules = Rules(rules)
        self.kNudges = kNudges

        self._agentStates = np.asarray(agentStates, dtype = np.double).copy()
        self._nStates     = len(agentStates)
        if isinstance(p_recomb, float):
            self._mcmc = MCMC(self._rng, p_recomb)
            self._use_mcmc = True
        else:
            self._mcmc = MCMC(self._rng, 0)
            self._use_mcmc = False

        # create adj list
        # if graph:
        self.adj = Adjacency(graph)
        # set states if present
        states = kwargs.get("states")
        if states is not None:
            self.states = states.copy()
        else:
            self.reset()

        # create properties
        self.nudgeType  = nudgeType

        # create memory
        self.memorySize   = <size_t> memorySize
        self._memory      = np.random.choice(self.agentStates, size = (self.memorySize, self.adj._nNodes))
        # weight factor of memory
        self._memento     = <size_t> memento
        self.nudges       = nudges
        # n.b. sampleSize has to be set from no on
        self.updateType = updateType
        self.sampleSize = <size_t> kwargs.get("sampleSize", self.nNodes)

        self._z = 1 / <double> self._nStates
       

    cpdef double rand(self, size_t n):
        for i in range(n):
            self._rng.rand()
        return 0.

    cdef state_t[::1]  _updateState(self, node_id_t[::1] nodesToUpdate) nogil:
        cdef NudgesBackup* backup = new NudgesBackup()
        # updating nodes
        cdef node_id_t node
        if self._use_mcmc:
            self._mcmc.step(nodesToUpdate, <PyObject *> self)
        else:
            for node in range(nodesToUpdate.shape[0]):
                node = nodesToUpdate[node]
                #self._apply_nudge(node, backup)
                self._step(node)
                #self._remove_nudge(node, backup)

        # clean up
        free(backup)
        self._swap_buffers()
        self._last_written = (self._last_written + 1) % 2
        # return self.__newstates
        if self._last_written == 1:
            return self.__newstates
        else:
            return self.__states

    cdef void _apply_nudge(self, node_id_t node,\
                           NudgesBackup* backup) nogil:

        # check if it has neighbors
        if self.adj._adj[node].neighbors.size() == 0:
            return
        # TODO: check struct inits; I think there is no copying done here
        cdef node_id_t idx
        cdef state_t state
        cdef NodeBackup tmp
        cdef weight_t weight
        cdef int jdx = 0
        cdef size_t agent_idx
        # check if there is a nudge
        nudge = self._nudges.find(node)
        it = self.adj._adj[node].neighbors.begin()
        if nudge != self._nudges.end():
            # start nudge
            if self._rng._rand() < deref(nudge).second:
                # random sampling
                idx = <node_id_t> (self._rng._rand() * self.adj._adj[node].neighbors.size())
                # obtain bucket
                it = self.adj._adj[node].neighbors.begin()
                while it != self.adj._adj[node].neighbors.end():
                    if jdx == idx:
                        idx = deref(it).first
                        break
                    jdx +=1 
                    post(it)
                # obtain state
                state = self._states[idx]
                weight = self.adj._adj[node].neighbors[idx]
                # store backup
                tmp.state  = state
                tmp.weight = weight
                deref(backup)[idx] = tmp 

                # adjust weight
                self.adj._adj[node].neighbors[idx] = weight * self._kNudges
                # sample uniformly
                agent_idx = <size_t> (self._rng._rand() * self._nStates)
                self._states[node] = self._agentStates[idx]
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
            self._states[neighbor] = deref(it).second.state
            self.adj._adj[node].neighbors[neighbor] = deref(it).second.weight
            post(it)
        deref(backup).clear()
        return


    cdef vector[double]  _nudgeShift(self, node_id_t node, vector[double] p ) nogil:
        # shift pmf by some nudge
        _nudge = self._nudges.find(node)
        cdef size_t idx
        cdef double nudge
        #TODO: normalize nudge pmf
        if _nudge != self._nudges.end(): 
            nudge = deref(_nudge).second
            with gil:
                for idx in range(p.size()) :
                    p[idx] += nudge 
        return p
    cdef void _swap_memory(self) nogil:
        # use swapped states
        cdef size_t mi, node
        for mi in range(0, self._memorySize):
            if mi == 0:
                for node in range(self.adj._nNodes):
                    self._memory[mi, node] = self._states[node]
            else:
                self._memory[mi] = self._memory[mi - 1]
        return


    cdef void _swap_buffers(self) nogil:
        """
        Update state buffers
        This function is intended to allow for custom buffers update
        """
        swap(self._states, self._newstates)
        # default also swap the memory buffer if exists
        self._swap_memory()
        return

    cpdef state_t[::1] updateState(self, node_id_t[::1] nodesToUpdate):
        """
        General state updater wrapper
        I
        """
        return self._updateState(nodesToUpdate)

    cdef void _step(self, node_id_t node) nogil:
        return

    cpdef node_id_t[:, ::1] sampleNodes(self, size_t nSamples):
        return self._sampleNodes(nSamples)

    cdef node_id_t[:, ::1] _sampleNodes(self, size_t  nSamples) nogil:
        # cdef size_t [:, ::1] sampleNodes(self, size_t  nSamples):
        """
        Shuffles nodeids only when the current sample is larger
        than the shuffled array
        N.B. nodeids are mutable
        """
        # check the amount of samples to get
        cdef:
            size_t sampleSize = self._sampleSize
            # TODO replace this with a nogil version
            # long _samples[nSamples][sampleSize]
            size_t start, i, j, k
            size_t samplei

        # if serial move through space like CRT line-scan method
        cdef node_id_t[:, ::1] samples

        # replace with nogil variant
        with gil:
            samples = np.zeros((nSamples, sampleSize), dtype = np.uintp)
        # cdef vector[vector[node_id_t]] samples = vector[vector[node_id_t]](nSamples)
        cdef node_id_t* nodeids = &self.adj._nodeids[0]
        for samplei in range(nSamples):
            start = (samplei * sampleSize) % self.adj._nNodes
            if start + sampleSize >= self.adj._nNodes or sampleSize == 1:
                # fisher-yates swap
                self._rng.fisher_yates(\
                                        nodeids, \
                                        self.adj._nNodes, \
                                        sampleSize)

            # assign the samples; will be sorted in case of seri        
            for j in range(sampleSize):
                samples[samplei][j]    = nodeids[(start + j) % self.adj._nNodes]
        return samples
        
    cpdef void reset(self, p = None):
        if p is None:
            p = np.ones(self.nStates) / self.nStates
        self.states = np.random.choice(\
                                self.agentStates, \
                                p = p, \
                                size = self.adj._nNodes)

    def removeAllNudges(self):
        """
        Sets all nudges to zero
        """
        self._nudges.clear()

    cpdef np.ndarray simulate(self, size_t samples):
        cdef:
            state_t[:, ::1] results = np.zeros((samples, self.adj._nNodes), dtype = np.double)
            # int sampleSize = 1 if self._updateType == 'single' else self.adj._nNodes
            node_id_t[:, ::1] r = self.sampleNodes(samples)
            # vector[vector[int][sampleSize]] r = self.sampleNodes(samples)
            int i

        if self.last_written:
            results[0] = self.__states
        else:
            results[0] = self.__newstates

        for i in range(1, samples):
            results[i] = self._updateState(r[i])
        return results.base # convert back to normal array


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

    cdef state_t _sample_proposal(self) nogil:
        return self._agentStates[<size_t> ( self._rng._rand() * self._nStates ) ]

    ##### MODEL PROPERTIES
    #####
    #####
    @property
    def p_recomb(self):
        return self._mcmc._p_recomb

    @p_recomb.setter
    def p_recomb(self, value):
        assert  0 <= value <= 1
        self._mcmc._p_recomb = value
    @property
    def rng(self): return self._rng

    @property
    def graph(self): return self.adj.graph

    @property
    def nNodes(self): return self.adj._nNodes

    @property
    def mcmc(self): return self._mcmc
    # TODO: make class pickable
    # hence the wrappers
    @property
    def memorySize(self): return self._memorySize

    @memorySize.setter
    def memorySize(self, value):
        if isinstance(value, int):
            self._memorySize = <size_t> value
        else:
            self._memorysize = 0

    @property
    def memento(self) : return self._memento
    @memento.setter
    def memento(self, val):
        if isinstance(val, int):
            self._memento = val
            self._memory = np.random.choice(self.agentStates,
                                            size = (val, self.nNodes))

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
    def agentStates(self): return self._agentStates.base# warning has no setter!


    @property
    def adj(self):
        return self.adj

    @property
    def states(self)    :
        if self.last_written:
            return self.__newstates.base
        else:
            return self.__states.base
    
    @property
    def updateType(self): return self._updateType

    @property
    def nudgeType(self) : return self._nudgeType

    @property
    def nodeids(self)   : return self.adj._nodeids.base

    @property
    def nudges(self)    : return self._nudges

    @property
    def nNodes(self)    : return self.adj._nNodes

    @property
    def nStates(self)   : return self._nStates


    @property
    def sampleSize(self): return self._sampleSize

    @property
    def newstates(self) :
        if self.last_written:
            return self.__states.base
        else:
            return self.__newstates.base



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
                if k in self.adj.mapping:
                    idx = self.adj.mapping[k]
                    self._nudges[idx] = v
                elif k in self.adj.rmapping:
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
            self._newstates = self._states
            # assign  buffers to the same address
            self.__newstates = self.__states
            # sanity check
            assert self._states == self._newstates
            assert id(self.__states.base) == id(self.__newstates.base)
        # reset buffer pointers
        elif value == "sync":
            # obtain a new memory address
            self.__newstates = self.__states.base.copy()
            assert id(self.__newstates.base) != id(self.__states.base)
            # sanity check pointers (maybe swapped!)
            self._states   = &self.__states[0]
            self._newstates = &self.__newstates[0]
            # test memory addresses
            assert self._states != self._newstates
            assert id(self.__newstates.base) != id(self.__states.base)
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
            self._sampleSize = <size_t> (value * self.adj._nNodes)
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
        # check existence of buffer
        if self._states is NULL:
            self.__states = np.random.choice(self.agentStates, \
                                             self.adj._nNodes)
            self._states = &self.__states[0]

        if self._newstates is NULL:
            self.__newstates = np.random.choice(self.agentStates,\
                                                 size = self.adj._nNodes)
            self._newstates = &self.__newstates[0]

        # case iterable
        if hasattr(value, '__iter__'):
            for i in range(self.adj._nNodes):
                # case dict
                if hasattr(value, 'get'):
                    val = <state_t> value.get(self.adj.rmapping[i])
                # case iterable
                else:
                    val = <state_t> value[i]
                self._states[i]    = val
                self._newstates[i] = val
        # case value
        else:
            for node in range(self.adj._nNodes):
                self._states[node] = <state_t> value

    def get_settings(self):
        """
        Warning this function may cause bugs
        The model properties have to be copied without being overly verbose
        The seed needs to be updated otherwise you will get the model
        """
        kwargs = {}
        from pickle import dumps
        for k in dir(self):
            atr = getattr(self, k)
            if k[0] != '_' and not callable(atr):
                try:
                    dumps(atr)
                    kwargs[k] = atr
                except:
                    pass
        return kwargs

    def __reduce__(self):
        return rebuild, (self.__class__, self.get_settings())
        # return self.__class__(**self.get_settings())
        #return rebuild, (self.__class__, kwargs)

    def __deepcopy__(self, memo = {}):
        if len(memo) == 0:
            memo = self.get_settings()
        return self.__class__(**memo)

    cdef SpawnVec _spawn(self, size_t nThreads = openmp.omp_get_num_threads()):
        """
        Spawn independent models
        """
        cdef:
            int tid
            SpawnVec spawn 
            Model m
        for tid in range(nThreads):
            # ref counter increase
            m =  self.__deepcopy__(self.get_settings())
            # HACK: fix this
            # m.mcmc._p_recomb = self.mcmc._p_recomb
            # force resed
            spawn.push_back( PyObjectHolder(\
                                        <PyObject*> m\
                                        )
                             )
        return spawn


    # WARNING: overwrite this for the model using  mcmc
    cdef double probability(self, \
                            state_t state,  \
                            node_id_t node\
                            ) nogil:
        return 1.



def rebuild(cls, kwargs):
    return cls(**kwargs)

cdef class Logmap(Model):
    def __init__(self,\
                 graph,\
                 double r = 1,\
                 double alpha = 0,\
                 agentStates = np.arange(2, dtype = np.double),\
                 **kwargs,\
                 ):
        super(Logmap, self).__init__(**locals())
        self.r = r
        self.alpha = alpha



    cdef void  _step(self, node_id_t node) nogil:
        # determine local state
        it = self.adj._adj[node].neighbors.begin()
        cdef:
            weight_t weight
            node_id_t neighbor
            long double x_n = 0

        while it != self.adj._adj[node].neighbors.end():
            neighbor = deref(it).first
            weight   = deref(it).second
            x_n      += weight *  self._states[neighbor]
            post(it)

        x_n = self._r * self._states[node] * (1 - self._states[node]) +\
            self._alpha * fabs(cos(x_n - self._states[node]) )
        return 

    @property
    def r(self):
        return self._r
    @r.setter
    def r(self, value):
        self._r = value 

    @property
    def alpha(self):
        return self._alpha
    @alpha.setter
    def alpha(self, value):
        self._alpha = value


cdef class Potts(Model):
    def __init__(self, \
                 graph,\
                 t = 1,\
                 agentStates = np.array([0, 1], dtype = np.double),\
                 delta       = 0, \
                 p_recomb    = 0.,
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
                                    p_recomb = p_recomb,
                                    **kwargs)

        self._H = kwargs.get("H", \
                             np.zeros(\
                                self.adj._nNodes, \
                                dtype = np.double)\
                             )
        self.t       = t
        self._delta  = delta

    cpdef np.ndarray node_energy(self, state_t[::1] states):
        cdef:
            np.ndarray energies = np.zeros(self.adj._nNodes)
            state_t* ptr = self._states

            state_t current, state
            double energy, store 

        self._states = &states[0]
        for node in range(self.adj._nNodes):
            current = self._states[node]
            for state in self._agentStates:
                self._states[node] = state
                energy = exp(- self._beta * \
                             self._energy(node))
                if state == current:
                    store = energy
                energies[node] += energy
            energies[node] = store / energies[node]
            self._states = ptr
        return energies

    cpdef vector[double] siteEnergy(self, state_t[::1] states):
        cdef:
            vector[double] siteEnergy = vector[double](self.adj._nNodes)
            int node
            double Z, energy
            state_t* ptr = self._states
        # reset pointer to current state
        self._states = &states[0]
        energy = 0
        for node in range(self.adj._nNodes):
            # Z = <double> self.adj._adj[node].neighbors.size()
            energy = - self._energy(node) # just average
            siteEnergy[node] = energy
        # reset pointer to original buffer
        self._states = ptr
        return siteEnergy

    # cdef vector[double] _energy(self, node_id_t node) nogil:

    cdef double _energy(self, node_id_t node) nogil:
        """
        """
        cdef:
            size_t neighbors = self.adj._adj[node].neighbors.size()
            state_t* states = self._states # alias
            size_t  neighbor, neighboridx
            double weight # TODO: remove delta

            double energy  = self._H[node]

        if self._nudges.find(node) != self._nudges.end():
            energy += self._nudges[node]


        # compute the energy
        cdef:
            pair[bint, pair[state_t, double]] rule;
            double update
            MemoizeUnit memop

        it = self.adj._adj[node].neighbors.begin()
        cdef size_t idx

        # current state as proposal
        cdef state_t proposal = self._states[node]
        while it != self.adj._adj[node].neighbors.end():
            weight   = deref(it).second
            neighbor = deref(it).first
            # check rules
            rule = self._rules._check_rules(proposal, states[neighbor])
            # update using rule
            if rule.first:
                update = rule.second.second
            # normal potts
            else:
                update = weight * self._hamiltonian(proposal, states[neighbor])

            energy += update
            post(it)

        cdef size_t mi
        # TODO: move to separate function
        for mi in range(self._memorySize):
            energy += exp(mi * self._memento) * self._hamiltonian(states[node], self._memory[mi, node])
        return energy

    cdef double probability(self, state_t state, node_id_t node) nogil:
        cdef state_t tmp = self._states[node]
        self._states[node] = state
        cdef:
            double energy = self._energy(node)
            double p = exp(self._beta * energy)

        self._states[node] = tmp
        return p

    cdef void _step(self, node_id_t node) nogil:
        cdef:
            state_t proposal = self._sample_proposal()
            state_t cur_state= self._states[node]
            double p     = self.probability(proposal, node) / \
                self.probability(cur_state, node)
        if self._rng._rand () < p:
            self._newstates[node] = proposal
        return



    cdef double _hamiltonian(self, state_t x, state_t  y) nogil:
        return cos(2 * pi  * ( x - y ) * self._z)

    @cython.cdivision(False)
    cpdef  np.ndarray magnetize(self,\
                              np.ndarray temps  = np.logspace(-3, 2, 20),\
                              size_t n             = int(1e3),\
                              size_t burninSamples = 0,\
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
            print("Spawning threads")
            cdef:
                int tid
                double Z = 1/ <double> self._nStates
                SpawnVec  tmpHolder = self._spawn(threads)
                PyObject* tmptr
                Model     tmpMod

            print("Magnetizing temperatures")
            pbar = ProgBar(N)
            for ni in prange(N, \
                    nogil       = True,\
                    num_threads =  threads,\
                    schedule    = 'static'):
                tid = threadid()
                # get model
                tmptr = tmpHolder[tid].ptr
                with gil:
                    tmpMod = <Model> tmptr
                    # setup simulation
                    tmpMod.t         =  temps[ni]
                    tmpMod.states[:] = tmpMod.agentStates[0]
                    # calculate phase and susceptibility
                    res = tmpMod.simulate(n)  * Z 
                    phase = np.real(np.exp(2 * np.pi * np.complex(0, 1) * res)).mean()
                    results[0, ni] = np.abs(phase)
                    pbar.update(1)

            results[1, :] = np.abs(np.gradient(results[0, :], temps, edge_order = 1))

            # fit sigmoid
            if match >= 0:
                # fit sigmoid
                from scipy import optimize
                params, cov = optimize.curve_fit(sigmoid, temps, results[0, :], maxfev = 10_000)
                # optimize
                # setting matched temperature
                critic = optimize.fmin(sigmoidOpt, \
                                       x0 = .1,\
                                       args = (params, match ),\
                                       )
                tcopy = critic
                print(f"Sigmoid fit params {params}\nAt T={critic}")

            self.t = tcopy # reset temp
            return results

    @property
    def delta(self): return self._delta

    @property
    def H(self): return self._H.base

    @H.setter
    def H(self, value):
        assert len(value) == self.nNodes
        for idx, v in enumerate(value):
            self._H[idx] = v

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

cdef class Prisoner(Potts):
    def __init__(self, graph,\
                 agentStates = np.arange(2),\
                 t = 1.0,\
                 R = 1.,\
                 P = 0.,\
                 S = 0.,\
                 T = .5,\
                 hierarchy = None,
                 p_recomb = None,
                 coupling = 0., **kwargs):

        super(Prisoner, self).__init__(**locals())

        self.R = R # reward
        self.S = S # suckers' payout
        self.P = P # punishment
        self.T = T # temptation

        self.coupling = coupling

        # overwrite magnetization
        if hierarchy:
            self.H = hierarchy



    cdef double _energy(self, node_id_t node) nogil:
        cdef:
            size_t neighbors = self.adj._adj[node].neighbors.size()
            state_t* states = self._states # alias
            size_t  neighbor, neighboridx
            double weight # TODO: remove delta

            double energy  = 0


        # compute the energy
        cdef:
            pair[bint, pair[state_t, double]] rule;
            double update

        it = self.adj._adj[node].neighbors.begin()
        cdef size_t idx

        # current state as proposal
        cdef state_t proposal = self._states[node]
        while it != self.adj._adj[node].neighbors.end():
            weight   = deref(it).second
            neighbor = deref(it).first
            # check rules
            rule = self._rules._check_rules(proposal, states[neighbor])
            # update using rule
            if rule.first:
                update = rule.second.second
            # normal potts
            else:
                update = weight * self._hamiltonian(proposal, states[neighbor])

            energy += update
            post(it)

        cdef size_t mi
        # TODO: move to separate function
        for mi in range(self._memorySize):
            energy += exp(mi * self._memento) * self._hamiltonian(states[node], self._memory[mi, node])
        return energy

    cdef double _hamiltonian(self, state_t x, state_t y) nogil:
        """
        Play the prisoner game
        """
        return self._R * x * y + self._T * x * fabs(1  - y) + \
            self._S * fabs(1 - x) * y  + self._P * fabs( 1 - x ) * fabs( 1 - y )



    cdef void _step(self, node_id_t node) nogil:
        self.probability(self._states[node], node)

    cdef double probability(self, state_t state, node_id_t node) nogil:
        cdef state_t tmp = self._states[node]
        self._states[node] = state

        cdef size_t idx = <size_t> (self._rng._rand() * self.adj._adj[node].neighbors.size())
        cdef node_id_t neighbor = (self.adj._adj[node].neighbors.bucket(idx))
        cdef:
            double energy          = self._energy(node)
            double energy_neighbor = self._energy(neighbor)
            double delta           = self._H[neighbor] - self._H[node]
            double p = 1 / (1 + \
                            exp(self._beta  * (energy - energy_neighbor * (1 + self._coupling * delta))))

        if self._rng._rand() < p:
            self._newstates[node] = self._states[neighbor]
        # self._states[node] = tmp
        return p

    def _setter(self, value, start = 0, end = 1):
        if start >= 0:
            return value


    # boiler-plate...
    @property
    def coupling(self): return self._coupling

    @coupling.setter
    def coupling(self, value):
        self._coupling = self._setter(value)

    @property
    def P(self): return self._P

    @P.setter
    def P(self, value):
        self._P = self._setter(value)

    @property
    def R(self): return self._R

    @R.setter
    def R(self, value):
        self._R = self._setter(value)

    @property
    def S(self): return self._S

    @S.setter
    def S(self, value):
        self._S = self._setter(value)

    @property
    def T(self) : return self._T

    @T.setter
    def T(self, value):
        self._T = self._setter(value)




cdef class Pottsis(Potts):
    def __init__(self, \
                 graph, \
                 beta = 1, \
                 eta  = .2, \
                 mu   = .1, \
                 **kwargs):

        super(Pottsis, self).__init__(graph = graph,\
                                      **kwargs)
        self.mu = mu
        self.eta = eta
        self.beta = beta

  
    cdef double _energy(self, node_id_t node) nogil:
        """
        """
        cdef:
            size_t neighbors = self.adj._adj[node].neighbors.size()
            state_t* states = self._states # alias
            size_t  neighbor, neighboridx
            double weight # TODO: remove delta

            double energy = self._H[node]

        # compute the energy
        cdef:
            pair[bint, pair[state_t, double]] rule;
            double update
            MemoizeUnit memop

        it = self.adj._adj[node].neighbors.begin()
        cdef size_t idx
        cdef state_t proposal = self._sample_proposal()
        cdef state_t state    = states[node]
        while it != self.adj._adj[node].neighbors.end():
            weight   = deref(it).second
            neighbor = deref(it).first
            # check rules
            rule = self._rules._check_rules(proposal, states[neighbor])
            # update using rule
            if rule.first:
                update = rule.second.first
            # normal potts
            else:
                #update = weight * self._hamiltonian(proposal, states[neighbor])
                update = states[neighbor]
            energy += update

            post(it)
        # prob of staying the same
        cdef double fx = (1 - self._eta)**energy

        energy = \
            (state - 1) * ((proposal * 2 - 1) * fx - proposal) + \
            proposal * (- 2 * proposal * self._mu + proposal + self._mu)

        if energy:
            energy = log(energy)
        else:
            energy = -INFINITY
        cdef size_t mi

        # # TODO: move to separate function
        # for mi in range(self._memorySize):
        #     energy[0] -= exp(- mi * self._memento) * self._hamiltonian(states[node], self._memory[mi, node])
        #     energy[1] -= exp(-mi * self._memento ) * self._hamiltonian(self._agentStates[testState], self._memory[mi, node])

        return energy
    
    # this is currently not correct,
    # x, y here need to be the future and current state
    # This model is different from the traditional potts
    # The state being considered is not 1, 1 but in this case 2,2
    # Need a way to solve this problem
    # cdef double _hamiltonian(self, state_t x, state_t y, double sum) nogil
    cdef double _hamiltonian(self, state_t x, state_t y) nogil:
        return y

    @property
    def eta(self):
        return self._eta
    @eta.setter
    def eta(self,value):
        self._eta = value

    @property
    def mu(self):
        return self._mu
    @mu.setter
    def mu(self,value):
        self._mu = value

    @property
    def beta(self): return self._beta

    @beta.setter
    def beta(self, value):
        self._beta = value



cdef class Ising(Potts):
    def __init__(self, graph,\
                 **kwargs):
        # default override
        kwargs['agentStates'] = np.array([0, 1], dtype = np.double)
        super(Ising, self).__init__(\
                                    graph = graph,\
                                    **kwargs)

    # cdef double _hamiltonian(self, state_t x , state_t y) nogil:
    #     return <double> (x * y)

# associated with potts for matching magnetic
@cython.binding(True)
@cython.cdivision(False)
def sigmoid(x, a, b, c, d):
    return  a * (1. + np.exp(b * x - c))**(-1) + d
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

    cdef double _get_system_influence(self) nogil:
        cdef double influence = 0
        for node in range(self.adj._nNodes):
            influence += self._states[node]
        return influence / <double> self.adj._nNodes
    
    cdef double probability(self, state_t proposal, node_id_t node) nogil:
        cdef:
            # vector[double] probs
            double energy
            double delta
            double p
            double systemInfluence = self._alpha * self._get_system_influence()

        # store state
        cdef state_t backup_state = self._states[node]

        # compute proposal
        self._states[node] = proposal
        energy = self._energy(node)
        delta  = energy - self._states[node] * systemInfluence
        p      = exp(self._beta * delta)
        return p

        # if self._rng._rand() < p :
        #     self._newstates[node] = <state_t> energy
        #     self._newsystem_mag_ptr[0] += 2 * (energy[2] / <double> self.adj._nNodes)
        # return

    cdef void _swap_buffers(self) nogil:
         swap(self._states, self._newstates)
         swap(self._system_mag_ptr, self._newsystem_mag_ptr)
         return

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


cdef class AB(Model):
    def __init__(self, graph, zealots = dict(),\
                 **kwargs):
        kwargs['agentStates'] = np.arange(3) # a, ab, b
        super(AB, self).__init__(graph, **kwargs)
        for k in zealots:
            self._zealots[k] = True

    cdef void _step(self, \
                    node_id_t node\
                    ) nogil:

        cdef state_t* proposal = self._newstates

        cdef Neighbors tmp = self.adj._adj[node].neighbors
        # random interact with a neighbor
        cdef size_t idx = <size_t> (self._rng._rand() * (tmp.size() - 1))

        # work around for counter access
        it = tmp.begin()
        cdef size_t counter = 0
        while it != tmp.end(): 
            if counter == idx:
                break
            counter += 1
            post(it)

        cdef node_id_t neighbor = deref(it).first

        cdef state_t thisState = self._states[node]
        cdef state_t thatState = self._states[neighbor]
        # if not AB
        if thisState != 1:
            if thisState == thatState:
                return
            else:
                # CASE A
                if thisState == 0:
                    if thatState == 2:
                        proposal[neighbor] = 1
                    else:
                        proposal[neighbor] = 0
                # CASE B
                if thisState == 2:
                    if thatState == 1:
                        proposal[neighbor] = 2
                    else:
                        proposal[neighbor] = 1
        # CASE AB
        else:
            # communicate A
            if self._rng._rand() < .5:
                if thatState == 1:
                    proposal[neighbor] = 0
                    proposal[node]     = 0
                elif thatState == 2:
                    proposal[neighbor] = 1
            # communicate B
            else:
                if thatState == 1:
                    proposal[node]  = 2
                    proposal[neighbor] = 2
                elif thatState == 0:
                    proposal[neighbor] = 1
        if self._zealots[neighbor]:
            proposal[neighbor] = thatState
        return


cdef class SIRS(Model):
    def __init__(self, graph, \
                 agentStates = np.array([0, 1, 2], dtype = np.double),\
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

    cdef float _checkNeighbors(self, node_id_t node) nogil:
        """
        Check neighbors for infection
        """
        cdef:
            node_id_t  neighbor
            float neighborWeight
            float infectionRate = 0
            float ZZ = 1
        it = self.adj._adj[node].neighbors.begin()
        while it != self.adj._adj[node].neighbors.end():
            neighbor = deref(it).first
            neighborWeight = deref(it).second
            post(it)
            # sick
            if self._states[neighbor] == 1:
                infectionRate += neighborWeight * self._states[neighbor]
            # NOTE: abs weights?
            ZZ += neighborWeight
        return infectionRate * self._beta / ZZ

    cdef void _step(self, node_id_t node) nogil:
        cdef:
            float rng = self._rng._rand()
        # HEALTHY state 
        if self._states[node] == 0:
            # infect
            if rng  < self._checkNeighbors(node):
                self._newstates[node] = 1
        # SICK state
        elif self._states[node] == 1:
            if self._rng._rand() < .5:
                if rng < self._mu:
                    self._newstates[node] = 2
            else:
                if rng < self._nu:
                    self._newstates[node] = 0
        # SIRS motive
        elif self._states[node] == 2:
            if rng < self._kappa:
                self._newstates[node] = 0
        else:
            self._newstates[node] = self._states[node]
        # add SIRS dynamic?
        return

    cpdef void init_random(self, node = None):
       self.states = 0
       if node:
           idx = self.adj.mapping[node]
       else:
           idx = <size_t> (self._rng._rand() * self.adj._nNodes)
       self._states[idx] = 1

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
            k = self.adj._adj[node].neighbors.size()
            rule = np.random.randint(0, 2**(2 ** k), dtype = int)
            rule = format(rule, f'0{2 ** k}b')[::-1]
            self._evolve_rules[node] = [int(i) for i in rule]

    @property
    def rules(self):
        return self._evolve_rules

    cdef void _step(self, node_id_t node) nogil:
       """
       Update step for Random Boolean networks
       Count all the 1s from the neighbors and index into fixed rule
       """

       cdef:
           long c = 0
           long counter = 0 
           long neighbor
           long N = self.adj._adj[node].neighbors.size()
       it = self.adj._adj[node].neighbors.begin()
       while it != self.adj._adj[node].neighbors.end():
           if self._states[deref(it).first] == 1:
               counter += 2 ** c
           c += 1
           post(it)

        #update
       self._newstates[node] = self._evolve_rules[node][counter]
       return
   

cdef class Percolation(Model):
    def __init__(self, graph, p = 1, \
                 agentStates = np.array([0, 1], dtype = np.double), \
                **kwargs):
        super(Percolation, self).__init__(**locals())
        self.p = p


    cdef void _step(self, node_id_t node) nogil:
        cdef:
            long neighbor
        if self._states[node]:
            it = self.adj._adj[node].neighbors.begin()
            while it != self.adj._adj[node].neighbors.end():
                if self._rng._rand() < self._p:
                    neighbor = deref(it).first
                    self._newstates[neighbor] = 1
                post(it)
        return 

    @property
    def p(self):
        return self._p
    
    @p.setter
    def p(self, value):
        self._p = value



cdef class Bonabeau(Model):
    """
    Bonabeau model in hierarchy formation

    
    """
    def __init__(self, graph,\
                 agentStates = np.array([0, 1]),\
                 eta = 1,\
                 **kwargs):

        super(Bonabeau, self).__init__(**locals())
        self.eta = eta

        self._weight = np.zeros(self.nNodes, dtype = np.double)

    cdef void _step(self, node_id_t node) nogil:
        # todo: implement
        # move over grid

        # if other agent present fight with hamiltonian

        cdef state_t thisState = self._states[node]
        if thisState == 0:
            return

        cdef size_t idx = <size_t> (self._rng._rand() * self.adj._adj[node].neighbors.size())
        neighbor = self.adj._adj[node].neighbors.begin()
        for i in range(idx):
            if i == idx:
                break
            post(neighbor)

        cdef:
            node_id_t neighborPosition = deref(neighbor).first
            state_t thatState     = self._states[neighborPosition]
            double p
        if thatState:
            p = self._hamiltonian(self._weight[node], self._weight[neighborPosition])
            # won fight
            if self._rng._rand() < p:
                # swap position
                self._newstates[node] = thatState
                self._newstates[neighborPosition] = thisState

                self._weight[node] += 1
                self._weight[neighborPosition] -= 1
            else:
                self._weight[node] -= 1
                self._weight[neighborPosition] += 1
        else:
            self._newstates[neighborPosition] = thisState
            self._newstates[node]             = thatState
        return
    cdef double _hamiltonian(self, double x, double y) nogil:
         return <double>(1 + exp(-self._eta * (x - y)))**(-1)

    @property
    def eta(self):
        return self._eta
    @eta.setter
    def eta(self,value):
        self._eta = value

    @property
    def weight(self): return self._weight.base


cdef class CCA(Model):
    def __init__(self, \
                 graph,\
                 threshold = 0.,\
                 agentStates = np.array([0, 1, 2], dtype = np.double),\
                 **kwargs):
        """
        Circular cellular automaton
        """

        super(CCA, self).__init__(**locals())

        self.threshold = threshold

    cdef void _evolve(self, node_id_t node) nogil:
        """
        Rule : evolve if the state of the neigbhors exceed a threshold
        """

        cdef:
            long neighbor
            long nNeighbors = self.adj._adj[node].neighbors.size()
            int i
            double fraction = 0
            state_t* states = self._states
        # check neighbors and see if they exceed threshold
        it = self.adj._adj[node].neighbors.begin()
        while it != self.adj._adj[node].neighbors.end():
            neighbor = deref(it).first
            if (states[neighbor] == (states[node] + 1) % self._nStates):
                fraction += 1
            post(it)
        if (fraction / <double> nNeighbors >= self._threshold):
            self._newstates[node] = ((states[node] + 1 ) % self._nStates)
        else:
            if self._rng._rand() <= self._threshold:
                i = <int> (self._rng._rand() * self._nStates)
                self._newstates[node] = self._agentStates[i]
        return 
    cdef void _step(self, node_id_t node) nogil:
        self._evolve(node)
        return

    # threshold for neighborhood decision
    @property
    def threshold(self):
        return self._threshold
    @threshold.setter
    def threshold(self, value):
        assert 0 <= value <= 1.
        self._threshold = value




#def rebuild(graph, states, nudges, updateType):
#    cdef RBN tmp = RBN(graph, updateType = updateType)
#    tmp.states = states.copy()
#    tmp.nudges = nudges.copy()
#    return tmp


