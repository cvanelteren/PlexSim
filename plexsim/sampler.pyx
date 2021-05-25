#distutils: language=c++
from posix.time cimport clock_gettime, timespec, CLOCK_REALTIME
cdef class RandomGenerator:

    def __init__(self,\
                 object seed,\
                 ):
        """Init mersenne twister with some seed"""


        cdef timespec ts
        if seed is None:
            clock_gettime(CLOCK_REALTIME, &ts)
            _seed = ts.tv_sec
        elif seed >= 0 and isinstance(seed, int):
            _seed = seed
        else:
            raise  ValueError("seed needs uint")

        # define rng sampler
        self._dist = uniform_real_distribution[double](0.0, 1.0)
        self.seed = _seed
        self._gen  = mt19937(self.seed)

    cpdef double rand(self):
        return self._rand()

    cdef double _rand(self) nogil:
        """ Draws uniformly from 0, 1"""
        return self._dist(self._gen)

    @property
    def seed(self): return self._seed
    @seed.setter
    def seed(self, value):
        if isinstance(value, int) and value >= 0:
            self._seed = value
            self._gen   = mt19937(self.seed)
        else:
            raise ValueError("Not an uint found")

    cdef void fisher_yates(self, \
                           node_id_t* nodes,\
                           size_t n, \
                           size_t stop) nogil:
        cdef size_t idx, jdx
        for idx in range(n - 1):
            jdx = <size_t> (self._rand() * (n - idx))
            swap(nodes[idx], nodes[jdx])
            if stop == 1:
                break
        return

