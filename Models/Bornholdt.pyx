include "definitions.pxi"
from PlexSim.Models.FastIsing cimport Ising
cdef class Bornholdt(Ising):

    def __init__(self, graph,\
                t = 1,\
                alpha = 1,\
                agentStates = [-1, 1],\
                nudgeType = "constant",\
                magSide = '',\
                **kwargs):
        """
        Bornholdt model; Ising spin like model based on S.Bornholdt (2000)
        """
        super(Bernholdt, self).__init__(**locals())
        self._meanState = np.mean(self._states)
    cdef void _step(self, long node) nogil:
        cdef:
            long neighbor
            #long* neighbors = &self._adj[node].neighbors[0]
        #    Connection  neighborHood = &self._adj[node]

        #for neighbor in range(neighborHood.neighbors.size()):
        #    neighbor = <long> neighborHood.neighbors[neighbor] 
        #    weight  = neighborHood.weights[neighbor:w
        #    ]
            


    @property
    def alpha(self):
        return self._alpha

    @alpha.setter
    def alpha(self, value):
        assert isinstance(value, float)
        self._alpha = value
