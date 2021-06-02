#distutils: language=c++
cimport cython
from cython.operator cimport dereference as deref
from cython.operator cimport preincrement as prei
from cython.operator cimport postincrement as post
import numpy as np
cimport numpy as np
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
   


