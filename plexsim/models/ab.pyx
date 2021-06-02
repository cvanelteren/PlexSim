#distutils: language=c++
# cimport cython
cimport cython, numpy as np
import numpy as np
from cython.operator cimport dereference as deref
from cython.operator cimport preincrement as prei
from cython.operator cimport postincrement as post

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
