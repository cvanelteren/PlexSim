#distutils: language=c++
from PlexSim.Models.Models cimport Model
from libcpp.vector cimport vector

# from models cimport Model
import copy
from tqdm import tqdm
from pyprind import ProgBar
import multiprocessing as mp
import numpy  as np
cimport numpy as np

from libc.math cimport exp, log, cos, pi
cimport cython
from cython.parallel cimport prange, threadid
from cython.operator cimport postincrement, dereference
from libcpp.unordered_map cimport unordered_map
from PlexSim.Models.parallel cimport *


cdef class Potts(Model):
    def __init__(self, \
                        graph,\
                        t = 1,\
                        agentStates = [0, 1],\
                        nudgeType   = 'constant',\
                        updateType  = 'async', \
                        memorySize     = 0, \
                        delta            = 0, \
                        **kwargs):
        """
        Potts model

        default inputs see :Model:
        Additional inputs
        :delta: a modifier for how much the previous memory sizes influence the next state
        """
        super(Potts, self).__init__(**locals())

        cdef np.ndarray H  = np.zeros(self.graph.number_of_nodes(), float)
        for node, nodeID in self.mapping.items():
            H[nodeID] = self.graph.nodes()[node].get('H', 0)
        # for some reason deepcopy works with this enabled...
        self.states = np.asarray(self.states.base).copy()
        # self.nudges = np.asarray(self.nudges.base).copy()

        # specific model parameters
        self._H      = H
        # self._beta = np.inf if temperature == 0 else 1 / temperature
        self.t       = t

        self._delta  = delta

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
            double Z, energy
        for node in range(self._nNodes):
            Z = self._adj[node].neighbors.size()
            energy = - self.energy(node, states)[0] / Z # just average
            siteEnergy.push_back(energy)
        return siteEnergy


    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cdef vector[double] _energy(self, long node) nogil:
        cdef:
            long neighbors = self._adj[node].neighbors.size()
            long* states = self._states_ptr # alias
            long neighbor, neighboridx
            double weight # TODO: remove delta
            vector[double] energy = vector[double](3)
        # fill buffer
        # TODO: change this to more efficient buffer
        # keep track of:
        #   - energy of current state
        #   - energy of possible state
        #   - the possible state
        # count the neighbors in the different possible states

        # draw random new state
        cdef int testState = <int> (self._rand() * self._nStates)
        testState = self._agentStates[testState]

        energy[0] = self._H[node]
        energy[1] = self._H[node]
        energy[2] = testState # keep track of possible new state

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
    cdef double _hamiltonian(self, long x, long y) nogil:
        # sanity checking
        return cos(2 * pi  * (<double> x - <double> y) / <double> self._nStates)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cdef void _step(self, long node) nogil:
        cdef:
            vector[double] probs
            double p

        probs = self._energy(node)
        p = exp(- self._beta *( probs[1] - probs[0]))
        if self._rand() <= p:
            self._newstates_ptr[node] = <long> probs[2]

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
                    self.states     = self.agentStates[0] # rest to ones; only interested in how mag is kept
                    # (<Potts> tmptr).burnin(burninSamples)
                    # (<Potts> tmptr).reset
                    res        = (<Potts> tmptr).simulate(n)
                    # results[0, i] = np.array(self.siteEnergy(res[n-1])).sum()
                    mu = np.array([self.siteEnergy(resi) for resi in res])

                    results[0, i] = mu.mean()
                    results[1, i] = (mu**2).mean()  - mu.mean()**2 * self._beta
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
        # tmp.nudges = self.nudges.base
        return tmp

    def __reduce__(self):
        tmp = {i: getattr(self, i) for i in dir(self)}
        return (rebuild, tmp)



def rebuild(**kwargs):
    cdef Potts tmp = Potts(**kwargs)
    tmp.nudges = kwargs.get('nudges').copy()
    return tmp
