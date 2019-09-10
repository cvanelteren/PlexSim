# cython: infer_types=True
# distutils: language=c++
# __author__ = 'Casper van Elteren'

"""
Created on Tue Feb  6 09:36:17 2018

@author: Casper van Elteren
"""
from Models.Models cimport Model
# from models cimport Model
import numpy  as np
cimport numpy as np

from scipy.stats import linregress
import networkx as nx, multiprocessing as mp, \
                scipy,  functools, copy, time
from tqdm import tqdm

# ___CythonImports___
cimport cython
from cython cimport numeric
from cython.parallel cimport prange, parallel, threadid


from libc.math cimport exp
from libcpp.map cimport map
from libcpp.vector cimport vector
from cython.operator cimport dereference, preincrement
from libc.stdio cimport printf


# from libc.math cimport max, min
from Models.parallel cimport *
# use external exp
cdef extern from "vfastexp.h":
    double exp_approx "EXP" (double) nogil

cdef class Ising(Model):
    # def __cinit__(self, *args, **kwargs):
    #     print('cinit fastIsing')
    def __init__(self, \
                 graph,\
                 t = 1,\
                 agentStates = [-1 ,1],\
                 nudgeType   = 'constant',\
                 updateType  = 'async', \
                 magSide     = '',\
                 **kwargs):
        super(Ising, self).__init__(**locals())
        # print('Init ising')
        cdef np.ndarray H  = np.zeros(self.graph.number_of_nodes(), float)
        for node, nodeID in self.mapping.items():
            H[nodeID] = self.graph.nodes()[node].get('H', 0)
        # for some reason deepcopy works with this enabled...
        self.states           = np.asarray(self.states.base).copy()
        self.nudges           = np.asarray(self.nudges.base).copy()
        # specific model parameters
        self._H               = H
        # self._beta             = np.inf if temperature == 0 else 1 / temperature
        self.magSideOptions   = {'': 0, 'neg': -1, 'pos': 1}
        self.magSide          = magSide

        self.t = t

        # this be a tuple with list, dict

        # cdef tuple equilibriate = \
        # kwargs.get('equilibrium', ())

        # if equilibriate:
          # print('Starting equilibration')
          # self.equilibriate(*equilibriate)
        # kwargs.pop('equilibrium', None)




    @property
    def H(self):
      return self._H

    def equilibriate(\
            self, \
            magRatios: np.ndarray,\
            settings: dict,  \
            ):
        """
        Uses :magRatio: to look for matching temperature values that have
        the desired magnetic ratio. The :settings: variable contains
        settings for matching the temperatures, see :matchMagnetization:

        Returns dict containing the magnetic ratios as well as the found
        raw data points
        """
        magRatios = np.asarray(magRatios) # ensure
        # setup variables
        cdef:
          np.ndarray magValues, optCoeffs
          dict matched
          np.ndarray temps

        """
        Equilbriation if required by simulation
        """

        cdef float mr

        def sigmoid(x, a, b, c, d):
          return a / (1 + np.exp(- b * (x - c))) + d
        def froot(x, a, c):
          return sigmoid(x, *a) -c
        # run simulation
        # returns mag and sus
        magValues = self.matchMagnetization(**settings)
        # normalize 0, 1
        # magValues = (magValues - magValues.min()) / (magValues.max() - magValues.min())

        # func

        from scipy import optimize
        optCoeffs = optimize.curve_fit(\
              sigmoid, settings['temperatures'], \
              magValues[0])[0]

        matched = {}

        magValues = np.concatenate(\
        ( settings.get('temperatures')[None, :], magValues), axis = 0)

        matched['mag'] = magValues
        # t = np.zeros(magRatios.size)
        t = {}
        for idx, mr in enumerate(magRatios):
          t[mr] = optimize.root(\
                      froot,\
                      0, \
                      args = (optCoeffs, mr),\
                      method = 'linearmixing'\
                      ).x
        # tmp = np.stack((t, magRatios))
        matched['ratios'] = t
        # assign properties
        self.matched   = matched
        return matched

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cpdef np.ndarray burnin(self,\
                 int samples = int(1e2), \
                 double threshold = 1e-2, ):
        """
        Go to equilibrium distribution; uses magnetization and linear regression
        to see if the system is stabel
        """

        # magnetization function
        magnetization = np.mean
        cdef:
            y  = np.array(magnetization(self.states)) # for regression
            int h, counter = 0 # tmp var and counter
            double beta        # slope value
            np.ndarray x # for regression
            long[::1] states
            long[:, ::1] r
            # vector[int][1] r = 0

        # print('Starting burnin')
        while True:
            r      = self.sampleNodes(1) # produce shuffle
            states = self.updateState(r[0]) # update state
            # check if magnetization = constant
            y      = np.hstack((y, np.abs(magnetization(states))))
            if counter > samples :
                # do linear regression
                h = len(y + 2) # plus 2 due to starting point
                x = np.arange(h)
                beta = linregress(x, y).slope
                if abs(beta) < threshold:
                    break
            counter += 1
        else:
            print('Number of bunin samples used {0}\n\n'.format(counter))
            print(f'absolute mean magnetization last sample {abs(y[-1])}')
        return y


    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cdef double energy(self, \
                        int  node, \
                        long[::1] states) nogil :
                       # cdef double energy(self, \
                       #                    int  node, \
                       #                    long[::1] states)  :
        """
        input:
            :nsyncode: member of nodeIDs
        returns:
                :energy: current energy of systme config for node
        """
        cdef:
            long length            = self._adj[node].neighbors.size()
            long neighbor, i
            double weight
            double delta = 1
            double energy          = -self._H [node] * states[node]

        # TODO: add memory part
        for i in range(length):
            neighbor = self._adj[node].neighbors[i]
            weight   = self._adj[node].weights[i]
            energy  -= states[node] * states[neighbor] * weight

        energy -= self._nudges[node] * states[node]
        # energy *= (1 + self._nudges[node])
        return energy

    cpdef long[::1] updateState(self, long[::1] nodesToUpdate):
        return self._updateState(nodesToUpdate)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    @cython.overflowcheck(False)
    cdef long[::1] _updateState(self, long[::1] nodesToUpdate) nogil:
    # cdef long[::1] _updateState(self, long[::1] nodesToUpdate):
        """
        Determines the flip probability
        p = 1/(1 + exp(-beta * delta energy))
        """
        cdef:
            # long[::1] states    = self._states # alias
            # long[::1] newstates = self._newstates
            int length          = nodesToUpdate.shape[0]
            double Z            = <double> self._nNodes
            long node
            double energy, p
            int n
        # for n in prange(length,  = True): # dont prange this
        for n in range(length):
            node      = nodesToUpdate[n]
            energy    = self.energy(node, self._states)
            # p = 1 / ( 1. + exp_approx(-self.beta * 2. * energy) )
            p  = 1 / ( 1. + exp(-self._beta * 2. * energy))
            # p  = p  +  self._nudges[node]
            # p += self._nudges[node]
            if self.rand() < p:
                self._newstates[node] = -self._states[node]
        # uggly
        cdef double mu   =  0 # sign
        cdef long   NEG  = -1 # see the self.magSideOptions
        cdef long   POS  =  1
        # printf('%d ', mu)
        # compute mean
        for node in range(self._nNodes):
            self._states[node] = self._newstates[node] # update
            mu          += self._states[node] # normalization not really needed

        # out of state equilibrium?
        if (mu < 0 and self._magSide == POS) or\
         (mu > 0 and self._magSide == NEG):
            # printf('%f %d\n', mu, self._magSide)
            # flip if true
            for node in range(self._nNodes):
                self._states[node] = -self._states[node]
        return self._states



    cpdef np.ndarray[double] computeProb(self):
        """
        Compute the node probability for the current state p_i = 1/z * (1 + exp( -beta * energy))**-1
        """

        probs = np.zeros(self.nNodes)
        for node in self.nodeids:
            en = self.energy(node, self.states)
            probs[node] = exp(-self._beta * en)
        return probs / np.nansum(probs)

    cpdef double  hammy(self):
        cdef double h = 0
        for node in self.nodeids:
            h -= self.energy(node, self.states)
        return h

    cpdef  np.ndarray matchMagnetization(self,\
                          np.ndarray temperatures = np.logspace(-3, 2, 20),\
                          int n                   = int(1e3),\
                          int burninSamples       = 0, \
                          ):
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
            np.ndarray results = np.zeros((2, temperatures.shape[0]))
            int N = len(temperatures)
            int i
            double t
            # Ising m
            int threads = mp.cpu_count()
            vector[PyObjectHolder] tmpHolder
            Ising tmp
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

        print('here')
        for i in prange(N, nogil = True, schedule = 'static',\
                        num_threads = threads):
            # m = copy.deepcopy(self)
            tid = threadid()
            tmptr = tmpHolder[tid].ptr
            with gil:
                t                  = temperatures[i]
                (<Ising> tmptr).t  = t
                jdx    = (<Ising> tmptr).magSideOptions[tmp.magSide]
                if jdx:
                    (<Ising> tmptr).states = jdx
                else:
                    (<Ising> tmptr).states = 1
            # self.states     = jdx if jdx else self.reset() # rest to ones; only interested in how mag is kept
                (<Ising> tmptr).burnin(burninSamples)
                magres        = (<Ising> tmptr).simulate(n)
                results[0, i] = abs(magres.mean())
                # results[1, i] = ((magres**2).mean() - magres.mean()**2) * (<Ising> tmptr).beta
                pbar.update(1)
        results[1, :] = abs(np.gradient(results[0], temperatures, edge_order = 1))
        # print(results[0])
        self.t = tcopy # reset temp
        return results
    def __deepcopy__(self, memo):
        # print('deepcopy')
        tmp = {i: getattr(self, i) for i in dir(self)}
        tmp = Ising(**tmp)
        # tmp.nudges = self.nudges.base.copy()
        return tmp

    def __reduce__(self):
        tmp = {i: getattr(self, i) for i in dir(self)}
        return (rebuild, tmp)

    # PROPERTIES
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
      # make property
        self._t   = value
        self.beta = 1 / value if value != 0 else np.inf

def rebuild(**kwargs):
    cdef Ising tmp = Ising(**kwargs)
    tmp.nudges = kwargs.get('nudges').copy()
    return tmp
