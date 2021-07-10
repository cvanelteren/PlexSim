##distutils: language=c++
## cython: profile = True
## cython: linetrace = True
## distutils: define_macros=CYTHON_TRACE_NOGIL=1
## cython: np_pythran=True
import numpy as np
cimport numpy as np
from libcpp.vector cimport vector
cimport cython
from cython.parallel cimport parallel, prange, threadid
from cython.operator cimport dereference as deref, preincrement, postincrement as post
from libc.math cimport exp, cos, pi
import multiprocessing as mp
from pyprind import ProgBar

cdef class Potts(Model):
    """Kinetic q-Potts model

    Implements kinetic q-Potts model on arbitrary graph.
    This model implements all the base functionality of the
    Potts/Ising related models (e.g. Pottsis or Bornholdt).

    Parameters
    ----------
    graph : nx.Graph or nx.DiGraph
        Interaction structure for the spins.
    \agentStates: np.ndarray,
        Array giving q-states
    \delta: int
       A modifier for how much the memory affects the current received energy of
    a node
    \ **kwargs : dict
        General settings (see Model).

    Examples
    --------
    FIXME: Add docs.
    """

    def __init__(self, \
                 graph,\
                 t = 1,\
                 agentStates = np.array([0, 1], dtype = np.double),\
                 delta       = 0, \
                 p_recomb    = None,
                 **kwargs):

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
        """" Computes  average by  degree of node  energy of
        all nodes given a system state.

        Parameters
        ----------
        states: memoryview doubles
              1D vector of spin states

        Returns
        =======
        Returns node energy of all nodes given :states:
        """
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
        """ Computes raw site energy of nodes given a system state

        Parameters
        ----------

        states: memory view of spin states
            1D vector of size number of spins indicating the system state
        for which to compute the site energy.

        Returns
        -------
        Returns the raw site energy per spin in the system given :states:
        """
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
        """Computes energy of a spin
        This function is a low-level callable only.

        Parameters
        ----------
        node: size_t
            Spin for which to compute the energy for


        Returns
        -------
        Returns site energy of a spin

        """
        cdef:
            size_t neighbors = self.adj._adj[node].neighbors.size()
            state_t* states = self._states # alias
            size_t  neighbor, neighboridx
            double weight # TODO: remove delta

            # init with external magnetic field
            double energy  = self._H[node] * self._states[node]

        if self._nudges.find(node) != self._nudges.end():
            energy += self._nudges[node] * self._states[node]


        # compute the energy
        it = self.adj._adj[node].neighbors.begin()
        cdef size_t idx

        # current state as proposal
        cdef state_t proposal = self._states[node]
        while it != self.adj._adj[node].neighbors.end():
            weight   = deref(it).second
            neighbor = deref(it).first
            # update energy
            energy += weight * self._hamiltonian(proposal, states[neighbor])
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
            double p = self.probability(proposal, node) / \
                self.probability(cur_state, node)
        if self._rng._rand () < p:
            self._newstates[node] = proposal
        return

    cdef double _hamiltonian(self, state_t x, state_t  y) nogil:
        return cos(2 * pi  * ( x - y ) * self._z)

    cdef double magnetize_(self, Model mod, size_t n, double t):
        """ Magnetization function
        Computes the magnetization based on the average phase of the
        spins in the system. If al spins are aligned, the average phase is
        1.

        Note this is a low-level callable only!

        Parameters
        ----------
        mod: Model
           Spin system (Bornholdt/Ising or Potts)
        n: int
           Number of samples to use to determine the magnetization
        t: double
          Temperature of the spin system

        Returns
        -------
        Average phase of the spin system
        """
        # setup simulation
        cdef double Z = 1 / <double> self._nStates
        cdef np.ndarray results
        cdef double phase
        # set temp
        mod.t         =  t
        # reset states
        mod.states[:] = mod.agentStates[0]
        # sample states
        results = mod.simulate(n)  * Z
        # compute spin angles
        phase = np.real(np.exp(2 * np.pi * np.complex(0, 1) * results)).mean()
        return np.abs(phase)

    @cython.cdivision(False)
    cpdef  np.ndarray magnetize(self,\
                              np.ndarray temps  = np.logspace(-3, 2, 20),\
                              size_t n             = int(1e3),\
                              size_t burninSamples = 0,\
                              size_t n_jobs = 0,
                              ):
            """
            Computes the magnetization as a function of temperatures

            Parameters
            ----------
            temps: np.ndarray
                a range of temperatures
            \n: int
                number of samples to simulate for
            \burninSamples: int
                number of samples to throw away before sampling

            Returns
            -------
            Returns 2D matrix (2, number of temperatures). The first index (0)
            contains the magnetization, the second index (1) contains the magnetic
            susceptibility
            """
            #TODO: requires cleanup
            # some variables are redundant or not clear what they mean
            cdef:
                double tcopy   = self.t # store current temp
                double[:, ::1] results = np.zeros((2, temps.shape[0]))

                int N = len(temps)
                int ni
                np.ndarray magres
                list modelsPy = []

            # setup parallel models
            print("Spawning threads")
            if n_jobs == 0:
                n_jobs = mp.cpu_count()
            cdef:
                int tid
                double Z = 1/ <double> self._nStates
                SpawnVec  models = self._spawn(n_jobs)
                PyObject* ptr
                Model     mod

            print("Magnetizing temperatures")
            pbar = ProgBar(N)

            for ni in prange(N, \
                    nogil       = True,\
                    num_threads =  n_jobs,\
                    schedule    = 'static'):
                # acquire thread
                tid = threadid()
                # get model
                ptr = models[tid].ptr
                # results[0, ni] = self.magnetize_(<Model> tmptr, n, temps[ni])

                # magnetize!
                with gil:
                    results[0, ni] = self.magnetize_((<Model> ptr), n, temps[ni])
                    pbar.update()
            #TODO: remove?
            # compute susceptibility
            results.base[1, :] = np.abs(np.gradient(results.base[0, :], temps, edge_order = 1))
            self.t = tcopy # reset temp
            return results.base

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

@cython.binding(True)
@cython.cdivision(False)
def sigmoid(x, a, b, c, d):
    return  a * (1. + np.exp(b * x - c))**(-1) + d
@cython.binding(True)
def sigmoidOpt(x, params, match):
    return np.abs( sigmoid(x, *params) - match )

# deprecated
def match_temperature(match, results, temps):
    """
    matches temperature
    """
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
    return tcopy
