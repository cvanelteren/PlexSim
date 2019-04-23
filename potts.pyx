# cython: infer_types=True
# distutils: language=c++
from Models.models cimport Model
from libcpp.vector cimport vector

# from models cimport Model
import copy
from tqdm import tqdm
import multiprocessing as mp
import numpy  as np
cimport numpy as np

from libc.math cimport exp
cimport cython
from cython.parallel cimport prange, threadid


from cpython cimport PyObject, Py_XINCREF, Py_XDECREF
cdef extern from *:
    """
    #include <Python.h>
    #include <mutex>

    std::mutex ref_mutex;

    class PyObjectHolder{
    public:
        PyObject *ptr;
        PyObjectHolder():ptr(nullptr){}
        PyObjectHolder(PyObject *o):ptr(o){
            std::lock_guard<std::mutex> guard(ref_mutex);
            Py_XINCREF(ptr);
        }
        //rule of 3
        ~PyObjectHolder(){
            std::lock_guard<std::mutex> guard(ref_mutex);
            Py_XDECREF(ptr);
        }
        PyObjectHolder(const PyObjectHolder &h):
            PyObjectHolder(h.ptr){}
        PyObjectHolder& operator=(const PyObjectHolder &other){
            {
                std::lock_guard<std::mutex> guard(ref_mutex);
                Py_XDECREF(ptr);
                ptr=other.ptr;
                Py_XINCREF(ptr);
            }
            return *this;

        }
    };
    """
    cdef cppclass PyObjectHolder:
        PyObject *ptr
        PyObjectHolder(PyObject *o) nogil
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

    cpdef long[::1] updateState(self, long[::1] nodesToUpdate):
        return self._updateState(nodesToUpdate)


    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cpdef vector[double] siteEnergy(self, long[::1] states):
        cdef:
            vector[double] siteEnergy
            int node
            double Z
        for node in range(self._nNodes):
            Z = self._adj[node].neighbors.size()
            siteEnergy.push_back((-self.energy(node, states)[0]  * self._nStates / Z - 1) / (self._nStates - 1))
        return siteEnergy


    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cdef vector[double] energy(self, int node, long[::1] states) nogil:
        cdef:
            long neighbors = self._adj[node].neighbors.size()
            long neighbor, neighboridx
            double weight
            long possibleState
            vector[double] energy
        # fill buffer
        # TODO: change this to more efficient buffer
        # keep track of:
        #   - energy of current state
        #   - energy of possible state
        #   - the possible state
        for possibleState in range(3):
            energy.push_back(0)
        # count the neighbors in the different possible states

        # draw random new state
        cdef int testState = <int> (self.rand() * self._nStates)
        testState = self.agentStates[testState]

        energy[0] = self._H[node]
        energy[1] = self._H[node]
        energy[2] = testState # keep track of possible new state
        for neighboridx in range(neighbors):
            neighbor   = self._adj[node].neighbors[neighboridx]
            weight     = self._adj[node].weights[neighboridx]
            if states[neighbor] == states[node]:
                energy[0] -= weight
            if states[neighbor] == testState:
                energy[1] -= weight
        # with gil: print(energy)
        return energy
    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cdef long[::1] _updateState(self, long[::1] nodesToUpdate) nogil:

        """
        Generate conditional distribution based on a change in state
        For all agent states compute the likelihood of staying in that state
        """

        cdef:
            int nodes = nodesToUpdate.shape[0]
            long node, nodeidx
            vector[double] probs
            int agentState
            double randomNumber
        for nodeidx in range(nodes):
            node         = nodesToUpdate[nodeidx]
            probs        = self.energy(node, self._states)
            randomNumber = self.rand()
            # with gil:
                # print(probs)
            if randomNumber <= exp(- self._beta * (probs[1] - probs[0])):
                self._newstates[node] = <int> probs[2]
        # repopulate buffer
        for node in range(self._nNodes):
            self._states[node] = self._newstates[node]
        return self._states

    cpdef  np.ndarray matchMagnetization(self,\
                              np.ndarray temps  = np.logspace(-3, 2, 20),\
                              int n             = int(1e3),\
                              int burninSamples = 0):
            """
            Computes the magnetization as a function of temperatures
            Input:
                  :temps: a range of temperatures
                  :n:     number of samples to simulate for
                  :burninSamples: number of samples to throw away before sampling
            Returns:
                  :temps: the temperature range as input
                  :mag:  the magnetization for t in temps
                  :sus:  the magnetic susceptibility
            """
            cdef:
                double tcopy   = self.t # store current temp
                np.ndarray results = np.zeros((2, temps.shape[0]))
                np.ndarray res, resi
                int N = len(temps)
                int i, j
                double t, avg, sus
                # Ising m
                int threads = mp.cpu_count()
                vector[PyObjectHolder] tmpHolder
                Potts tmp
                np.ndarray magres
                list modelsPy = []


            print("Computing mag per t")
            pbar = tqdm(total = N)
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
                # self.states     = jdx if jdx else self.reset() # rest to ones; only interested in how mag is kept
                    # (<Potts> tmptr).burnin(burninSamples)
                    # (<Potts> tmptr).reset
                    res        = (<Potts> tmptr).simulate(n)
                    # results[0, i] = np.array(self.siteEnergy(res[n-1])).sum()
                    results[0, i] = np.array([self.siteEnergy(resi) for resi in res]).sum()
                    # results[0, i] = np.array([(self.siteEnergy(resi)**2).mean(0) - results[0, i]**2)  * (<Potts> tmptr)._beta \
                                              # for resi in res].mean()
                    # for j in range(n):
                        # resi = np.array(self.siteEnergy(res[j]))
                        # avg = avg + resi.mean()
                        # sus = sus + (resi**2).mean()

                    # avg           = avg / nmean
                    # sus           = (sus/N - avg) * (<Potts> tmptr)._beta
                    # results[0, i] = avg
                    # results[1, i] = sus
                    pbar.update(1)
            # print(results[0])
            self.t = tcopy # reset temp
            return results
    def __deepcopy__(self, memo):
        # print('deepcopy')
        tmp = Potts(
                    graph       = copy.deepcopy(self.graph), \
                    temperature = self.t,\
                    agentStates = list(self.agentStates.base),\
                    updateType  = self.updateType,\
                    nudgeType   = self.nudgeType,\
                    )
        # tmp.states = self.states
        return tmp

    def __reduce__(self):
        return (rebuild, (self.graph, \
                          self.t,\
                          list(self.agentStates.base.copy()),\
                          self.updateType,\
                          self.nudgeType,\
                          self.nudges.base))



cpdef Potts rebuild(object graph, double t, \
                  list agentStates, \
                  str updateType, \
                  str nudgeType, \
                  np.ndarray nudges):
  cdef Potts tmp = copy.deepcopy(Potts(graph, t, agentStates, nudgeType, updateType))
  tmp.nudges = nudges.copy()
  return tmp
