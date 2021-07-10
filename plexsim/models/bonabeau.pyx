#distutils:language=c++
cimport cython, numpy as np
import numpy as np
from cython.operator cimport dereference as deref
from cython.operator cimport preincrement as prei
from cython.operator cimport postincrement as post

from libc.math cimport exp, cos, pi, fabs
cdef class Bonabeau(Model):
    """
    Bonabeau model in hierarchy formation updated using heat bath equation
    based on Bonabeau et al. 1995
    """
    def __init__(self, graph,\
                 agentStates = np.array([0, 1]),\
                 eta = 1,\
                 **kwargs):
        """Model for hierarchy formation

        Parameters
        ----------
        graph : nx.Graph or nx.DiGraph
            Graph   indicating    the   relationship   among
            interacting elements.
        \ agentStates : np.ndarray
            List indicating the states  the agents can take.
            Values are discrete.
        \ eta : double
            Coefficient for sigmoid curve
        \ **kwargs : dict
            Other properties  that can  be set for  the base
            model. See Model implementation.

        Examples
        --------
        FIXME: Add docs.
        """

        super(Bonabeau, self).__init__(**locals())
        self.eta = eta

        self._weight = np.zeros(self.nNodes, dtype = np.double)

    cdef void _step(self, node_id_t node) nogil:
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

