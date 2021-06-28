#distutils: language=c++
# __author__ = 'Casper van Elteren'
cimport cython
from cython.operator cimport dereference as deref, postincrement as post
import networkx as nx

cdef class Rules(Adjacency):
    def __init__(self, object graph):
        super().__init__(graph)

# cdef class Rules:
#     def __init__(self, object rules):
#         self.rules = rules
#         cdef:
#              # output
#              unordered_map[state_t, unordered_map[state_t, double]] r
#              # multimap[state_t, pair[ state_t, double ]] r
#              # var decl.
#              pair[state_t, pair[state_t, double]] tmp
#              double weight
#              dict nl = nx.node_link_data(rules)
#              state_t source, target

#         for link in nl['links']:
#             weight = link.get('weight', 1)
#             source = link.get('source')
#             target = link.get('target')

#             r[target][source] = weight

#             # tmp.first = target
#             # tmp.second = pair[state_t, double](source, weight)
#             # r.insert(tmp)
#             if not nl['directed'] and source != target:
#                 r[source][target] = weight

#                 # tmp.first  = source;
#                 # tmp.second = pair[state_t, double](target, weight)
#                 # r.insert(tmp)

#         self._rules = r # cpp property
#         # self.rules = rules # hide object


    # cdef rule_t _check_rules(self, state_t x, state_t y) nogil:

    #     it = self._rules.find(x)
    #     cdef rule_t tmp
    #     while it != self._rules.end():
    #         if deref(it).second.first == y:
    #             tmp.first = True
    #             tmp.second = deref(it).second
    #             return tmp
    #         post(it)
    #     return tmp
