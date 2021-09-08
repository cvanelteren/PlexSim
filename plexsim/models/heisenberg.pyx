# spins have 2d matrices on x,y,z direction
from plexsim.models.ising cimport Ising
cdef class Heisenberg(Ising):
    def __init__(self,
                 object graph,
                 *args,
                 **kwargs):
        super().__init__(graph, **kwargs)

