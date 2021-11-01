#distutils:language=c++
import networkx as nx, numpy as np
cimport numpy as np
from cython.operator cimport dereference as deref
from cython.operator cimport postincrement as post
cdef class Adjacency:
   """
    Constructs adj matrix using structs
    intput:
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

            node_id_t source, target

            # define adjecency
            Connections adj  #= Connections(graph.number_of_nodes(), Connection())# see .pxd
            weight_t weight
            # generate graph in json format
            dict nodelink = nx.node_link_data(graph)
            object nodeid
            int nodeidx

        for nodeidx, node in enumerate(nodelink.get("nodes")):
            nodeid            = node.get('id')
            mapping[nodeid]   = nodeidx
            rmapping[nodeidx] = nodeid
            adj[nodeidx] # init adjacency info

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
                adj[target].neighbors[source] = weight
            else:
                # add neighbors
                adj[source].neighbors[target] = weight
                adj[target].neighbors[source] = weight

        # public and python accessible
        # self.graph       = graph
        self.mapping     = mapping
        self.rmapping    = rmapping
        self._adj        = adj

        # Private
        _nodeids         = np.arange(graph.number_of_nodes(), dtype = np.uintp)
        np.random.shuffle(_nodeids) # prevent initial scan-lines in grid
        self._nodeids    = _nodeids
        self._nNodes     = graph.number_of_nodes()
        self._directed = directed

   cdef void _add_edge(self, node_id_t x, node_id_t y, double weight = 1) nogil:
       self._adj[x].neighbors[y] = weight
       if not self._directed:
           self._adj[y].neighbors[x] = weight
       return

   cdef void _remove_edge(self, node_id_t x, node_id_t y) nogil:
       self._adj[x].neighbors.erase(y)
       if not self._directed:
            self._adj[y].neighbors.erase(x)
       return

   # not this uses the node id not the string name
   cpdef add_edge(self, node_id_t x, node_id_t y, double weight = 1):
       self._add_edge(x, y, weight)
       return



   @property
   def adj(self):
       """
       Returns the adjacency structure.
       FIXME: further abstract this
       """
       return self._adj
       # return dict(self._adj)

   @property
   def graph(self):
       """
       Wrapper around retrieving the graph. Some models edit the adjacency structure
       as such we have to reconstruct the graph from the lower level mapping.
       """
       output = {node : {} for node in self.mapping}
       directed = False
       for k, v in self.adj.items():
           node = self.rmapping[k]
           # flip input from output
           # the adj matrix registers the inputs
           # to a node
           for kk, vv in v["neighbors"].items():
               neighbor = self.rmapping[kk]
               output[neighbor][node] = dict(weight=vv)
               if self.adj[kk]["neighbors"].get(k, 0) == 0:
                   directed = True

       #TODO: hotfix
       template = nx.Graph()
       if directed:
           template = nx.DiGraph()

       return nx.from_dict_of_dicts(output, create_using = template)

   def __repr__(self):
        #FIXME: remove this
        # Originally used for printing the lower level buffer
        return str(self._adj)

   def __eq__(self, other):
       return self.adj == other.adj
