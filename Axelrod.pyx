from Modelsl.models import Model
cdef class Axelrod(Model):
    """
    Implementation of binary Axelrod model
    """
    def __init__(self, **kwargs):
        super(Axelrod, self).__init__(**kwargs)
    cdef long[::1] _updateState(self, long[::1] state):


    cpdef updateState(self, long[::1] state):
        return self.states
