#distutils:language=c++
import networkx as nx, numpy as np
cimport numpy as np
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
        graph = nx.relabel_nodes(graph, {node : str(node) for node in graph.nodes()})
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
            str nodeid
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
                adj[target].neighbors[source] = weight
            else:
                # add neighbors
                adj[source].neighbors[target] = weight
                adj[target].neighbors[source] = weight
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
