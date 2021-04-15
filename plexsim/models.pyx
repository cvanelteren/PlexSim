# distutils: language=c++
## cython: profile = True
## cython: linetrace = True
## distutils: define_macros=CYTHON_TRACE_NOGIL=1
## cython: np_pythran=True


# __author__ = 'Casper van Elteren'
cimport cython

import numpy as np
cimport numpy as np
import networkx as nx, functools, time
import copy, sys, os

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
from cpython cimport PyObject


from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from libc.math cimport exp, log, cos, pi, lround, fabs, isnan, signbit

from pyprind import ProgBar
#from alive_progress import alive_bar
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
    """
    Random number generator class
        :param \
                         RandomGenerator rng: 
        :param \
                         double p_recomb:  genetic algorithm recombination probability\
                        :type: float
    """
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
        for idx in range(n - 1):
            jdx = <size_t> (self._rand() * (n - idx))
            swap(nodes[idx], nodes[jdx])
            if stop == 1:
                break
        return


cdef class Adjacency:
   """
    Constructs adj matrix using structs
    intput:
        :nx.Graph or nx.DiGraph: graph
   """
   def __init__(self, object graph):

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


cdef public class Model [object PyModel, type PyModel_t]:
    """
    Base type for all models. This should hold all the minimial required information for building a model.
    Should not be instantiated directly

    :param \
                        graph: Structure of the system. :type: nx.Graph
    :param \
                        agentStates:  np.ndarray containing possible states agent can assume, defaults to np.array([0, 1]).
    :param \
                        nudgeType:  allow nudging of node states, defaults to 'constant'
    :param \
            updateType: 'async' or  'sync'. Async is equivalent to :sampleSize;
                        glauber   updates.  In   contrast,   'async'  has   two
                        "indepdendent" buffers. The two variants can have effect
                        your simulation results. Defaults to 'async'
    :param \
                        nudges:  dict containing which nodes to nudge; keys can be tuples,  values are floats.
    :param \
                        seed: random number generator seed, defaults to  current time
    :param \
                        memorySize: size of memory to consider, defaults to 0.
    :param \
                        kNudges:  
    :param \
                        memento:  exponential decay rate of memerory effect.
    :param\
                    p_recomb: ignore
    :param \
                        rules:  ignore 
    :param \
                        **kwargs:  Ignore
    """
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

        # create pointer
        self.ptr = <PyObject*> self
       

    cpdef double rand(self, size_t n):
        """
        draw random number [0, 1]
        """
        for i in range(n):
            self._rng.rand()
        return 0.

    cdef state_t[::1]  _updateState(self, node_id_t[::1] nodesToUpdate) nogil:
        """
        :param nodesToTupdate: list containing node ids to update
        returns: new system state 
        """
        cdef NudgesBackup* backup = new NudgesBackup()
        # updating nodes
        cdef node_id_t node
        if self._use_mcmc:
            self._mcmc.step(nodesToUpdate, <PyObject *> self)
        else:
            for node in range(nodesToUpdate.shape[0]):
                node = nodesToUpdate[node]
                self._apply_nudge(node, backup)
                self._step(node)
                self._remove_nudge(node, backup)

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
        cdef node_id_t target

        # check if there is a nudge
        nudge = self._nudges.find(node)
        it = self.adj._adj[node].neighbors.begin()
        cdef pair[node_id_t, weight_t] _nudge
        if nudge != self._nudges.end():
            # start nudge
            target = deref(nudge).first
            weight = deref(nudge).second
            
            _nudge.first = self.adj._nNodes + 1
            _nudge.second = weight

            self.adj._adj[target].neighbors.insert(_nudge)

            # if self._rng._rand() < deref(nudge).second:
            #     # random sampling
            #     idx = <node_id_t> (self._rng._rand() * self.adj._adj[node].neighbors.size())
            #     # obtain bucket
            #     it = self.adj._adj[node].neighbors.begin()
            #     while it != self.adj._adj[node].neighbors.end():
            #         if jdx == idx:
            #             idx = deref(it).first
            #             break
            #         jdx +=1 
            #         post(it)
            #     # obtain state
            #     state = self._states[idx]
            #     weight = self.adj._adj[node].neighbors[idx]
            #     # store backup
            #     tmp.state  = state
            #     tmp.weight = weight
            #     deref(backup)[idx] = tmp 

                # # adjust weight
                # self.adj._adj[node].neighbors[idx] = weight * self._kNudges
                # # sample uniformly
                # agent_idx = <size_t> (self._rng._rand() * self._nStates)
                # self._states[node] = self._agentStates[idx]

        return

    cdef void _remove_nudge(self, node_id_t node,\
                            NudgesBackup* backup) nogil:
        """
        Clear nudges and restore the states
        """
        cdef:
            node_id_t neighbor
            NodeBackup state
            node_id_t nudge_id = self.adj._nNodes + 1
        it = deref(backup).begin()

        while it != deref(backup).end():
            neighbor  = deref(it).first
            jt =  self.adj._adj[deref(it).first].neighbors.find(nudge_id)
            if jt != self.adj._adj[deref(it).first].neighbors.end():
                self.adj._adj[deref(it).first].neighbors.erase(jt)


            # self._states[neighbor] = deref(it).second.state
            # self.adj._adj[node].neighbors[neighbor] = deref(it).second.weight

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

    cpdef public state_t[::1] updateState(self, node_id_t[::1] nodesToUpdate):
        """
        General state updater wrapper
        """
        return self._updateState(nodesToUpdate)

    cdef public void _step(self, node_id_t node) nogil:
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
                #

                # for node in range(self.adj._nNodes -  1, 1):
                #     jdx = <size_t> (self._rand() * idx)
                #     swap(nodeids[idx], nodeids[jdx])
                #     if sampleSize == 1:
                #         break

                self._rng.fisher_yates(\
                                       nodeids,
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
        """"
        :param samples: number of samples to simulate
        :type: int 
        returns:
            np.ndarray containing the system states to simulate 
        """
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

    cpdef np.ndarray simulate_mean(self, size_t samples):
        cdef:
            state_t[::1] results = np.zeros(samples, dtype = np.double)
            # int sampleSize = 1 if self._updateType == 'single' else self.adj._nNodes
            # vector[vector[int][sampleSize]] r = self.sampleNodes(samples)
            int i

        if self.last_written:
            results[0] = np.mean(self.__states)
        else:
            results[0] = np.mean(self.__newstates)

        for i in range(1, samples):
            results[i] = np.mean(self._updateState(self.sampleNodes(1)[0]))
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
    def rules(self):
        return self._rules.rules
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
                    self._nudges[idx] = <state_t> v
                elif k in self.adj.rmapping:
                    self._nudges[k] = <state_t> v
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
            #m = new Model(*m.ptr)
            # HACK: fix this
            # m.mcmc._p_recomb = self.mcmc._p_recomb
            # force resed
            spawn.push_back( PyObjectHolder(m.ptr) )

        return spawn


    # WARNING: overwrite this for the model using  mcmc
    cdef double probability(self, \
                            state_t state,  \
                            node_id_t node\
                            ) nogil:
        return 1.


cdef class ModelMC(Model):
    def __init__(self, p_recomb = 1, *args, **kwargs):
        # init base model
        super(ModelMC, self).__init__(*args, **kwargs)

        # start creating stochastic properties
        # note the rng is shared with base
        self._mcmc = MCMC(self._rng, p_recomb)


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
        """Logistic map
        :graph: test
        """
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
        self._newstates[node] = x_n
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

cdef class ValueNetworkNP(Potts):

    def __init__(self, graph,
                 rules, 
                 t = 1,
                 bounded_rational = 1,
                 agentStates = np.arange(0, 2, dtype = np.double),
                 alpha = 1,
                 **kwargs
                 ):
        super(ValueNetworkNP, self).__init__(graph = graph,
                                     agentStates = agentStates,
                                     rules = rules,
                                     **kwargs)

        self.bounded_rational = bounded_rational
        self.alpha = alpha
        self.setup_rule_paths()
        self.setup_values()


    @property
    def test(self):
        print(self.paths)
        print(self.paths_rules)
    #construct shortest path among nodes
    cpdef void compute_node_path(self, node_id_t node):
        cdef str node_label = self.adj.rmapping[node]
        cdef size_t path_counter = 0
        # idx acts as dummy merely counting the seperate unique paths
        sp = nx.single_source_shortest_path_length(self.graph, node_label, cutoff = self._bounded_rational)
        for other, distance in sp.items():
            # add the non-local influences
            # note the node_label is the start node here; ignore that in future reference
            node_other = self.adj.mapping[str(other)]
            distance = float(distance)
            self.paths[node][distance].push_back(node_other) 
            path_counter += 1
        return 
    
    cpdef void setup_values(self, int bounded_rational = 1):
        #pr = ProgBar(len(self.graph))
        # store the paths
        self.paths.clear()
        import pyprind as pr
        cdef object pb = pr.ProgBar(len(self.graph))
        cdef size_t i, n = self.adj._nNodes
        for i in prange(0, n, nogil = 1):
            with gil:
                self.compute_node_path(i)
                pb.update()
        return
    cpdef void setup_rule_paths(self):
        self.paths_rules.clear()
        # idx acts as dummy merely counting the seperate unique paths
        for state in self._rules.rules:
            paths = nx.single_source_shortest_path_length(self._rules.rules,
                                state, cutoff = self._bounded_rational)
            # values hold the other states
            for state_other, distance in paths.items():
                #state = <state_t>(state)
                # state_other = <state_t>(state_other)
                self.paths_rules[state][distance].push_back(state_other)
        return

    @property
    def bounded_rational(self):
        return self._bounded_rational
    @bounded_rational.setter
    def bounded_rational(self, value):
        assert 1 <= value <= len(self.rules)
        self._bounded_rational = int(value)
    @property
    def alpha (self):
        return self._alpha
    @alpha.setter
    def alpha(self, value):
        self._alpha = value

    cdef double _energy(self, node_id_t node) nogil:
        """
        """
        cdef:
            size_t neighbors = self.adj._adj[node].neighbors.size()
            state_t* states = self._states # alias
            size_t  neighbor, neighboridx
            double weight # TODO: remove delta

            double energy  = self._H[node] * self._states[node]

        if self._nudges.find(node) != self._nudges.end():
            energy += self._nudges[node] * self._states[node]


        # compute the energy
        cdef:
            pair[bint, pair[state_t, double]] rule;
            double update
            MemoizeUnit memop

        cdef size_t idx

        #TODO: cleanup
        # get the distance to consider based on current state
        #cdef size_t distance = self.distance_converter[proposal]
        # only get nodes based on distance it can reach based on the value network
        # current state as proposal
        cdef state_t proposal = self._states[node]
        
        cdef:
            state_t start 
            rule_t rule_pair
            size_t j

        energy = self._match_trees(node)

        cdef size_t mi
        # TODO: move to separate function
        for mi in range(self._memorySize):
            energy += exp(mi * self._memento) * self._hamiltonian(states[node], self._memory[mi, node])
        return energy 


    cdef double _match_trees(self, node_id_t node) nogil:
        """"
        Performs tree matching
        """

        # loop vars
        cdef state_t* states = self._states # alias
        cdef unordered_map[double, vector[node_id_t]] consider_nodes = self.paths[node]

        cdef:
            rule_t rule_pair
            size_t idx, r

        # path to check
        cdef vector[node_id_t] path
        # holds bottom-up value chain
        cdef vector[node_id_t] nodes_to_consider
        cdef vector[state_t] possible_states_at_distance
        cdef double tmp, update

        # acquire current node state
        cdef state_t neighbor_state, state_at_distance, node_state = states[node]
        
        cdef double counter = 0
        for r in range(1, self._bounded_rational + 1):
            nodes_to_consider = self.paths[node][r]
            # set energy addition
            tmp = 0
            possible_states_at_distance = self.paths_rules[node_state][r]
            for idx in range(nodes_to_consider.size()):
                neighbor = nodes_to_consider[idx]
                neighbor_state = states[neighbor]
                # check the possible states at distance x
                # 
                update = -1
                for jdx in range(possible_states_at_distance.size()):
                    # obtain state
                    state_at_distance = possible_states_at_distance[jdx]
                    if neighbor_state == state_at_distance:
                        update = 1
            # add weighted effect of neighbors of neighbors
            counter += update * exp(-self._alpha * r)
        return counter

    cdef double  magnetize_(self, Model mod, size_t n, double t):
        # setup simulation
        cdef double Z = 1 / <double> self._nStates  
        mod.t         =  t
        # calculate phase and susceptibility
        #mod.reset()
        mod.states[:] = mod.agentStates[0]
        res = mod.simulate(n) 
        res = np.array([mod.check_vn(i) for i in res]).mean()
        #res = np.array([mod.siteEnergy(i) for i in res]).mean()
        return res
        #return np.array([self.siteEnergy(i) for i in res]).mean()
        #return np.abs(np.real(np.exp(2 * np.pi * np.complex(0, 1) * res)).mean())

cdef class ValueNetwork(Potts):
    def __init__(self, graph,
                 rules, 
                 t = 1,
                 bounded_rational = 1,
                 agentStates = np.arange(0, 2, dtype = np.double),
                 **kwargs
                 ):
        super(ValueNetwork, self).__init__(graph = graph,
                                     agentStates = agentStates,
                                     rules = rules,
                                     **kwargs)
         
        #e = [(u, v) for u, v, d in rules.edges(data = True) if dict(d).get('weight', 1) > 0]
        #r = nx.from_edgelist(e)
        #
        self.bounded_rational = bounded_rational
        self.setup_values(bounded_rational)


    @property
    def bounded_rational(self):
        return self._bounded_rational
    @bounded_rational.setter
    def bounded_rational(self, value):
        assert 1 <= value <= len(self.rules)
        self._bounded_rational = int(value)

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
            energy = - self._energy(node) #/ <double>(self.adj._adj[node].neighbors.size()) # just average
            siteEnergy[node] = energy
        # reset pointer to original buffer
        self._states = ptr
        return siteEnergy
     
    cdef double  magnetize_(self, Model mod, size_t n, double t):
        # setup simulation
        cdef double Z = 1 / <double> self._nStates  
        mod.t         =  t
        # calculate phase and susceptibility
        #mod.reset()
        mod.states[:] = mod.agentStates[0]
        res = mod.simulate(n) 
        #res = np.array([mod.siteEnergy(i) for i in res]).mean()
        res = np.array([mod.check_vn(i).base for i in res]).mean()
        return res
        #return np.array([self.siteEnergy(i) for i in res]).mean()
        #return np.abs(np.real(np.exp(2 * np.pi * np.complex(0, 1) * res)).mean())
        #return res

    #construct shortest path among nodes
    cpdef void compute_node_path(self, node_id_t node):
        cdef str node_label = self.adj.rmapping[node]
        cdef size_t path_counter = 0
        cdef str other
        for other in self.graph:
            # idx acts as dummy merely counting the seperate unique paths
            for path in nx.all_simple_paths(self.graph, node_label, other, cutoff = len(self._rules.rules)):
                # add the non-local influences
                # note the node_label is the start node here; ignore that in future reference
                self.paths[node][path_counter] = [self.adj.mapping[str(i)] for i in path]
                path_counter += 1
        return 
    
    cpdef void setup_values(self, int bounded_rational = 1):
        #pr = ProgBar(len(self.graph))
        # store the paths
        self.paths.clear()
        import pyprind as pr
        cdef object pb = pr.ProgBar(len(self.graph))
        cdef size_t i, n = self.adj._nNodes
        for i in prange(0, n, nogil = 1):
            with gil:
                self.compute_node_path(i)
                pb.update()
        return
        
    
    # TODO tmp
    @property 
    def pat(self):
        return self.paths

    cpdef state_t[::1] check_vn(self, state_t[::1] state):
        cdef state_t[::1] output = np.zeros(self.nNodes)
        cdef state_t* ptr = self._states
        self._states = &state[0]
        cdef tmp = self._bounded_rational
        self._bounded_rational = len(self._rules.rules)
        for node in range(self.adj._nNodes):
            output[node] = self._match_trees(node)
        self._states = ptr
        self._bounded_rational = tmp
        return output
            
    cdef double _match_trees(self, node_id_t node) nogil:
        """"
        Performs tree matching
        """

        # loop vars
        cdef state_t* states = self._states # alias
        cdef unordered_map[size_t, vector[node_id_t]] consider_nodes = self.paths[node]
        cdef size_t neighbor_other
        cdef state_t state_other
        cdef double counter = 0

        cdef:
            state_t start 
            rule_t rule_pair
            size_t j

        # path to check
        cdef vector[node_id_t] path
        # holds bottom-up value chain
        cdef unordered_map[state_t, size_t] checker
        
        jt = consider_nodes.begin()
        while jt != consider_nodes.end():
            # reset tmp value chain
            checker.clear()
            path = deref(jt).second
            if path.size() <= self._bounded_rational:
                start = states[node]
                # color node
                checker[start] = 1
                # traverse the tree
                for j in range(1, path.size()):
                    # get neighbor
                    neighbor = path[j]
                    state_other = states[neighbor]
                    rule_pair = self._rules._check_rules(start, state_other)
                    # if rule found
                    if rule_pair.first:
                        # check the weight and see if state is finishing a chain
                        if rule_pair.second.second > 0 and checker.find(state_other) == checker.end():
                            # color node
                            checker[state_other] = 1
                        else:
                            break
                    # move pair up
                    start = state_other
                counter += (checker.size() - 1) / <double>(self._bounded_rational)
            post(jt)
        return counter


    cdef double _energy(self, node_id_t node) nogil:
        """
        """
        cdef:
            size_t neighbors = self.adj._adj[node].neighbors.size()
            state_t* states = self._states # alias
            size_t  neighbor, neighboridx
            double weight # TODO: remove delta

            double energy  = self._H[node] * self._states[node]

        if self._nudges.find(node) != self._nudges.end():
            energy += self._nudges[node] * self._states[node]


        # compute the energy
        cdef:
            pair[bint, pair[state_t, double]] rule;
            double update
            MemoizeUnit memop

        cdef size_t idx

        #TODO: cleanup
        # get the distance to consider based on current state
        #cdef size_t distance = self.distance_converter[proposal]
        # only get nodes based on distance it can reach based on the value network
        # current state as proposal
        cdef state_t proposal = self._states[node]
        
        cdef:
            state_t start 
            rule_t rule_pair
            size_t j
        cdef double counter = self._match_trees(node)
        it = self.adj._adj[node].neighbors.begin() 
        while it != self.adj._adj[node].neighbors.end():
            weight   = deref(it).second
            neighbor = deref(it).first
            # check rules
            rule = self._rules._check_rules(proposal, states[neighbor])
            # update using rule
            if rule.first:
                update = rule.second.second
            # normal potts
            elif neighbor == self.adj._nNodes + 1:
                update = weight 
            else:
                update = weight * self._hamiltonian(proposal, states[neighbor])
            energy += update
            post(it)

        cdef size_t mi
        # TODO: move to separate function
        for mi in range(self._memorySize):
            energy += exp(mi * self._memento) * self._hamiltonian(states[node], self._memory[mi, node])
        return energy * (1 + counter)
        #return energy + counter


    cdef double probability(self, state_t state, node_id_t node) nogil:
        cdef state_t tmp = self._states[node]
        self._states[node] = state
        cdef:
            double energy = self._energy(node)
            double p = exp(self._beta * energy)

        self._states[node] = tmp
        return p

    # default update TODO remove this
    cdef double _hamiltonian(self, state_t x, state_t  y) nogil:
        return cos(2 * pi  * ( x - y ) * self._z)

    cdef void _step(self, node_id_t node) nogil:
        cdef:
            state_t proposal = self._sample_proposal()
            state_t cur_state= self._states[node]
            double p     = self.probability(proposal, node) / \
                self.probability(cur_state, node)
        if self._rng._rand () < p:
            self._newstates[node] = proposal
        return

        

cdef class Potts(Model):
    """
        Potts model

        default inputs see :Model:
        Additional inputs
        :delta: a modifier for how much the previous memory sizes influence the next state
    """
    def __init__(self, \
                 graph,\
                 t = 1,\
                 agentStates = np.array([0, 1], dtype = np.double),\
                 delta       = 0, \
                 p_recomb    = 0.,
                 **kwargs):
    
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

            double energy  = self._H[node] * self._states[node]

        if self._nudges.find(node) != self._nudges.end():
            energy += self._nudges[node] * self._states[node]


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
            elif neighbor == self.adj._nNodes + 1:
                update = weight 
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

    cdef double magnetize_(self, Model mod, size_t n, double t):
        # setup simulation
        cdef double Z = 1 / <double> self._nStates  
        mod.t         =  t
        mod.states[:] = mod.agentStates[0]
        # calculate phase and susceptibility
        res = mod.simulate(n)  * Z
        phase = np.real(np.exp(2 * np.pi * np.complex(0, 1) * res)).mean()
        return np.abs(phase)

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
                #SpawnVec  tmpHolder = self._spawn(threads)
                PyObject* tmptr
                Model     tmpMod

            print("Magnetizing temperatures")
            pbar = ProgBar(N)

            # for ni in prange(N, \
            #         nogil       = True,\
            #         num_threads =  threads,\
            #         schedule    = 'static'):

            for ni in range(N):
                #tid = threadid()
                # get model
                #tmptr = tmpHolder[tid].ptr
                results[0, ni] = self.magnetize_(<Model> self.ptr, n, temps[ni])
                #with gil:
                #    results[0, ni] = self.magnetize_(<Model> tmptr, n, temps[ni])
                #    pbar.update()
                

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
    def delta(self):
        """
        """
        return self._delta

    @property
    def H(self):
        """
        External magnetic field
        """
        return self._H.base

    @H.setter
    def H(self, value):
        assert len(value) == self.nNodes
        for idx, v in enumerate(value):
            self._H[idx] = v

    @property
    def beta(self):
        """
        Shortcut for 1/T
        """
        return self._beta

    @beta.setter
    def beta(self, value):
        self._beta = value

    @property
    def t(self):
        """
        Temperature
        """
        return self._t

    @t.setter
    def t(self, value):
        self._t   = value
        self.beta = 1 / value if value != 0 else np.inf

#TODO: bug in the alpha coupler...doesnt differ from original code but doesn't
#work the same way?
cdef class Prisoner(Potts):
    """
    Prisoner dilemma model on a graph

    :param graph: Structure of the graph see Model\
    :param \
                        agentStates: 
    :param \
                        t: level of noise in the system (Gibbs distribution)
    :param \
                        T: level of temptation to defect [0, 1], defaults to 1
    :param \
                        R: level of reward to defect [0, 1], defaults to 1
    :param \
                        P: level of punishment to defect [0, 1], defaults to 0
    :param \
                        S: level of suckers' payout to defect [0, 1], defaults to 0
    :param \
                        hierarchy:  external magnetic field that would enforce hierarchy
    :param \
                        p_recomb: see model 
    :param \
                        alpha: discounting factor of how much to listen to a neighbor, default to 0
    """
    def __init__(self, graph,\
                 agentStates = np.arange(2),\
                 t = 1.0,\
                 T = 1,\
                 R = 1.,\
                 P = 0.,\
                 S = 0.,\
                 hierarchy = None,
                 p_recomb = None,
                 alpha = 0., **kwargs):
        """
        Prisoner dilemma model on a graph

        :param graph: Structure of the graph see Model\
        :param \
                            agentStates: 
        :param \
                            t: level of noise in the system (Gibbs distribution)
        :param \
                            T: level of temptation to defect [0, 1], defaults to 1
        :param \
                            R: level of reward to defect [0, 1], defaults to 1
        :param \
                            P: level of punishment to defect [0, 1], defaults to 0
        :param \
                            S: level of suckers' payout to defect [0, 1], defaults to 0
        :param \
                            hierarchy:  external magnetic field that would enforce hierarchy
        :param \
                            p_recomb: see model 
        :param \
                            alpha: discounting factor of how much to listen to a neighbor, default to 0
        """
        super(Prisoner, self).__init__(**locals(), **kwargs)

        self.T = T # temptation
        self.R = R # reward
        self.P = P # punishment
        self.S = S # suckers' payout

        self.alpha = alpha

        # overwrite magnetization
        if hierarchy:
            for idx, hi in enumerate(hierarchy):
                self.H[idx] = hi



    cdef double _energy(self, node_id_t node) nogil:

        it = self.adj._adj[node].neighbors.begin()
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
        return energy

    cdef double _hamiltonian(self, state_t x, state_t y) nogil:
        """
        Play the prisoner game
        """
        # x, y
        # 0, 1  = (D, C) -> T
        # 1, 1  = (C, C) -> R
        # 1, 0  = (C, D) -> S
        # 0, 0  = (D, D) -> P


        cdef double tmp = 0
        if x == 0. and y == 0.:
            tmp = self._P
        elif x == 1. and y == 0.:
            tmp = self._S
        elif x == 0. and y == 1.:
            tmp = self._T
        elif x == 1. and y == 1.:
            tmp = self._R
        return tmp

        #if self._rng._rand() < tmp:
            # return 1.
        # return 0.

        # return self._R * x * y + self._S * fabs(1 - y) * x + \
        #     self._T * x * fabs(1 - y)  + self._P * fabs( 1 - x ) * fabs( 1 - y )



    cdef void _step(self, node_id_t node) nogil:
        self.probability(self._states[node], node)


    cpdef double probs(self, state_t state, node_id_t node):
        return self.probability(state, node)
    cdef double probability(self, state_t state, node_id_t node) nogil:

        # get random neighbor
        cdef size_t idx = <size_t> (self._rng._rand() * self.adj._adj[node].neighbors.size())
        # get iterator and advance
        it = self.adj._adj[node].neighbors.begin()
        for c in range(idx):
            post(it)
        # assign neighbor
        cdef node_id_t neighbor = deref(it).first

        cdef double energy, energy_neighbor, delta, p
        energy          = self._energy(node)
        energy_neighbor = self._energy(neighbor)
        delta           = self._H[neighbor] - self._H[node]
        delta = -delta
        p = 1 / (1. + exp(self._beta  * (energy - energy_neighbor * (1 + self._delta * self._alpha))))

            # adopt strategy
        if self._rng._rand() < p:
            self._newstates[node] = self._states[neighbor]

        # else:
        #     idx = <size_t> (self._rng._rand() * self._nStates)
        #     self._newstates[node] = self._agentStates[idx]

        # with gil:
        #     print(energy, energy_neighbor, 1/p, self._newstates[node], self._states[node],
        #             self._states[neighbor], node, neighbor)
        return p

    def _setter(self, value, start = 0, end = 1):
        if start >= 0:
            return value


    # boiler-plate...
    @property
    def alpha(self):
        """
        Coupling coefficient property
        """
        return self._alpha

    @alpha.setter
    def alpha(self, value):
        self._alpha = self._setter(value)

    @property
    def P(self):
        """
        Punishment property (double)
        """
        return self._P

    @P.setter
    def P(self, value):
        self._P = self._setter(value)

    @property
    def R(self):
        """
        Reward property
        """
        return self._R

    @R.setter
    def R(self, value):
     
        self._R = self._setter(value)

    @property
    def S(self):
        """
        Suckers' payout property
        """
        return self._S

    @S.setter
    def S(self, value):
        self._S = self._setter(value)

    @property
    def T(self) :
        """
        Temptation property
        """
        return self._T

    @T.setter
    def T(self, value):
        self._T = self._setter(value)




cdef class Pottsis(Potts):
    """Novel implementation of SIS model using energy functions\
        :param \
                         graph: 
        :param \
                         beta: 
        :param \
                         eta: 
        :param \
                         mu: 
        :param \
                         **kwargs: 
        :returns: 

    """
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
cdef class Bornholdt(Potts):
    """
    Implementation of Bornholdt model (2000)
    Ising-like dynamics with a global magnetiztion dynamic
    """
    def __init__(self,\
                 graph, \
                 double alpha = 1,\
                 **kwargs):

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
        delta  = energy - abs(self._hamiltonian(proposal, systemInfluence))
        p      = exp(self._beta * delta)

        self._states[node] = backup_state
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
    def alpha(self):
        """
        Global coupling constant
        """
        return self._alpha

    @alpha.setter
    def alpha(self, value):
        """Global coupling"""
        #TODO: add checks?
        self._alpha = <double> value


cdef class AB(Model):
    """
    Voter AB model

    :param graph: 
        :param \
                    zealots:  dict of zealots to include (people that cannot be convinced), defaults to 0
        :param \
                         **kwargs: 
    """
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
    """
        SIR model inspired by Youssef & Scolio (2011)
        The article describes an individual approach to SIR modeling which canonically uses a mean-field approximation.
        In mean-field approximations nodes are assumed to have 'homogeneous mixing', i.e. a node is able to receive information
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
    Bonabeau model in hierarchy formation updated using heat bath equation
    based on Bonabeau et al. 1995
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

        # get random neighbor
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
        # 
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
        """
        coefficient for sigmoid curve
        """
        return self._eta
    @eta.setter
    def eta(self,value):
        self._eta = value

    @property
    def weight(self):
        """
        return weights between nodes
        """
        return self._weight.base


cdef class CCA(Model):
    """
        Circular cellular automaton
    """
    def __init__(self, \
                 graph,\
                 threshold = 0.,\
                 agentStates = np.array([0, 1, 2], dtype = np.double),\
                 **kwargs):
   

        super(CCA, self).__init__(**locals())

        self.threshold = threshold

    cdef void _step(self, node_id_t node) nogil:
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
                
        
        
