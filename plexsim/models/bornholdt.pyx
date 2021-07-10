# TODO: system coupling is updated instantaneously which is in contradiction with the sync update rule
#
from libc.math cimport exp, cos, pi, fabs
from plexsim.models.base cimport swap
import numpy as np
cimport numpy as np
cdef class Bornholdt(Potts):
    """
    Implementation of Bornholdt model (2000)
    Ising-like dynamics with a global magnetiztion dynamic
    """
    def __init__(self,\
                 graph, \
                 double alpha = 1,\
                 **kwargs):
        """Spin model for economic crashes

        Implements Bornholdt model by Stefan Bornholdt 2001.
        It is based on an Ising model with a global coupling
        constant used to model financial crashes.

        Parameters
        ----------
        graph : nx.Graph or nx.DiGraph
            Interaction structure of the system.
        \alpha : double
            Global coupling coefficient; values larger than zero indicate an positive
        coupling with the system, conversely lower than zero is a negative coupling.
        \kwargs: dict,
            Containing general settings for the base class, e.g. sampleSize, updateType etc.
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
        """ Computes probability of current spin given its neighborhood configuration
        Parameters
        ==========
        proposal: state_t (double),
             Current system state
        \node_id_t: size_t
             Node corresponding to the spin state

        Returns
        =======
        Probability of the spin being in :proposal: state.
        """
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
        delta  = energy - fabs(self._hamiltonian(proposal, systemInfluence))
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

