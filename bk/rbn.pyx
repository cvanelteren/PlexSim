#distutils: language=c++
cimport cython
from cython.operator cimport dereference as deref, reference as ref
from cython.operator cimport postincrement as post
cdef class RBN(Model):
    def __init__(self, graph, rule = None, \
                 updateType = "sync",\
                 **kwargs):

        agentStates = [0, 1]

        super(RBN, self).__init__(**locals())
        # self.states = np.asarray(self.states.base.copy())

        # init rules
        # draw random boolean function
        for node in range(self.nNodes):
            k = self.adj._adj[node].neighbors.size()
            rule = np.random.randint(0, 2**(2 ** k), dtype = int)
            rule = format(rule, f'0{2 ** k}b')[::-1]
            self._evolve_rules[node] = [int(i) for i in rule]

    @property
    def rules(self):
        return self._evolve_rules

    cdef void _step(self, node_id_t node) nogil:
       """
       Update step for Random Boolean networks
       Count all the 1s from the neighbors and index into fixed rule
       """

       cdef:
           long c = 0
           long counter = 0 
           long neighbor
           long N = self.adj._adj[node].neighbors.size()
       it = self.adj._adj[node].neighbors.begin()
       while it != self.adj._adj[node].neighbors.end():
           if self._states[deref(it).first] == 1:
               counter += 2 ** c
           c += 1
           post(it)

        #update
       self._newstates[node] = self._evolve_rules[node][counter]
       return
   

cdef class Percolation(Model):
    def __init__(self, graph, p = 1, \
                 agentStates = np.array([0, 1], dtype = np.double), \
                **kwargs):
        super(Percolation, self).__init__(**locals())
        self.p = p


    cdef void _step(self, node_id_t node) nogil:
        cdef:
            long neighbor
        if self._states[node]:
            it = self.adj._adj[node].neighbors.begin()
            while it != self.adj._adj[node].neighbors.end():
                if self._rng._rand() < self._p:
                    neighbor = deref(it).first
                    self._newstates[neighbor] = 1
                post(it)
        return 

    @property
    def p(self):
        return self._p
    
    @p.setter
    def p(self, value):
        self._p = value

