#distutils: language=c++
# __author__ = 'Casper van Elteren'
cimport cython
from cython.operator cimport dereference as deref, postincrement as post
import networkx as nx, numpy as np

from plexsim.models.adjacency cimport Adjacency
cdef class Rules:
    """
    Constructs adj matrix using structs
    Parameters
    ==========
        :nx.Graph or nx.DiGraph: graph
    """
    def __init__(self, object graph):
        # check if graph has weights or states assigned and or nudges
        # note does not check all combinations
        # input validation / construct adj lists
        # defaults
        cdef double DEFAULTWEIGHT = 1.
        cdef double DEFAULTNUDGE  = 0.
        # DEFAULTSTATE  = random # don't use; just for clarity
        # enforce strings

        # relabel all nodes as strings in order to prevent networkx relabelling
        # graph = nx.relabel_nodes(graph, {node : str(node) for node in graph.nodes()})
        # forward declaration
        cdef:
            dict mapping = {}
            dict rmapping= {}

            state_t source, target

            # define adjecency
            unordered_map[state_t, unordered_map[state_t, double]] adj  #= Connections(graph.number_of_nodes(), Connection())# see .pxd
            weight_t weight
            # generate graph in json format
            dict nodelink = nx.node_link_data(graph)
            object nodeid
            int nodeidx

        for nodeidx, node in enumerate(nodelink.get("nodes")):
            nodeid            = node.get('id')
            mapping[nodeid]   = nodeidx
            rmapping[nodeidx] = nodeid

        # go through edges
        cdef bint directed  = nodelink.get('directed')
        cdef dict link
        for link in nodelink['links']:
            source = mapping[link.get('source')]
            target = mapping[link.get('target')]
            weight = <weight_t> link.get('weight', DEFAULTWEIGHT)
            # reverse direction for inputs
            if directed:
                # get link as input
                adj[target][source] = weight
            else:
                # add neighbors
                adj[source][target] = weight
                adj[target][source] = weight

        # public and python accessible
        self.graph       = graph
        self.mapping     = mapping
        self.rmapping    = rmapping
        self._adj        = adj

        # Private
        _nodeids         = np.arange(graph.number_of_nodes(), dtype = np.uintp)
        np.random.shuffle(_nodeids) # prevent initial scan-lines in grid
        self._nodeids    = _nodeids
        self._nNodes     = graph.number_of_nodes()

    @property
    def adj(self):
        return dict(self._adj)

    def __repr__(self):
         return str(self._adj)

    def __eq__(self, other):
        return self.adj == other.adj


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
