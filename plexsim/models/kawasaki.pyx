
from cython.operator import dereference as deref, postincrement as post
cdef class Kawasaki(Potts):
    def __init__(self, graph: object, agentStates: np.ndarray, **kwargs):

        super(Kawasaki, self).__init__(graph = graph,
                                       agentStates = agentStates,
                                       **kwargs)

    cdef void _step(self, node_id_t node) nogil:
        """
        Update using kawasaki dynamics
        """

        # choice a random spin
        # swaps state if it is more energetically favorable
        cdef:
            node_id_t neighbor
            state_t tmp,
            size_t idx, jdx
            double p1, p1_, p2, p2_, p

        # conversion
        idx = <size_t>(self._rng._rand() * self.adj._adj[node].neighbors.size())
        it = self.adj._adj[node].neighbors.begin()
        for i in range(idx):
            post(it)
        neighbor = deref(it).first

        # global stuff
        neighbor = <node_id_t>(self._rng._rand() * self.adj._nNodes)

        # energy current situation
        p1 = self.probability(self._states[node], node)
        p2 = self.probability(self._states[neighbor], neighbor)

        # switch states
        p1_ = self.probability(self._states[neighbor], node)
        p2_ = self.probability(self._states[node], neighbor)


        p = (p1 * p2)/(p2_ * p1_)
        if self._rng._rand() < p:
            # swap states
            tmp = self._states[node]
            self._newstates[node] = self._states[neighbor]
            self._newstates[neighbor] = tmp
        return
