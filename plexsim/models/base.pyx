import networkx as nx, functools, time, copy, sys, os
import numpy as np, networkx as nx
from pyprind import ProgBar
cimport numpy as np, cython, openmp

from cython.parallel cimport parallel, prange, threadid

from cython.operator cimport dereference as deref
from cython.operator cimport preincrement as prei
from cython.operator cimport postincrement as post

from libc.stdlib cimport malloc, free
from libcpp.vector cimport vector
from libcpp.pair cimport pair
from libcpp.map cimport map
from libcpp.unordered_map cimport unordered_map
from cpython cimport PyObject

from libc.math cimport exp, log, cos, pi, lround, fabs, isnan, signbit
#from alive_progress import alive_bar
import multiprocessing as mp

from posix.time cimport clock_gettime, timespec, CLOCK_REALTIME
cdef extern from "math.h":
    float INFINITY


# cdef public class Model [object PyModel, type PyModel_t]:
cdef class Model:
    """Base class for all modeling classes

    Parameters
    ----------
    \ graph : nx.Graph or nx.DiGraph
        Network structure  indicating relationship among
        elements of the complex system
    \ agentStates : np.ndarray
        Discrete states that the agents can take
    \ nudgeType : str
        Type of nudging being used. Can be "constant" or
        "single".
    \ updateType : str
        Update type  of elements of the  complex system.
        Either "sync"  or "async" (default).  The "sync"
        options has two independent buffers in which the
        results  are written.  The "async"  options will
        have no independent buffers.
    \ nudges : dict
        Nudge applied to a certain variable
    \ seed : int
        Seed for random number generator.
    \ memorySize : int
        Size of the memory of the system. Defaults to 0.
    \ kNudges : int
        Deprecated.
    \ memento : int
        Deprecated
    \ p_recomb : float
        Recombination rate of the genetic algorithm. Values are within 0, 1 (defaults to zero).
        Non-zero values will activate the genetic algorithm.
    \ rules: nx.Graph or nx.DiGraph
        Network structure for rules. Only used for Value networks. Defaults to empty (not used).
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
       

    cdef state_t[::1]  _updateState(self, node_id_t[::1] nodesToUpdate) nogil:
        """Efficient cython update state. Only callable from cython mode.

        Parameters
        ----------
        node_id_t: size_t memory view
            series of node to update
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

    # TODO make this separate
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
        """Generates random nodes to update

        Shuffles nodeids only when the current sample is larger
        than the shuffled array
        N.B. nodeids are mutable

        Parameters
        ----------
        size_t nSamples: size_t
            Number of samples to draw

        Returns
        -------
        memory view of ints of size :sampleSize:

        Examples
        --------
        FIXME: Add docs.

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
        """Wrapper for simulating the system

        Parameters
        ----------
        size_t samples : int
            int

        Returns
        -------
        np.ndarray
            np.ndarray of size (time_steps, nodes)

        Examples
        --------
        FIXME: Add docs.

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
        FIXME: not implemented
        Hebbian learning rule that will strengthen similar
        connections and weaken dissimilar connections

        """

        # TODO: add learning rate delta
        # TODO: use hamiltonian function -> how to make general
        
        return 

    cdef double _learningFunction(self, node_id_t xi, node_id_t xj):
        """
        FIXME: not implemented
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
        """Returns the rule graph as a networkx object
        """
        return self._rules.graph

    @property
    def p_recomb(self):
        """Returns the recombination probability
        """
        return self._mcmc._p_recomb

    @p_recomb.setter
    def p_recomb(self, value):
        """Sets the recombination probability
        """
        assert  0 <= value <= 1
        self._mcmc._p_recomb = value
    @property
    def rng(self):
        """
        Returns random number generator. See Sampler.
        """
        return self._rng

    @property
    def graph(self):
        """
        Returns network interaction structure
        """
        return self.adj.graph

    @property
    def nNodes(self):
        """
        Returns number of nodes
        """
        return self.adj._nNodes

    @property
    def mcmc(self):
        """
        Returns metropolis sampler
        """
        return self._mcmc
    # TODO: make class pickable
    # hence the wrappers
    @property
    def memorySize(self):
        """
        Returns memory size
        """
        return self._memorySize

    @memorySize.setter
    def memorySize(self, value):
        if isinstance(value, int):
            self._memorySize = <size_t> value
        else:
            self._memorysize = 0

    @property
    def memento(self) :
        """
        """
        return self._memento
    @memento.setter
    def memento(self, val):
        if isinstance(val, int):
            self._memento = val
            self._memory = np.random.choice(self.agentStates,
                                            size = (val, self.nNodes))
    @property
    def kNudges(self):
        """
        Deprecated
        """
        return self._kNudges
    @kNudges.setter
    def kNudges(self, value):
        self._kNudges = value
    @property
    def last_written(self):
        """
        :noindex:
        """
        return self._last_written

    @last_written.setter
    def last_written(self, value):
        self._last_written = value

    @property
    def memory(self):
        """Returns memory buffer"""
        return self._memory.base

    @memory.setter
    def memory(self, value):
        if isinstance(value, np.ndarray):
            self._memory = value
    @property
    def sampleSize(self): return self._sampleSize

    @property
    def agentStates(self): return self._agentStates.base# warning has no setter!


    @property
    def states(self):
        if self.last_written:
            return self.__newstates.base
        else:
            return self.__states.base
    
    @property
    def updateType(self):
        """Returns updateType"""
        return self._updateType

    @property
    def nudgeType(self):
        """
        Returns nudgeType
        """
        return self._nudgeType

    @property
    def nodeids(self):
        """
        Returns node ids
        Note these are not sorted!
        """
        return self.adj._nodeids.base

    @property
    def nudges(self):
        """
        Return dict of nudges
        """
        return self._nudges

    @property
    def nNodes(self):
        """
        Returns number of nodes in the system
        """
        return self.adj._nNodes

    @property
    def nStates(self):
        """
        Returns size of alphabet of each agent
        """
        return self._nStates


    @property
    def sampleSize(self):
        """
        Returns sampleSize
        """
        return self._sampleSize

    @property
    def newstates(self):
        """:nodindex:"""
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

    @property
    def adj(self):
        return self.adj

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

    def get_settings(self) -> dict:
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

    def __reduce__(self) -> tuple:
        return rebuild, (self.__class__, self.get_settings())
        # return self.__class__(**self.get_settings())
        #return rebuild, (self.__class__, kwargs)

    def __deepcopy__(self, memo = {}) -> Model:
        if len(memo) == 0:
            memo = self.get_settings()
        return self.__class__(**memo)


    # tmp for testing the parallezation
    cpdef list spawn(self, size_t n_jobs = openmp.omp_get_num_threads()):
        """ Creates vector of copies of the model
        Wraps _spawn method.
        Parameters
        ==========
        n_jobs: int,
            Number of copies to make
        Returns
        =======
        list of copies of the model. Note that each thread will generate a different seed;
        the seed will be increased by the thread id.
        """
        cdef SpawnVec models_ = self._spawn(n_jobs)
        models = []
        for thread in range(n_jobs):
            models.append(<Model> models_[thread].ptr)
        return models

    cdef SpawnVec _spawn(self, size_t nThreads = openmp.omp_get_num_threads()):
        """ Cython callable low-level function for generating copies of the model
        Parameters
        ==========
        n_jobs: int,
            Number of copies to make
        Returns
        =======
        list of copies of the model. Note that each thread will generate a different seed;
        the seed will be increased by the thread id.
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
            # force reset
            spawn.push_back( PyObjectHolder(m.ptr) )

        return spawn

    cpdef add_edge(self, node_id_t x, node_id_t y, double weight = 1):
        self.adj._add_edge(x, y, weight)

    # WARNING: overwrite this for the model using  mcmc
    cdef double probability(self, \
                            state_t state,  \
                            node_id_t node\
                            ) nogil:
        """ computed the probability of the current state
        Note: needs to be implemented by inhereted class.
        Parameters
        ==========
        state: state_t (double),
            Current state for which to compute the probability for
        node: node_id (unsigned int),
            node for which to compute the probability for
        """
        return 1.


    def __eq__(self, other : Model) ->bool:
        """Comparison for Model base

        Checks whether the implemented classes have the same
        properties.

        Parameters
        ----------
        other : Model
            Model implementation (can be child class).

        Returns
        -------
        bool
            returns  true  if  class   is  the  same,  false
            otherwise.

        Examples
        --------
        FIXME: Add docs.

        """
        #TODO: this is likely to break in the future

        for name in dir(self):
            prop = getattr(self, name)
            oprop = getattr(other, name)

            if not name.startswith("_") and callable(prop) == False:
                if hasattr(prop, "__iter__"):
                    if hasattr(prop, "nodes"):
                        if not nx.is_isomorphic(prop, oprop):
                            return False
                    else:
                        if name == 'nodeids':
                            prop, oprop = sorted(prop), sorted(oprop)
                        for x, y in zip(prop, oprop):
                            if x != y:
                                print(f"Found problem with {oprop} {prop}")
                                return False
                else:
                    if prop != oprop:
                        print(f"Found problem with {oprop} {prop}")
                        print(oprop.nodes(), prop.nodes())
                        return False

        return True


cdef class ModelMC(Model):
    def __init__(self, p_recomb = 1, *args, **kwargs):
        # init base model
        super(ModelMC, self).__init__(*args, **kwargs)

        # start creating stochastic properties
        # note the rng is shared with base
        self._mcmc = MCMC(self._rng, p_recomb)

# helper function for pickling
def rebuild(cls, kwargs):
    return cls(**kwargs)
