import networkx as nx, numpy as np

def create_rule_full(rule, connection_weight_other = -1,
                     connection_weight = 1,
                     self_weight = 0):
    """
    Create a full rule graph
    """
    # connection between nodes
    # self weight
    A = nx.adjacency_matrix(rule).todense() 
    g = nx.Graph()
    for idx, w in enumerate(A.flat):
        u, v = np.unravel_index(idx, A.shape)
        if w > 0:
            w *= connection_weight
        else:
            w = connection_weight_other
        g.add_edge(u, v, weight = w * connection_weight)

    # add self love
    for node in g.nodes():
        g.add_edge(node, node, weight = self_weight)
    return g
