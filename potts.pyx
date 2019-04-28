# distutils: language=c++
from Models.models cimport Model
from libcpp.vector cimport vector

# from models cimport Model
import copy
from tqdm import tqdm
import multiprocessing as mp
import numpy  as np
cimport numpy as np

from libc.math cimport exp, log, cos, pi
cimport cython
from cython.parallel cimport prange, threadid

from Models.parallel cimport *


cdef class Potts(Model):
    def __init__(self, \
                 **kwargs):
        """
        Potts model

        default inputs see :super:

        Additional inputs
        :delta: a modifier for how much the previous memory sizes influence the next state
        """
        super(Potts, self).__init__(**kwargs)

        cdef np.ndarray H  = np.zeros(self.graph.number_of_nodes(), float)
        for node, nodeID in self.mapping.items():
            H[nodeID] = self.graph.nodes()[node].get('H', 0)
        # for some reason deepcopy works with this enabled...
        self.states = np.asarray(self.states.base).copy()
        self.nudges = np.asarray(self.nudges.base).copy()

        # specific model parameters
        self._H      = H
        # self._beta = np.inf if temperature == 0 else 1 / temperature
        self.t       = kwargs.get('temperature', 1)

        self._delta  = kwargs.get('delta', 0)

        # self._memory = np.ones((self.memorySize, self.nNodes), dtype = long)

    @property
    def delta(self): return self._delta

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
            double weight # TODO: remove delta
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
        testState = self._agentStates[testState]

        energy[0] = self._H[node]
        energy[1] = self._H[node]
        energy[2] = testState # keep track of possible new state
        for neighboridx in range(neighbors):
            neighbor   = self._adj[node].neighbors[neighboridx]
            weight     = self._adj[node].weights[neighboridx]
            energy[0]  -= weight * self.hamiltonian(states[node], states[neighbor])
            energy[1]  -= weight * self.hamiltonian(testState, states[neighbor])
            # if states[neighbor] == states[node]:
                # energy[0] -= weight
            # if states[neighbor] == testState:
                # energy[1] -= weight

        # retrieve memory
        cdef int memTime
        for memTime in range(self._memorySize):
            # check for current state
            energy[0] -= self.hamiltonian(states[node], self._memory[memTime, node]) * exp(-memTime * self._delta)
            energy[1] -= self.hamiltonian(testState, self._memory[memTime, node]) * exp(-memTime * self._delta)
        # with gil: print(energy)
        return energy
    cdef double hamiltonian(self, long x, long y) nogil:
        return cos(2 * pi  * (x - y) / self._nStates)

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

        # fill memory  by shifting all rows down by 1
        cdef int memTime
        # repopulate buffer
        for node in range(self._nNodes):
            self._states[node]    = self._newstates[node]
            if self._memorySize:
                for memTime in range(self._memorySize - 1, 0, -1):
                        # with gil: print(memTime)
                        self._memory[memTime, node] = self._memory[memTime - 1, node]
                self._memory[0, node] = self._states[node]
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
                    results[0, i] = np.array([self.siteEnergy(resi) for resi in res]).mean()
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
        tmp = {i: getattr(self, i) for i in dir(self)}
        tmp = Potts(**tmp)
        return tmp

    def __reduce__(self):
        tmp = {i: getattr(self, i) for i in dir(self)}
        return (rebuild, tmp)



def rebuild(**kwargs):
    print('>', kwargs)
    cdef Potts tmp = Potts(**kwargs)
    tmp.nudges = kwargs.get('nudges').copy()
    return tmp
