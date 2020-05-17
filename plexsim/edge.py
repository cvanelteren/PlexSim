import networkx as nx

n = 100
g = nx.grid_graph([n, n])
g = nx.convert_node_labels_to_integers(g)
with open("edge.json", 'w') as f:
    import json
    json.dump(nx.node_link_data(g), f)
    
